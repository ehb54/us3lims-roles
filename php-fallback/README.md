# PHP2Shell fallback build for EL8 (php:7.4)

This is a stopgap for the LIMS hosts until Red Hat or Oracle ship a `php:7.4` errata that fixes PHP2Shell (CVE-2026-109618, CVE-2026-109619). It is the vendor's php 7.4.33-6 source RPM plus the php.net 7.4 backport, rebased onto it. Tickets: ultrascan-tickets#1151, which follows #1150.

## Why a rebuild of the vendor package

- php.net fixed only 8.2 and later. For 7.4 it published a source backport: php-src branch `PHP-7.4-CVE-2026-109618-109619`, commit 712e60f9, described as a "minimal mitigation for EOL version".
- That commit sits on upstream 7.4.33. Upstream 7.4.33 lacks the 33 CVE fixes Red Hat has added to `php:7.4` since 2022.
- So `php-cve-2026-109618-109619.patch` is that commit rebased onto the vendor's 7.4.33-6 sources:
  - 15 files apply unchanged.
  - `main/main.c`: the vendor tree already has hunk 1, the `max_multipart_body_parts` ini entry. Hunks 2 and 3 (the request-shutdown state reset) are not there and are applied. A plain `patch` run skips all three silently.
  - `main/rfc1867.c`: the vendor tree already has the body-parts limit (CVE-2023-0662) and the `(unsigned char)` ctype casts. Only the header filter and the `size_t` changes are applied, identical to the PHP-8.0 backport; `patch` would have added a second body-parts limit.
  - `rebase/rebase.sh <dir>` re-derives the patch in a container and reproduces it byte for byte.

## Build

```bash
php-fallback/build.sh /path/to/out
```

- It needs docker and internet access.
- It downloads and checks Oracle's 7.4.33-6 source RPM, adds the patch as `Patch242`, and builds in `oraclelinux:8` as an unprivileged user. That takes about 20 minutes, including php's self-tests.
- Output: `RPMS/`, `SRPMS/` and `build.log`.
- The release is the vendor's plus `.us3.1`, i.e. `7.4.33-6.module+el8.10.0+91013+9868f608.us3.1`. It sorts above the vendor 7.4.33-6 on Oracle, RHEL and Alma, and below any vendor follow-up (`7.module…`, `6.1.module…`, `6.module….1`).
- The rpm changelog names both CVEs.

## Install

Upgrade the host to `php:7.4` and put the fallback over it, pointing at the `RPMS/` directory on the controller:

```bash
ansible-playbook upgrade-php-playbook.yml -l <host> -e run=1 -e lims_php_rpm_dir=/path/to/out/RPMS
```

- Only the php packages already installed are upgraded.
- The PECL extensions built for 7.4 keep working.
- The playbook report shows "PHP2Shell fix in the installed php packages: yes".

When the vendor errata ships, `dnf update` replaces the fallback; this was tested with a stand-in modular errata repository. Do **not** run `dnf distro-sync` before then: it downgrades to the unpatched vendor 7.4.33-6 in the repositories.

## Behaviour changes, all from upstream's minimal mitigation

- **A request that exceeds `memory_limit` ends its process.** The process prints "Fatal error: Allowed memory size … exhausted" to stderr and exits instead of unwinding (`longjmp`) back into the request.
  - php-fpm starts a new worker.
  - The client gets a 503 from httpd instead of PHP's 500.
  - Shutdown functions and destructors do not run.
  - The fatal error does not reach the php-fpm log unless the pool has `catch_workers_output = yes`.
- **Session upload progress is disabled in the code**, whatever `session.upload_progress.enabled` says. The LIMS does not use it.
- **Not included:** the per-extension out-of-memory hardening of the full 8.2.35 fix (about 100 more files).

## Tests (disposable containers only)

**php self-tests.** Compared with an unmodified 7.4.33-6 build, the extra failures are exactly the ones the mitigation causes: 8 session `rfc1867` upload-progress tests and `tests/lang/bug45392` (the fatal-error output format).

**`tests/upstream-tests.sh`** runs the php-src regression tests from the 8.2.35 fix that apply to 7.4. Results:
- **Out of memory while parsing a multipart POST:** vendor 7.4.33-6 exits 255 with no output on all 35 requests (the bailout path of CVE-2026-109618); the fallback prints the fatal error and exits 1.
- **One part with 150,000 headers:** vendor runs out of memory; the fallback keeps only Content-Disposition/Content-Type and parses it.
- **The CLI-server next-request tests fail by design,** since the server process exits on out-of-memory.

**`tests/fpm-worker-test.sh`** runs through httpd + php-fpm, with one worker and an 8M limit:

| case | vendor 7.4.33-6 | fallback |
|---|---|---|
| A: out of memory while parsing a multipart POST | worker exits (70), replaced | worker exits (1), replaced |
| B: out of memory while the script runs | same worker serves the next request | worker exits (1), replaced |
| C: upload progress with a cookie, no `session_start()` | handler writes the session | handler does not run |
