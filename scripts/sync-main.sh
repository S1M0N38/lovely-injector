#!/usr/bin/env bash
# Keep the CI-only `main` branch rebased on top of `master`.
#
# `master` is a pristine mirror of ethangreen-dev/lovely-injector: never commit
# to it. `main` carries only release-pipeline changes (.github/workflows), so it
# can always be replayed on top of upstream.
set -euo pipefail

git fetch origin --prune
git fetch upstream --prune

git checkout master
git merge --ff-only origin/master

git checkout main
git rebase master
git push --force-with-lease origin main

echo "main is now: $(git log --oneline -1 main)"
