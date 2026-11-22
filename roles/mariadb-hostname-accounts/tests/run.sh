#!/bin/bash
# Tests for the mariadb-hostname-accounts role (ultrascan-tickets#1290) in throwaway containers:
#   el8:  OL8,  MariaDB 10.3
#   el10: OL10, MariaDB 10.11
# each with ansible-core 2.16 and the collections pinned in requirements.yml.
# usage: roles/mariadb-hostname-accounts/tests/run.sh [el8|el10]...     (default: both)
# ENGINE=docker|podman picks the container engine (default: docker if installed, else podman).
# Exits non-zero if any test fails.
set -u
T=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$T/../../.." && pwd)
ENGINE=${ENGINE:-$(command -v docker >/dev/null 2>&1 && echo docker || echo podman)}
[ $# -gt 0 ] || set -- el8 el10
rc=0
for p in "$@"; do
    [ -f "$T/Containerfile.$p" ] || { echo "unknown platform '$p' (el8, el10)"; exit 2; }
    img=us3lims-roles-tests:mariadb-hostname-accounts-$p
    echo "== $p: building $img"
    ctx=$(mktemp -d)
    cp "$T/Containerfile.$p" "$ctx/Containerfile" && cp "$REPO/requirements.yml" "$ctx/"
    if ! $ENGINE build -q -t $img -f "$ctx/Containerfile" "$ctx" > /dev/null; then
        echo "FAIL $p: image build"; rc=1; rm -rf "$ctx"; continue
    fi
    rm -rf "$ctx"
    $ENGINE run --rm --hostname test-db.example --security-opt label=disable -v "$REPO":/repo:ro $img \
        bash /repo/roles/mariadb-hostname-accounts/tests/in-container.sh || rc=1
done
[ $rc = 0 ] && echo "all passed" || echo "FAILURES"
exit $rc
