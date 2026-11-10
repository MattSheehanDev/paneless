#!/usr/bin/env bash
# With the Command Line Tools toolchain, compiling the tests intermittently fails to load the
# Swift Testing macro plugin ("plugin for module 'TestingMacros' not found") even though the
# plugin is installed. Retry only that failure; any other failure is reported immediately.
set -uo pipefail
cd "$(dirname "$0")/.."

log=$(mktemp)
trap 'rm -f "$log"' EXIT

for attempt in 1 2 3 4 5; do
    swift test "$@" 2>&1 | tee "$log"
    status=${PIPESTATUS[0]}
    if [[ $status -eq 0 ]] || ! grep -q "plugin for module 'TestingMacros' not found" "$log"; then
        exit "$status"
    fi
    echo "Swift Testing macro plugin failed to load; retrying ($attempt/5)..." >&2
done
exit "$status"
