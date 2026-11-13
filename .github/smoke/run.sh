#!/usr/bin/env bash
# Host side of the container smoke test.
#
#   run.sh <image> <pass|fail>
#
# Extracts the downloaded liblovely.tar.gz into ./dist, runs the in-container
# check against <image>, and asserts the outcome. "fail" is used deliberately:
# it pins the artifact's glibc floor (e.g. the native x86_64 build must NOT load
# on debian:12), so the release notes can't silently go stale.
set -euo pipefail

image="${1:?usage: run.sh <image> <pass|fail>}"
expect="${2:?usage: run.sh <image> <pass|fail>}"

tar xzf dist/lovely-*.tar.gz -C dist
ls -l dist

set +e
docker run --rm \
    -v "${PWD}/.github/smoke:/smoke:ro" \
    -v "${PWD}/dist:/dist:ro" \
    "${image}" bash /smoke/in-container.sh 2>&1 | tee /tmp/smoke.log
rc="${PIPESTATUS[0]}"
set -e

echo "::group::container output"
cat /tmp/smoke.log
echo "::endgroup::"
echo "exit code ${rc}, expected: ${expect}"

if [ "${expect}" = "pass" ] && [ "${rc}" -ne 0 ]; then
    echo "::error::expected the artifact to work in ${image}, but it failed"
    exit 1
fi
if [ "${expect}" = "fail" ] && [ "${rc}" -eq 0 ]; then
    echo "::error::expected the artifact to fail in ${image}, but it worked"
    exit 1
fi

echo "OK: ${image} behaved as expected (${expect})"
