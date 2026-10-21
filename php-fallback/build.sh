#!/bin/bash
# Build the PHP2Shell fallback php RPMs for EL8 (ultrascan-tickets#1151): the vendor php:7.4
# 7.4.33-6 source RPM plus php-cve-2026-109618-109619.patch, in an oraclelinux:8 container.
#
# usage: build.sh <output dir>
#   needs docker and internet access; about 20 minutes with the php self-tests on a large host
#   (export RUNSELFTEST=0 to skip them). Output: RPMS/, SRPMS/ and build.log in <output dir>.

set -euo pipefail

if [ $# -ne 1 ]; then
    sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
fi

here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$1"
out=$(cd "$1" && pwd)

# Oracle publishes the source of Red Hat's php:7.4 errata; this is 7.4.33-6 (2026-08)
srpm=php-7.4.33-6.module+el8.10.0+91013+9868f608.src.rpm
srpm_url=https://yum.oracle.com/repo/OracleLinux/OL8/appstream/x86_64/getPackageSource/$srpm
srpm_sha256=dfb6d87f2db700254568d9a0a29c1da92314bef8e20077ba371f33209fa201a1

if [ ! -e "$out/$srpm" ]; then
    curl -sSfL -o "$out/$srpm.part" "$srpm_url"
    mv "$out/$srpm.part" "$out/$srpm"
fi
echo "$srpm_sha256  $out/$srpm" | sha256sum -c -

docker run --rm \
    -e SRPM="$srpm" \
    -e RUNSELFTEST="${RUNSELFTEST:-1}" \
    -e PACKAGER="${PACKAGER:-UltraScan LIMS fallback build <root@localhost>}" \
    -v "$here:/src:ro" -v "$out:/out" \
    oraclelinux:8 /src/build-in-container.sh
