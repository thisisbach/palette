#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
RELEASE_TAG="${1:?Pass a stable release tag such as v1.2}"
# Validate before using the version in output paths.
VERSION="$(python3 -c 'import runpy,sys; print(runpy.run_path("Scripts/set-version.py")["release_version"](sys.argv[1]))' "$RELEASE_TAG")"
PALETTE_ARCHITECTURES="arm64 x86_64" PALETTE_RELEASE_VERSION="$VERSION" ./build.sh dist
codesign --verify --deep --strict dist/Palette.app
ARCHIVE="dist/Palette-$VERSION-macOS-universal.zip"
ditto -c -k --sequesterRsrc --keepParent dist/Palette.app "$ARCHIVE"
(cd dist && shasum -a 256 "Palette-$VERSION-macOS-universal.zip" > SHA256SUMS.txt)
echo "Prepared $ARCHIVE"
