#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
DESTINATION="${1:-build}"
ARCHITECTURES="${PALETTE_ARCHITECTURES:-$(uname -m)}"
./Scripts/fetch-sparkle.sh
mkdir -p "$DESTINATION/Palette.app/Contents/MacOS" "$DESTINATION/Palette.app/Contents/Resources" "$DESTINATION/Palette.app/Contents/Frameworks"
TEMPORARY="$(mktemp -d)"
trap 'rm -rf "$TEMPORARY"' EXIT
BINARIES=()
for ARCHITECTURE in $ARCHITECTURES; do
  swiftc -module-cache-path "${TMPDIR:-/tmp}/palette-module-cache" -O -parse-as-library \
    -target "$ARCHITECTURE-apple-macosx14.0" -F Vendor/Sparkle -framework Sparkle \
    -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
    Sources/*.swift -o "$TEMPORARY/Palette-$ARCHITECTURE"
  BINARIES+=("$TEMPORARY/Palette-$ARCHITECTURE")
done
lipo -create "${BINARIES[@]}" -output "$DESTINATION/Palette.app/Contents/MacOS/Palette"
cp Info.plist "$DESTINATION/Palette.app/Contents/Info.plist"
cp Resources/AppIcon.icns "$DESTINATION/Palette.app/Contents/Resources/"
cp Vendor/Sparkle/LICENSE "$DESTINATION/Palette.app/Contents/Resources/Sparkle-LICENSE.txt"
ditto Vendor/Sparkle/Sparkle.framework "$DESTINATION/Palette.app/Contents/Frameworks/Sparkle.framework"
if [ -n "${PALETTE_RELEASE_VERSION:-}" ]; then
  python3 Scripts/set-version.py "$PALETTE_RELEASE_VERSION" "$DESTINATION/Palette.app/Contents/Info.plist"
fi
codesign --force --sign - "$DESTINATION/Palette.app"
echo "Built $DESTINATION/Palette.app"
