#!/bin/bash
# Runs inside oraclelinux:8, started by rebase.sh.
set -euo pipefail

dnf -y -q install rpm-build git patch perl > /dev/null
rpm -i "/out/$SRPM" 2>/dev/null
rpmbuild -bp --nodeps /root/rpmbuild/SPECS/php.spec > /out/rebase-prep.log 2>&1
cd /root/rpmbuild/BUILD/php-7.4.33
git init -q && git add -A && git -c user.email=b@b -c user.name=b commit -qm "vendor 7.4.33-6, prepped"

# 1. everything but main/main.c and main/rfc1867.c applies unchanged
git apply --exclude=main/main.c --exclude=main/rfc1867.c "/out/$UPSTREAM"

# 2. main/main.c: hunk 1 (max_multipart_body_parts ini entry) is already in the vendor tree;
#    hunks 2 and 3 (request-shutdown state reset) are not
grep -q '"max_multipart_body_parts"' main/main.c
awk '/^diff --git a\/main\/main.c/ { p = 1 } /^diff --git a\/main\/php_variables.c/ { p = 0 } p' "/out/$UPSTREAM" |
    awk 'BEGIN { h = 0 } /^@@/ { h++ } h != 1' > /tmp/main.c-hunks2-3.diff
git apply /tmp/main.c-hunks2-3.diff

# 3. main/rfc1867.c: the vendor tree already has the body-parts limit and the (unsigned char)
#    ctype casts; apply the header filter and size_t changes, as in the PHP-8.0 backport
perl /src/rfc1867.pl main/rfc1867.c

git -c core.abbrev=8 diff > /out/php-cve-2026-109618-109619.patch
git diff --stat | tail -1
