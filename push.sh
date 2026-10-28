#!/usr/bin/env bash
# Push the current branch to the remote, but only after the local checks pass.
#
#   ./push.sh               checks + tests, then git push (the pre-push review hook runs)
#   ./push.sh --no-verify   checks + tests, then git push --no-verify (skips the review hook)
#
# Everything printed here is also saved to .review/last-push.log, and the review hook saves its
# findings to .review/last-review.md, so Claude can read both ("Fix findings").
set -uo pipefail
cd "$(dirname "$0")"

NO_VERIFY=0
for arg in "$@"; do
  case "$arg" in
    --no-verify) NO_VERIFY=1 ;;
    -h | --help) sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "push.sh: unknown option '$arg' (only --no-verify)" >&2; exit 2 ;;
  esac
done

# ---- project-specific: the checks that must pass before any push ----
CHECKS=(
  "checks::swift run PagePalsChecks"
  "build::swift build"
)
# ----------------------------------------------------------------------

git config core.hooksPath .githooks   # use the hooks stored in this repo (repo-local setting)
chmod +x .githooks/pre-push

mkdir -p .review
LOG=.review/last-push.log
exec > >(tee "$LOG") 2>&1
echo "[push] $(date '+%Y-%m-%d %H:%M:%S') branch $(git rev-parse --abbrev-ref HEAD) @ $(git rev-parse --short HEAD)"

# The checks run on the files in the folder, but git pushes commits. With uncommitted changes the checks
# could pass on something that is not in the commits being pushed, so stop here.
if [ -n "$(git status --porcelain)" ]; then
  echo "[push] Uncommitted changes found. Commit or stash them first (git status), so the checks test what is pushed."
  git status --short
  exit 1
fi

for entry in "${CHECKS[@]}"; do
  label="${entry%%::*}"
  cmd="${entry#*::}"
  echo "[push] Running $label: $cmd"
  if ! bash -c "$cmd"; then
    echo "[push] FAILED: $label. Push stopped. (Log: $LOG -- tell Claude \"Fix findings\".)"
    exit 1
  fi
done
echo "[push] All checks passed."

args=()
[ "$NO_VERIFY" -eq 1 ] && args+=(--no-verify) && echo "[push] --no-verify: pushing WITHOUT the review hook."
# First push of a branch: set its upstream on origin.
git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1 ||
  args+=(-u origin "$(git rev-parse --abbrev-ref HEAD)")
# macOS ships bash 3.2, where an empty array counts as unset under `set -u`
git push ${args[@]+"${args[@]}"}
status=$?
[ $status -eq 0 ] && echo "[push] Pushed." || echo "[push] git push exited $status (see above)."
exit $status
