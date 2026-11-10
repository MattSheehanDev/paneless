#!/usr/bin/env bash
# Usage: scripts/release.sh 1.2.0
# Runs the tests, then tags v<version> and pushes the tag. The Release workflow
# (.github/workflows/release.yml) builds Paneless.zip and publishes the GitHub release.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:?usage: scripts/release.sh <version>, e.g. 1.2.0}"
TAG="v${VERSION}"

if [[ -n "$(git status --porcelain)" ]]; then
    echo "Working tree is dirty; commit or stash first." >&2
    exit 1
fi
if git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null; then
    echo "Tag ${TAG} already exists." >&2
    exit 1
fi

./scripts/test.sh

git tag -a "$TAG" -m "Paneless ${VERSION}"
git push origin "$TAG"

echo "Pushed ${TAG}. Follow the release build at:"
echo "  https://github.com/MattSheehanDev/paneless/actions/workflows/release.yml"
