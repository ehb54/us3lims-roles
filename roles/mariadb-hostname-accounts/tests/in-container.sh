#!/bin/bash
# Run by run.sh inside a test container. A throwaway MariaDB server with skip-name-resolve, as
# config-lims-database sets it, holds accounts at a host name, made before a restart so that it
# ignores them, and control accounts at localhost, IP addresses and patterns. The playbook then
# runs against it in each mode, once with SHOW GRANTS as the server answers it and once with
# injected errors (inject.py).
set -u
export ANSIBLE_ROLES_PATH=/repo/roles ANSIBLE_NOCOLOR=1 ANSIBLE_DEPRECATION_WARNINGS=0
PB=/repo/mariadb-hostname-accounts-playbook.yml
PW=role-test-root
SOCK=/var/lib/mysql/mysql.sock
BIN=$(ls /usr/libexec/mariadbd /usr/libexec/mysqld 2>/dev/null | head -1)
INIT=$(command -v mariadb-install-db || command -v mysql_install_db)
FAILS=0
LOG=""
SRV=""

sql() { mysql --no-defaults -S $SOCK -u root -p"$PW" -N -B -e "$1"; }
start() { # $@: extra server options
    local i
    setpriv --reuid=mysql --regid=mysql --init-groups $BIN --no-defaults --datadir=/var/lib/mysql \
        --socket=$SOCK --skip-networking --log-error=/var/tmp/mariadb.err "$@" &
    SRV=$!
    for i in $(seq 1 60); do
        mysqladmin --no-defaults -S $SOCK ping > /dev/null 2>&1 && sleep 1 && return 0
        sleep 1
    done
    echo "the server did not start:"; tail -5 /var/tmp/mariadb.err; exit 1
}
stop() { kill $SRV; wait $SRV; }
# the accounts at a host name, the role's own test of a name (not localhost, an IP address or a pattern)
named() {
    sql "SELECT IFNULL(GROUP_CONCAT(CONCAT(user, '@', host) ORDER BY user, host), '(none)') FROM mysql.user
         WHERE host <> 'localhost' AND host NOT REGEXP '[:%_/]' AND host NOT REGEXP '^[0-9.]*\$'"
}
controls() { sql "SELECT COUNT(*) FROM mysql.user WHERE user = 'ctl'"; }
# puts back the accounts at a host name that an earlier case dropped, and restarts, so that every
# case starts from the same accounts
reset_named() {
    local a
    [ "$(named)" = "$NAMED" ] && return 0
    for a in ${NAMED//,/ }; do
        sql "CREATE USER IF NOT EXISTS '${a%@*}'@'${a#*@}' IDENTIFIED BY 'x'" 2>&1 | grep -v -i warning
    done
    stop
    start --skip-name-resolve
}
make_named() { sql "CREATE USER IF NOT EXISTS 'gfac'@'db.example.org' IDENTIFIED BY 'x';
                    CREATE USER IF NOT EXISTS 'us3php'@'db.example.org' IDENTIFIED BY 'x'" 2>&1 | grep -v -i warning; }
# $1 label, $2 report|apply|check, $3 injection JSON for inject.py, or "" for none. Sets RC and LOG.
play() {
    local x=""
    case $2 in apply) x="-e run=1";; check) x="-e run=1 --check";; esac
    if [ -n "$3" ]; then
        echo "$3" > /var/tmp/inject.json
        export ANSIBLE_COLLECTIONS_PATH=/var/tmp/inject
    else
        rm -f /var/tmp/inject.json
        unset ANSIBLE_COLLECTIONS_PATH
    fi
    LOG=/var/tmp/$1.log
    /opt/ansible/bin/ansible-playbook -i /var/tmp/hosts.ini -l localhost $x -e ansible_become=false \
        -e mariadb_hostname_login_password="$PW" $PB > $LOG 2>&1
    RC=$?
}
# the task the play failed in
failed_task() { awk '/^TASK \[/ {t = $0} /^(fatal|failed):/ {print t; exit}' $LOG | sed -e 's/^TASK \[[^:]*: //' -e 's/\] \**$//'; }
expect() { # $1 description, $2 shell condition
    if eval "$2"; then
        echo "ok   $1"
    else
        echo "FAIL $1"
        FAILS=$((FAILS + 1))
        grep -E '^(fatal|failed):|"msg": ' $LOG | tail -6 | cut -c1-240 | sed 's/^/       /'
    fi
}

mkdir -p /var/tmp/inject && cp -a /root/.ansible/collections/ansible_collections /var/tmp/inject/
MQ=/var/tmp/inject/ansible_collections/ansible/mysql/plugins/modules/mysql_query.py
[ -f $MQ ] || MQ=/var/tmp/inject/ansible_collections/community/mysql/plugins/modules/mysql_query.py
/usr/bin/python3 /repo/roles/mariadb-hostname-accounts/tests/inject.py $MQ || exit 1
printf '[lims]\nlocalhost ansible_connection=local\n' > /var/tmp/hosts.ini

$INIT --user=mysql --datadir=/var/lib/mysql > /var/tmp/init.log 2>&1 || { echo "init failed"; tail /var/tmp/init.log; exit 1; }
start --skip-name-resolve
mysql --no-defaults -S $SOCK -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$PW'"
make_named
for h in localhost % 10.0.0.1 10.0.% ::1; do sql "CREATE USER 'ctl'@'$h' IDENTIFIED BY 'x'"; done
stop
start --skip-name-resolve
NAMED=$(named)
echo "MariaDB $(sql 'SELECT VERSION()'), $(/opt/ansible/bin/ansible --version | head -1), accounts at a host name: $NAMED"
G="gfac@db.example.org"

reset_named
play report report ""
expect "report lists the accounts at a host name for apply, and drops none" \
    '[ $RC = 0 ] && grep -q "\"msg\": \"apply drops: .*$G" $LOG && [ "$(named)" = "$NAMED" ]'

reset_named
play lost-apply apply "{\"$G\": [\"2013\"]}"
expect "apply, lost connection (2013) at the first SHOW GRANTS: fails there, drops none" \
    '[ $RC != 0 ] && [ "$(failed_task)" = "Ask the server for each one'"'"'s grants" ] && [ "$(named)" = "$NAMED" ]'
reset_named
play denied-apply apply "{\"$G\": [\"1227\"]}"
expect "apply, permission error (1227) at the first SHOW GRANTS: fails there, drops none" \
    '[ $RC != 0 ] && [ "$(failed_task)" = "Ask the server for each one'"'"'s grants" ] && [ "$(named)" = "$NAMED" ]'
reset_named
play lost-report report "{\"$G\": [\"2013\"]}"
expect "report, lost connection (2013): fails, drops none" \
    '[ $RC != 0 ] && [ "$(failed_task)" = "Ask the server for each one'"'"'s grants" ] && [ "$(named)" = "$NAMED" ]'
reset_named
play recheck-lost apply "{\"$G\": [\"pass\", \"2013\"]}"
expect "apply, 1141 and then a lost connection at the check before the drop: fails there, drops none" \
    '[ $RC != 0 ] && [ "$(failed_task)" = "Check that the server still refuses each one with 1141" ] && [ "$(named)" = "$NAMED" ]'
reset_named
play recheck-matched apply "{\"$G\": [\"pass\", \"matched\"]}"
expect "apply, 1141 and then answered at the check before the drop: fails there, drops none" \
    '[ $RC != 0 ] && [ "$(failed_task)" = "Check that the server still refuses each one with 1141" ] && [ "$(named)" = "$NAMED" ]'

reset_named
play check check ""
expect "apply with --check drops none" '[ $RC = 0 ] && [ "$(named)" = "$NAMED" ]'
reset_named
play apply apply ""
expect "apply drops every account at a host name, and no control account" \
    '[ $RC = 0 ] && [ "$(named)" = "(none)" ] && [ "$(controls)" = 5 ]'
play apply-again apply ""
expect "apply again finds nothing to drop" '[ $RC = 0 ] && grep -q "\"msg\": \"nothing to drop\"" $LOG'

make_named
stop
start
play resolve-on apply ""
expect "with skip_name_resolve OFF, apply drops none" \
    '[ $RC = 0 ] && grep -q "skip_name_resolve is OFF" $LOG && [ "$(named)" != "(none)" ] && [ "$(controls)" = 5 ]'

stop
[ $FAILS = 0 ] && echo "all passed" || echo "$FAILS FAILED"
exit $((FAILS > 0))
