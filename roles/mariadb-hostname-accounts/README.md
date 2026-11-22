# Ansible role: MariaDB accounts at host names

Drops the MariaDB accounts whose host is a name (such as the server's own host name), which the server ignores because it runs with `skip-name-resolve`. Run it through `mariadb-hostname-accounts-playbook.yml` on existing hosts. `config-lims-database` applies it on every run. ultrascan-tickets#1290.

## Why

`config-lims-database` sets `skip-name-resolve` (Gary's settings). With it, MariaDB matches logins only against accounts at `localhost`, IP addresses and patterns, so an account at a host name never lets anyone in. Earlier versions of `create-grants.yml` still made `new_us3user`, `us3php`, `gfac` and `us3_notice` at `{{ server_name }}`, and `mysql_install_db` (10.3) also makes `root@<hostname>`.

Such an account is harmless for logins, but it breaks tools once the server has restarted:

- MariaDB 10.11 refuses a GRANT to it (ERROR 1133). MariaDB 10.3 only warns.
- On both versions, `SHOW GRANTS` for it fails (ERROR 1141). That stops `mysql_user` on a re-run of `create-grants.yml`, and a grant export such as dbutils' `uslims_daily_backup.php`.

A host built by the current `create-grants.yml` has none of these accounts, so the role finds nothing to do there.

## What it does

Modes are set by `mariadb_hostname_mode`. The playbook maps `-e run=1` to `apply`.

- `report` (default): shows `skip_name_resolve` and every account whose host is a name. For each one, it says whether the server ignores it, which the server shows by refusing `SHOW GRANTS` for it with error 1141. It also names the accounts `apply` would drop. Nothing is changed.
- `apply`:
  1. Asks the server again: `skip_name_resolve` must still be ON, and each account must still be refused with 1141.
  2. Drops each account at a host name that the server ignores.
  3. Checks that none of them is left.

Only error 1141 marks an account as ignored. Any other `SHOW GRANTS` error, such as a lost connection or a missing privilege, stops the run before anything is dropped.

  Running it again changes nothing.

A host counts as a name unless it is `localhost`, empty, an IP address, or a pattern (`%`, `_`, `/`, or an IPv6 `:`). That is the server's own test for whether a host needs a name lookup.

When `skip_name_resolve` is OFF, accounts at host names can match logins, so nothing is dropped and the report says so. An account at a host name that the server still answers for is left alone too.

`--check` with `-e run=1` shows what `apply` would drop.

`tests/run.sh` runs the role against throwaway MariaDB 10.3 and 10.11 servers in containers; see `tests/README.md`.

Root's credentials come from the dbutils defaults file `~us3/lims/database/utils/my.cnf` (`mariadb_hostname_my_cnf`). `config-lims-database` passes `mariadb_hostname_login_password` (`root_db_pass`) instead, since that file doesn't exist yet during a fresh install. The mysql tasks run with the first python that can import `pymysql`, as in `secure-mariadb-root`.

## Role Variables

See `defaults/main.yml`.

`mariadb_hostname_mode` - `report` (default) or `apply`

`mariadb_hostname_my_cnf` - defaults file with root's `[client]` password, default `~us3/lims/database/utils/my.cnf`

`mariadb_hostname_login_password` - root's password; when set, used instead of `mariadb_hostname_my_cnf`

`mariadb_hostname_socket` - default `/var/lib/mysql/mysql.sock`

`mariadb_hostname_python_candidates` - pythons tried for PyMySQL after the inventory's or discovered one

## Notes

- Nothing can log in through a dropped account while `skip-name-resolve` is set, so dropping one changes no login.
- A datadir copied from an EL8 host to a new one carries these accounts with it. Run the role after the copy.
- Client hosts: run `report` first and hand the output to the site before any `apply`.
