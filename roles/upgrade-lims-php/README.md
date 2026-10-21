# Ansible LIMS role: upgrade php

Moves an EL8 LIMS host (RHEL, Oracle Linux, Alma, Rocky 8) from the `php:7.2` module stream to `php:7.4`. Red Hat retired `php:7.2` in 2021, so it gets no security fixes, including none for PHP2Shell (CVE-2026-109618, CVE-2026-109619). `php:7.4` is supported for the life of RHEL 8, and its fixes arrive through `dnf`. Run it through `upgrade-php-playbook.yml`. ultrascan-tickets#1150.

## What it does

Modes are set by `lims_php_mode`; the playbook maps `-e run=1` to `upgrade` and `-e mitigate=1` to `mitigate`.

- `info` (default): reports the enabled stream, php version and package, whether the php-common changelog lists the PHP2Shell CVEs (vendor packages keep version 7.4.33 and add the fix as a new release, e.g. `7.4.33-7`), hand-built extensions and startup warnings. Changes nothing.
- `mitigate`: writes the PHP2Shell settings and restarts php-fpm if it is running. Works on any stream, so a `php:7.2` host can get them before it is upgraded.
  - `/etc/php.d/zz-us3lims-php2shell.ini`: `session.upload_progress.enabled = 0`
  - `/etc/php-fpm.d/zz-us3lims-php2shell.conf`: `pm.max_requests` and `session.upload_progress.enabled` for each pool in `lims_php_fpm_pools`. These override `www.conf`, which `config-lims-php` owns.
  - With `lims_php_mitigation: false` it removes both files instead.
- `upgrade`:
  1. Stops before changing anything if a hand-built extension (a `.so` in the extension directory that no rpm owns) has no recipe in `lims_php_pecl`.
  2. Saves the php state to `lims_php_state_dir`: `php -v`, `php -m`, php rpms, `pecl list`, `/etc/php*` and the hand-built `.so` files.
  3. Runs `dnf module switch-to php:7.4`. Config files the roles changed stay as they are; dnf writes the packaged ones beside them as `.rpmnew`. With `lims_php_rpm_dir` set, it then upgrades the installed php packages to the fallback RPMs in that controller directory (`php-fallback/build.sh`, ultrascan-tickets#1151); nothing happens once the vendor packages are newer.
  4. Rebuilds each hand-built extension that no longer loads with `pecl install -f`. The pinned tarball is fetched on the controller, checked against its sha256 and copied to the host, so the host needs no internet access.
  5. Applies the PHP2Shell settings and restarts php-fpm and httpd if they were running (see `lims_php_keep_stopped`).
  6. Reports whether the php-common changelog lists the PHP2Shell CVEs. Fails if the php version is not 7.4, if any module that loaded before is missing (php CLI and php-fpm; extensions php 7.4 itself dropped, `lims_php_modules_dropped`, such as wddx, are only reported), if php prints startup warnings, or if php-fpm or httpd is not running (except one left stopped with `lims_php_keep_stopped`).

  Running it again on an upgraded host changes nothing.

## Role Variables

See `defaults/main.yml`.

`lims_php_stream` - target stream, default `"7.4"`

`lims_php_pecl` - extensions that can be rebuilt: `imagick` 3.8.1 (LIMS captcha) and `pam` 2.2.5 (`pam_auth()` on PAM sites), each with a sha256 and build dependencies

`lims_php_pecl_cache` - controller directory for the tarballs, default `~/.cache/us3lims-pecl`. On a controller without internet access, copy `imagick-3.8.1.tgz` and `pam-2.2.5.tgz` there first.

`lims_php_ignore_extensions` - hand-built extensions to leave alone

`lims_php_mitigation`, `lims_php_fpm_pools`, `lims_php_fpm_max_requests` - the PHP2Shell settings, default on, pool `www`, `1`

`lims_php_rpm_dir` - controller directory of fallback php RPMs, default empty (none)

`lims_php_keep_stopped` - default `true`: after changes, php-fpm and httpd are restarted only if each was running when the play started. A service stopped beforehand stays stopped, and the final check does not expect it to run, so stopping httpd first keeps the LIMS down until the host has been checked. With `false`, both are restarted, which also starts a stopped one (ultrascan-tickets#1152).

## Fallback RPMs and dnf

The fallback release is the vendor release plus `.us3.1`, so it sorts above vendor 7.4.33-6 and below any vendor follow-up. A plain `dnf update` moves the host to the vendor fix once it ships. Do not run `dnf distro-sync` on a host with the fallback: it downgrades to the vendor packages in the repository, which until then are the unpatched 7.4.33-6.

## Rollback

`dnf module switch-to php:7.2`, then copy the saved `.so` files back into `/usr/lib64/php/modules` and restart php-fpm. This puts the host back on an unsupported php.
