#!/usr/bin/env bash
# Runs the test suite. With only the Command Line Tools installed, SwiftPM intermittently fails to
# load the Swift Testing macro plugin ("plugin for module 'TestingMacros' not found"), so pass its
# path explicitly.
set -euo pipefail
cd "$(dirname "$0")/.."

CLT_DIR=/Library/Developer/CommandLineTools
FLAGS=()
if [[ "$(xcode-select -p 2>/dev/null)" == "$CLT_DIR" ]]; then
    FLAGS=(-Xswiftc -plugin-path -Xswiftc "$CLT_DIR/usr/lib/swift/host/plugins/testing")
fi

swift test ${FLAGS[@]+"${FLAGS[@]}"} "$@"
