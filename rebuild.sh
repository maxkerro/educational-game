#!/bin/bash
# Runs the checks, quits a running PagePals, rebuilds, and starts the fresh app.
# A failing check stops the script before the running app is touched.
set -euo pipefail
cd "$(dirname "$0")"

echo "== checks =="
swift run PagePalsChecks

pkill -x PagePals || true     # `open` would otherwise just bring the old copy to the front

swift build
./build-app.sh
open build/PagePals.app
