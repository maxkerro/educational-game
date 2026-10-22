#!/bin/bash
# Quits a running PagePals, rebuilds, and starts the fresh app.
set -euo pipefail
cd "$(dirname "$0")"

pkill -x PagePals || true     # `open` would otherwise just bring the old copy to the front

swift build
./build-app.sh
open build/PagePals.app
