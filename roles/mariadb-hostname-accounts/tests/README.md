# Tests for mariadb-hostname-accounts

Run in throwaway containers, never against a real server: OL8 with MariaDB 10.3, and OL10 with MariaDB 10.11. Each has ansible-core 2.16 and the collections pinned in `requirements.yml`.

```
roles/mariadb-hostname-accounts/tests/run.sh          # both platforms
roles/mariadb-hostname-accounts/tests/run.sh el10     # one: el8 or el10
ENGINE=podman roles/mariadb-hostname-accounts/tests/run.sh
```

It exits non-zero if a test fails. The images (`us3lims-roles-tests:mariadb-hostname-accounts-el8` and `-el10`) stay until you remove them with `docker rmi` or `podman rmi`.

The server runs with `skip-name-resolve`, as config-lims-database sets it. It has accounts at a host name, made before a restart so that it ignores them, and control accounts at localhost, IP addresses and patterns. `mariadb-hostname-accounts-playbook.yml` then runs against it:

- report lists the accounts at a host name and drops none;
- `SHOW GRANTS` errors other than 1141, injected through a patched copy of the collections (`inject.py`):
  - a lost connection (2013) or a permission error (1227) at the first check fails the play there, in apply and report mode;
  - a lost connection or an answer at the check right before the drop fails the play there;
  - none of them drops anything;
- `--check` drops nothing;
- apply drops every account at a host name and no control account;
- a second apply finds nothing to drop;
- with `skip_name_resolve` OFF, apply drops nothing.
