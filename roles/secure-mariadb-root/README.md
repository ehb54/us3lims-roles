# Ansible role: MariaDB root accounts without a password

Drops the MariaDB root accounts other than `root@localhost` that log in with no password. Run it through `secure-mariadb-root-playbook.yml` on existing hosts; `config-lims-database` applies it on new ones. ultrascan-tickets#1294.

## Why

`mysql_install_db` in MariaDB 10.3 (EL8) creates `root@127.0.0.1`, `root@::1` and `root@<hostname>` next to `root@localhost`, without passwords. `mysql_secure_installation` would give all of them root's password and remove `root@<hostname>`; `config-lims-database` set only `root@localhost`'s password (unless `root_old_db_pass` was given) and left the others without one. This role removes those, leaving `root@localhost` as on a fresh MariaDB 10.4+ install.

Nothing in the LIMS code logs in as root over TCP: dbutils (`db_config.php`, `my.cnf`) and the roles use `root@localhost` through the socket. A passwordless account also refuses a client that sends root's real password, so no tool can be using these accounts with a password today.

A fresh MariaDB 10.4+ install (EL9, EL10) has `root@localhost` only, so the role finds nothing to do there.

## What it does

Modes are set by `mariadb_root_mode`; the playbook maps `-e run=1` to `apply`.

- `report` (default): lists the root accounts and whether each has a password. It tries a passwordless root login over `127.0.0.1` and `::1`, and names the accounts `apply` would drop. Changes nothing.
- `apply`:
  1. Drops each root account other than `root@localhost` whose password is empty and whose plugin checks a password. Accounts that have a password, and `unix_socket` accounts, are left alone.
  2. Checks that a passwordless root login over `127.0.0.1` and `::1` is refused, and that root still logs in with the credentials below as `root@localhost`.
  3. Stops without changing anything if `root@localhost` itself has no password.

  Running it again changes nothing.

`--check` with `-e run=1` shows what `apply` would drop.

Root's credentials come from the dbutils defaults file `~us3/lims/database/utils/my.cnf` (`mariadb_root_my_cnf`). `config-lims-database` passes `mariadb_root_login_password` (`root_db_pass`) instead, since that file doesn't exist yet during a fresh install.

## Role Variables

See `defaults/main.yml`.

`mariadb_root_mode` - `report` (default) or `apply`

`mariadb_root_my_cnf` - defaults file with root's `[client]` password, default `~us3/lims/database/utils/my.cnf`

`mariadb_root_login_password` - root's password; when set, used instead of `mariadb_root_my_cnf`

`mariadb_root_socket` - default `/var/lib/mysql/mysql.sock`

`mariadb_root_check_hosts` - addresses the passwordless-login check tries, default `127.0.0.1` and `::1`

## Notes

- A dropped account comes back only if someone creates it. If something on a host turns out to need root over TCP, create that account with a password instead (config-lims-database's "Change root database password", run with `root_old_db_pass`, does that for all four hosts).
- Client hosts: run `report` first and hand the output to the site before any `apply`.
