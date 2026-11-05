# Ansible role: Apache and php security settings

Hides the Apache and php version banners, sends browser security headers and sets the php session cookie flags on EL8/EL9 hosts (RHEL, Oracle Linux, Alma, Rocky) running Apache with php-fpm: LIMS hosts and other web hosts. Run it through `web-hardening-playbook.yml`; `install-lims-server-playbook.yml` applies it to new LIMS hosts. ultrascan-tickets#1193.

## Why

External security scorecards read the `Server` and `X-Powered-By` headers. EL8/EL9 keep the upstream version numbers (Apache 2.4.37, OpenSSL 1.1.1k, PHP 7.4.33 on EL8) and backport the security fixes, so a scanner that maps versions to upstream CVE lists reports CVEs that are already fixed. Hiding the banners removes that false signal; it fixes nothing, and vendor updates stay the real control. The headers and the cookie flags are real hardening:

- `X-Content-Type-Options: nosniff`: browsers do not guess a response's type (e.g. run an uploaded file as a script).
- `X-Frame-Options: SAMEORIGIN` and `Content-Security-Policy: frame-ancestors 'self'`: other sites cannot frame these pages (clickjacking).
- `Referrer-Policy: strict-origin-when-cross-origin`: the browsers' default, stated.
- `Strict-Transport-Security` (optional): browsers use https only.
- `TraceEnable Off`: no HTTP TRACE.
- php `session.cookie_httponly`, `session.cookie_secure`, `session.cookie_samesite = Lax`: page scripts cannot read the session cookie, it is sent over https only, and requests started by other sites carry it only when following a link. `session.use_strict_mode`: php refuses session ids it did not create (session fixation).

The LIMS code (us3lims_dbinst, us3lims_newinst, us3lims_common, us3lims_gridctl) has no cross-site frames, does not read the session cookie in JavaScript and sets no session ids by hand. A full Content-Security-Policy is not set: the LIMS uses inline scripts.

## What it does

Modes are set by `web_hardening_mode`; the playbook maps `-e run=1` to `apply` and `-e remove=1` to `remove`.

- `report` (default): shows whether httpd and php-fpm run, the php version and session settings, php-fpm pool settings that override them, other Apache files that set the same directives or headers, whether the two files differ from what `apply` writes, and the response headers of `web_hardening_check_urls` (default `http://localhost/` and `https://localhost/`, requested by the host itself). Changes nothing.
- `apply`:
  1. Writes `/etc/httpd/conf.d/zz-us3lims-security.conf`: `ServerTokens Prod`, `ServerSignature Off`, `TraceEnable Off`, removes `X-Powered-By` and sets the headers on every response of every virtual host. httpd checks the new file with the installed configuration (`httpd -t`) before it replaces the old one, so a file httpd rejects is never installed.
  2. Writes `/etc/php.d/zz-us3lims-security.ini` (`expose_php = Off` and the session settings), read after `/etc/php.ini`, which `config-lims-php` owns, by the php CLI and php-fpm. Runs `php-fpm -t`; if it fails, the file is removed again.
  3. If a file changed and the service is running, reloads php-fpm (graceful; it replaces its workers) and restarts httpd. A stopped service stays stopped and reads the files when it starts. httpd is never gracefully reloaded, because that can hang (see Notes). It gets Apache's restart signal (SIGHUP): workers stop at once, requests in progress are cut off, and new workers start within about a second while the listening sockets stay open. Then the role waits for the first check page that answered before the change, up to about 1.5 minutes (`web_hardening_wait_retries`). If it does not answer, httpd is stopped and started (`systemctl restart`, which can take up to 90 s while requests in progress finish). If it still does not answer, the Apache file is removed again, httpd stopped and started, and the run fails, saying whether httpd answers without the file (ultrascan-tickets#1197). Before changing anything, apply stops if httpd runs but none of the check pages answers.
  4. Verifies: php reports the settings without startup warnings, no php-fpm pool overrides them, and each check URL that answers has no version in `Server`, no `X-Powered-By`, and the headers as set (HSTS on https URLs only).

  Running it again changes nothing.
- `remove`: removes both files, reloads php-fpm and restarts httpd if they are running, and waits for httpd to answer as in `apply` (stopping and starting it if needed).

`--check --diff` with `-e run=1` shows what `apply` would write.

## Role Variables

See `defaults/main.yml`. Per-host values go in the inventory.

`web_hardening_nosniff` - `X-Content-Type-Options: nosniff`, default `true`

`web_hardening_frame_options` - `X-Frame-Options`, default `SAMEORIGIN`; `""` sends none. Only pages of the same origin (scheme, host name, port) may then frame these pages; another host name, a subdomain too, is another origin. On a host whose sites frame each other across host names, set `""` and `web_hardening_frame_ancestors` to the allowed origins (`"'self' https://www.example.org"`).

`web_hardening_frame_ancestors` - `Content-Security-Policy: frame-ancestors`, default `'self'`; `""` sends none

`web_hardening_referrer_policy` - default `strict-origin-when-cross-origin`; `""` sends none

`web_hardening_hsts_max_age` - `Strict-Transport-Security` max-age in seconds, default `0` (none). A browser that has seen it refuses plain http and any certificate error on that host name for that long, so set it only where the certificate is CA-signed and renews (`31536000` = one year). Sent on https responses only. `web_hardening_hsts_include_subdomains`, default `false`, extends it to every subdomain.

`web_hardening_expose_php` - default `false`

`web_hardening_cookie_httponly`, `web_hardening_cookie_secure`, `web_hardening_cookie_strict_mode` - default `true`. Set `web_hardening_cookie_secure: false` on a host that serves php sessions over plain http; LIMS hosts redirect http to https.

`web_hardening_cookie_samesite` - default `Lax`; `""` leaves php's default (none). php 7.3 and later.

`web_hardening_check_urls` - pages the host requests from itself, default `http://localhost/` and `https://localhost/`

`web_hardening_request_timeout` - seconds per check request, default `5`; `web_hardening_wait_retries` - requests (2 s apart) while waiting for httpd after a restart, default `15`

`web_hardening_apache_file`, `web_hardening_php_file` - the two files

## Notes

- A virtual host that sets one of these headers itself overrides this role's value for that host; `report` lists such settings and `apply` then fails its header check.
- A php-fpm pool's `php_value` / `php_admin_value` overrides `/etc/php.d`; `apply` fails if a pool sets one of these settings.
- The role does not change TLS settings; mod_ssl follows the system crypto policy on EL8/EL9.
- A graceful reload (`systemctl reload httpd`, `apachectl graceful`, and certbot's renewals) starts new httpd processes while the old ones finish their requests. With the event MPM, on a host whose `ServerLimit` × `ThreadsPerChild` equals `MaxRequestWorkers`, no process slot is free for the new ones. httpd then accepts connections but answers none, and `error_log` repeats `AH03490: scoreboard is full, not at MaxRequestWorkers.Increase ServerLimit.` until the old processes exit. That is why the role restarts httpd instead. Headroom in `ServerLimit` would also keep other graceful reloads from hanging, but changing MPM limits on a busy production host needs its own testing; the role leaves them alone. ultrascan-tickets#1197
