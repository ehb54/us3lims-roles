#!/bin/bash
# Runs inside oraclelinux:8, started by build.sh: adds the PHP2Shell patch to the vendor php spec
# and builds it as an unprivileged user (several php self-tests fail as root).
#
# The release becomes <vendor release>.us3.1, e.g. 6.module+el8.10.0+91013+9868f608.us3.1:
# newer than the vendor's 7.4.33-6, older than any vendor follow-up (7.module..., 6.1.module...,
# 6.module....1), so "dnf update" moves a host to the vendor's fixed packages once they ship.

set -euo pipefail

dnf -y -q install rpm-build dnf-plugins-core make gcc gcc-c++ > /dev/null
dnf config-manager --set-enabled ol8_codeready_builder
dnf -y -q module enable php:7.4

useradd -m builder
su - builder -c "rpm -i /out/$SRPM"
spec=/home/builder/rpmbuild/SPECS/php.spec
dnf -y -q builddep "$spec" > /dev/null

vrel=$(rpm -qp --qf '%{RELEASE}' "/out/$SRPM" 2>/dev/null)
vbase=${vrel%%.*}
vdist=.${vrel#*.}

cp /src/php-cve-2026-109618-109619.patch /home/builder/rpmbuild/SOURCES/
perl -0pi -e "s/^Release: $vbase%\{\?dist\}\n/Release: $vbase%{?dist}.us3.1\n/m or die qq(Release line\n)" "$spec"
perl -0pi -e 's/^(Patch241: .*\n)/${1}Patch242: php-cve-2026-109618-109619.patch\n/m or die qq(Patch241 line\n)' "$spec"
perl -0pi -e 's/^(%patch -P241 .*\n)/${1}%patch -P242 -p1 -b .cve109618\n/m or die qq(%patch -P241 line\n)' "$spec"
# values go through the environment: an @ in PACKAGER would interpolate in a perl string
CL_DATE=$(LC_ALL=C date '+%a %b %d %Y') VBASE=$vbase perl -0pi -e '
    my $e = "* $ENV{CL_DATE} $ENV{PACKAGER} - 7.4.33-$ENV{VBASE}.us3.1\n"
        . "- Fix RCE via OOM corruption (GHSA-w8hw-w9fx-j79w)\n  CVE-2026-109618\n"
        . "- Fix RCE via stale global state (GHSA-6wmf-4rv5-p3rp)\n  CVE-2026-109619\n"
        . "- php-src PHP-7.4-CVE-2026-109618-109619 (712e60f9) rebased on 7.4.33-$ENV{VBASE}\n\n";
    s/^%changelog\n/%changelog\n$e/m or die "changelog\n";' "$spec"
chown -R builder: /home/builder/rpmbuild

su - builder -c "cd ~/rpmbuild/SPECS && rpmbuild -ba --define 'dist $vdist' --define 'runselftest $RUNSELFTEST' php.spec" > /out/build.log 2>&1

mkdir -p /out/RPMS /out/SRPMS
cp /home/builder/rpmbuild/RPMS/*/*.rpm /out/RPMS/
cp /home/builder/rpmbuild/SRPMS/*.rpm /out/SRPMS/
chown -R --reference=/out /out/RPMS /out/SRPMS /out/build.log
grep -E '^(Tests (failed|passed))' /out/build.log || true
ls /out/SRPMS
