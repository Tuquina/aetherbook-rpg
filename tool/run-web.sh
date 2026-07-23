#!/usr/bin/env bash
# Serves the Flutter web app from inside Docker and exposes it on the host.
# Open http://localhost:8080 in your browser (or in your iPhone's Safari using
# your PC's LAN IP, e.g. http://192.168.x.x:8080, then "Add to Home Screen").
set -euo pipefail

IMAGE="ghcr.io/cirruslabs/flutter:stable"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Building & serving Aetherbook (web) at http://localhost:8080 ..."

MSYS_NO_PATHCONV=1 docker run --rm -it \
    -p 8080:8080 \
    -v "${REPO}:/app" \
    -v aetherbook_pubcache:/root/.pub-cache \
    -w /app \
    "${IMAGE}" \
    flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
