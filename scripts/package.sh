#!/usr/bin/env bash
# Usage: scripts/package.sh 1.2.0
# Builds an ad-hoc signed Paneless.app and produces build/Paneless.zip and build/release-notes.md.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:?usage: scripts/package.sh <version>, e.g. 1.2.0}"
ZIP="build/Paneless.zip"
NOTES_FILE="build/release-notes.md"

SIGN_IDENTITY=- VERSION="$VERSION" ./scripts/build.sh

# ditto keeps the code signature and bundle metadata intact, unlike plain zip.
rm -f "$ZIP"
ditto -c -k --keepParent build/Paneless.app "$ZIP"

cat > "$NOTES_FILE" <<'EOF'
## Install

1. Download **Paneless.zip** below and unzip it.
2. Move **Paneless.app** to your Applications folder and open it.
3. macOS will block it the first time because it isn't notarized. Open **System Settings → Privacy & Security**, scroll down, and click **Open Anyway** next to Paneless.
4. Allow Paneless under **System Settings → Privacy & Security → Screen & System Audio Recording**, then reopen it.

Or, from Terminal:

```bash
xattr -dr com.apple.quarantine /Applications/Paneless.app && open /Applications/Paneless.app
```

Press **⇧⌘9** to capture. Requires macOS 14 or later on Apple Silicon.
EOF

echo "Packaged $ZIP"
