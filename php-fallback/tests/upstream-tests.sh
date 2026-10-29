#!/bin/bash
# upstream-tests.sh: run the php-src PHP2Shell regression tests that apply to 7.4 against the
# installed /usr/bin/php and /usr/bin/php-cgi (php-cli package). Run as an unprivileged user in a
# disposable container; needs curl. Writes everything under the given work dir.
#
# The tests come from the 8.2.35 fix (php-src 01a40e89): multipart parsing under a small
# memory_limit (tests/basic/oom_rfc1867_*, GHSA-f883-*) and request-to-request state
# (sapi/cli/tests/oom_*_next_request). Many expect 8.x output, so compare builds, not PASS counts:
# on the vendor 7.4.33-6, an OOM while parsing leaves php-cgi with exit 255 and no output (the
# bailout path of CVE-2026-109618); with the fix it prints the fatal error and exits 1.
#
# usage: upstream-tests.sh <work dir>

set -euo pipefail

if [ $# -ne 1 ]; then
    sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
fi
mkdir -p "$1"
cd "$1"

fix=01a40e89fbfc
raw=https://raw.githubusercontent.com/php/php-src
fetch() { mkdir -p "$(dirname "$2")"; curl -sSfL -o "$2" "$raw/$1/$2"; }

fetch php-7.4.33 run-tests.php
fetch php-7.4.33 sapi/cli/tests/php_cli_server.inc
for t in oom_rfc1867.inc oom_rfc1867_skipif.inc oom_rfc1867_session_skipif.inc oom_rfc1867_mb_skipif.inc \
         oom_rfc1867_target.inc oom_rfc1867_array_upload_name oom_rfc1867_early_report oom_rfc1867_field_name \
         oom_rfc1867_files oom_rfc1867_files_registration oom_rfc1867_files_registration_full_path \
         oom_rfc1867_form_value oom_rfc1867_header_continuation oom_rfc1867_header_count \
         oom_rfc1867_long_header_line oom_rfc1867_mb_encoding oom_rfc1867_post_vars \
         oom_rfc1867_upload_progress; do
    case $t in *.inc) fetch $fix tests/basic/$t ;; *) fetch $fix tests/basic/$t.phpt ;; esac
done
for n in 001 002 003 004 005 006 007 008 009 010 011; do fetch $fix tests/basic/GHSA-f883-x959-3vr9_$n.phpt; done
fetch $fix tests/basic/GHSA-f883-x959-3vr9_007.inc
fetch $fix sapi/cli/tests/oom_request_parsing_next_request.phpt
fetch $fix sapi/cli/tests/oom_shutdown_function_next_request.phpt

# PHP 8 function used by the cli tests
printf '%s\n' '<?php' "if (!function_exists('str_contains')) { function str_contains(\$h, \$n) { return \$n === '' || strpos(\$h, \$n) !== false; } }" > polyfill.php

# log the php-cgi exit status of each multipart request to tests/basic/cgi-exit.log
php -r '$f = "tests/basic/oom_rfc1867.inc"; $s = file_get_contents($f);
    $s = str_replace("    proc_close(\$handle);\n",
        "    file_put_contents(__DIR__ . \"/cgi-exit.log\", basename(\$_SERVER[\"SCRIPT_FILENAME\"], \".php\") . \" \" . proc_close(\$handle) . \"\\n\", FILE_APPEND);\n",
        $s, $n);
    file_put_contents($f, $s); if ($n != 1) { exit(1); }'
rm -f tests/basic/cgi-exit.log

rpm -q php-cli php-common || true
echo "PHP2Shell CVE lines in the php-common changelog: $(rpm -q --changelog php-common | grep -c -E 'CVE-2026-10961[89]' || true)"
TEST_PHP_EXECUTABLE=/usr/bin/php TEST_PHP_CGI_EXECUTABLE=/usr/bin/php-cgi \
    php run-tests.php -q -d auto_prepend_file="$PWD/polyfill.php" tests/basic sapi/cli/tests > run-tests.log 2>&1 || true
tr '\r' '\n' < run-tests.log | grep -E '^(PASS|FAIL|SKIP|BORK) ' | sed -E 's/^(\w+) .*\[([^]]+)\].*/\1 \2/' | sort -k2
echo "php-cgi exit status per multipart test (1 = fatal error and exit, 255 = bailout, 0 = parsed):"
sort tests/basic/cgi-exit.log | uniq -c | awk '{ printf "  %-44s exit %-4s x%s\n", $2, $3, $1 }'
