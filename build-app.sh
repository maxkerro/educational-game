#!/bin/bash
# Builds build/PagePals.app using only the Swift toolchain from the Command Line Tools (no Xcode).
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release --product PagePals

APP="build/PagePals.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/PagePals" "$APP/Contents/MacOS/PagePals"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"

# Ad-hoc signature so macOS on Apple Silicon will run the bundle locally.
codesign --force --sign - "$APP"

echo "Built $APP"
echo "Start it with: open $APP"
