#!/usr/bin/env bash
# Runs any Flutter/Dart command inside the pinned Docker image, so the SDK
# never has to be installed on the host. See tool/flutter.ps1 for details.
#
# Usage:
#   ./tool/flutter.sh test
#   ./tool/flutter.sh analyze
set -euo pipefail

IMAGE="ghcr.io/cirruslabs/flutter:stable"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# MSYS_NO_PATHCONV avoids Git-Bash mangling the /app path on Windows.
MSYS_NO_PATHCONV=1 docker run --rm \
    -v "${REPO}:/app" \
    -v aetherbook_pubcache:/root/.pub-cache \
    -w /app \
    "${IMAGE}" \
    flutter "$@"
