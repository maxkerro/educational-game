#!/bin/bash
# Pushes the current branch to GitHub. The pre-push hook (hooks/pre-push) first checks that
# the commits were made by an Opus model and stops the push if not.
set -euo pipefail
cd "$(dirname "$0")"

git config core.hooksPath hooks      # use the hooks stored in this repo
chmod +x hooks/pre-push

branch="$(git rev-parse --abbrev-ref HEAD)"
echo "Pushing $branch to origin ..."
git push -u origin "$branch"
