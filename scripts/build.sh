#!/usr/bin/env bash
# Builds build/Paneless.app (arm64), signed with SIGN_IDENTITY (default: the self-signed
# "Paneless Local Signing" identity, created on first run). A stable identity keeps the
# Screen Recording permission across rebuilds; SIGN_IDENTITY=- forces ad-hoc signing.
# VERSION=1.2.0 stamps the bundle's version.
set -euo pipefail
cd "$(dirname "$0")/.."

SIGN_IDENTITY="${SIGN_IDENTITY:-Paneless Local Signing}"
if [[ "$SIGN_IDENTITY" == "Paneless Local Signing" ]]; then
    ./scripts/create-signing-identity.sh "$SIGN_IDENTITY"
fi

swift build -c release --arch arm64
BIN_DIR=$(swift build -c release --arch arm64 --show-bin-path)

APP=build/Paneless.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Paneless" "$APP/Contents/MacOS/Paneless"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [[ -n "${VERSION:-}" ]]; then
    plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
fi

codesign --force --sign "$SIGN_IDENTITY" "$APP"
echo "Built $APP ($(codesign -dr - "$APP" 2>&1 | tail -1))"
