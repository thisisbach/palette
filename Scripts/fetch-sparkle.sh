#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=2.10.1
SHA256=1a856d2a9edb8e628de88121d7be04cf0e2167f8641650b78fca00b14244cf27
DESTINATION="Vendor/Sparkle"
if [ -f "$DESTINATION/.verified-$SHA256" ] && [ -d "$DESTINATION/Sparkle.framework" ]; then exit 0; fi
TEMPORARY="$(mktemp -d)"
trap 'rm -rf "$TEMPORARY"' EXIT
curl --fail --location --silent --show-error --retry 3 \
  "https://github.com/sparkle-project/Sparkle/releases/download/$VERSION/Sparkle-$VERSION.tar.xz" -o "$TEMPORARY/Sparkle.tar.xz"
printf '%s  %s\n' "$SHA256" "$TEMPORARY/Sparkle.tar.xz" | shasum -a 256 -c -
mkdir -p "$DESTINATION"
tar -xf "$TEMPORARY/Sparkle.tar.xz" -C "$DESTINATION"
touch "$DESTINATION/.verified-$SHA256"
