#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_BINARY="$(mktemp -t palette-tests)"
trap 'rm -f "$TEST_BINARY"' EXIT
swiftc -module-cache-path "${TMPDIR:-/tmp}/palette-module-cache" Sources/Models.swift Tests/ModelTests.swift -o "$TEST_BINARY"
"$TEST_BINARY"
swiftc -module-cache-path "${TMPDIR:-/tmp}/palette-module-cache" Sources/Models.swift Sources/Store.swift Tests/StoreTests.swift -o "$TEST_BINARY"
"$TEST_BINARY"
python3 Tests/UpdateFeedTests.py
./Scripts/fetch-sparkle.sh
swiftc -parse-as-library -module-cache-path "${TMPDIR:-/tmp}/palette-module-cache" Tests/UpdateSignatureTests.swift -o "$TEST_BINARY"
"$TEST_BINARY"
