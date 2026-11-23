#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_BINARY="$(mktemp -t palette-tests)"
trap 'rm -f "$TEST_BINARY"' EXIT
swiftc -module-cache-path "${TMPDIR:-/tmp}/palette-module-cache" Sources/Models.swift Tests/ModelTests.swift -o "$TEST_BINARY"
"$TEST_BINARY"
swiftc -module-cache-path "${TMPDIR:-/tmp}/palette-module-cache" Sources/Models.swift Sources/Store.swift Tests/StoreTests.swift -o "$TEST_BINARY"
"$TEST_BINARY"
