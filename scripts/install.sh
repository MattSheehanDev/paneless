#!/usr/bin/env bash
# Builds Paneless, installs it to ~/Applications and (re)launches it.
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/build.sh

DEST="$HOME/Applications"
mkdir -p "$DEST"
pkill -x Paneless 2>/dev/null || true
for _ in {1..50}; do pgrep -x Paneless >/dev/null || break; sleep 0.1; done
rm -rf "$DEST/Paneless.app"
cp -R build/Paneless.app "$DEST/"
# LaunchServices can briefly reject a just-replaced bundle (error -600), so retry the launch.
for attempt in 1 2 3 4 5; do
    open "$DEST/Paneless.app" 2>/dev/null && break
    [[ $attempt -eq 5 ]] && { echo "Could not launch $DEST/Paneless.app" >&2; exit 1; }
    sleep 1
done
echo "Installed to $DEST/Paneless.app — use ⇧⌘9 or the menu bar icon to capture."
