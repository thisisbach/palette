#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
DESTINATION="${1:-build}"
mkdir -p "$DESTINATION/Palette.app/Contents/MacOS" "$DESTINATION/Palette.app/Contents/Resources"
swiftc -module-cache-path "${TMPDIR:-/tmp}/palette-module-cache" -O -parse-as-library -target "$(uname -m)-apple-macosx14.0" Sources/*.swift -o "$DESTINATION/Palette.app/Contents/MacOS/Palette"
cp Info.plist "$DESTINATION/Palette.app/Contents/Info.plist"
cp Resources/AppIcon.icns "$DESTINATION/Palette.app/Contents/Resources/"
codesign --force --sign - "$DESTINATION/Palette.app"
echo "Built $DESTINATION/Palette.app"
