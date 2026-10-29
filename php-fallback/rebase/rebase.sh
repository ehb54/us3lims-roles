#!/bin/bash
# Re-derive ../php-cve-2026-109618-109619.patch: the php.net 7.4 PHP2Shell backport (php-src
# commit 712e60f9, branch PHP-7.4-CVE-2026-109618-109619) rebased onto the vendor php 7.4.33-6
# sources, in an oraclelinux:8 container. See ../README.md for what the rebase changes and why.
#
# usage: rebase.sh <work dir>    (needs docker; writes <work dir>/php-cve-2026-109618-109619.patch)

set -euo pipefail

if [ $# -ne 1 ]; then
    sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
fi

here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$1"
out=$(cd "$1" && pwd)

srpm=php-7.4.33-6.module+el8.10.0+91013+9868f608.src.rpm
srpm_url=https://yum.oracle.com/repo/OracleLinux/OL8/appstream/x86_64/getPackageSource/$srpm
srpm_sha256=dfb6d87f2db700254568d9a0a29c1da92314bef8e20077ba371f33209fa201a1
upstream=712e60f9edfd03f0960fc4fc3c2c375f42b90aa2

[ -e "$out/$srpm" ] || curl -sSfL -o "$out/$srpm" "$srpm_url"
echo "$srpm_sha256  $out/$srpm" | sha256sum -c -
curl -sSfL -o "$out/upstream-$upstream.patch" "https://github.com/php/php-src/commit/$upstream.patch"
head -1 "$out/upstream-$upstream.patch" | grep -q "^From $upstream " || { echo "unexpected upstream patch"; exit 1; }

docker run --rm -e SRPM="$srpm" -e UPSTREAM="upstream-$upstream.patch" \
    -v "$here:/src:ro" -v "$out:/out" oraclelinux:8 /src/rebase-in-container.sh
