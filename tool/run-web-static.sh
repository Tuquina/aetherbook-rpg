#!/usr/bin/env bash
# Builds a release web bundle and serves it statically from inside Docker —
# no debug/hot-reload service involved. Prefer this over run-web.sh when
# testing from another device (e.g. your phone): `flutter run -d web-server`
# starts Flutter's debug service (DWDS/VM Service), which only accepts
# connections from localhost — a phone on the LAN gets stuck on a blank
# screen because the debug-mode app waits on that connection to finish
# booting. A release build has no such dependency.
#
# Open http://localhost:8080, or from your phone http://<tu-IP-LAN>:8080
# (buscá la IP con `ip addr` / `ifconfig`).
#
# No hot-reload here: repetí este comando después de cada cambio de código.
set -euo pipefail

IMAGE="ghcr.io/cirruslabs/flutter:stable"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Compilando y sirviendo Aetherbook (web, release) en http://localhost:8080 ..."

MSYS_NO_PATHCONV=1 docker run --rm -it \
    -p 8080:8080 \
    -v "${REPO}:/app" \
    -v aetherbook_pubcache:/root/.pub-cache \
    -w /app \
    "${IMAGE}" \
    sh -c "flutter build web && dart run tool/static_server.dart 8080"
