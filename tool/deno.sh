#!/usr/bin/env bash
# Runs any Deno command inside the pinned Docker image. See tool/deno.ps1.
set -euo pipefail

IMAGE="denoland/deno:latest"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

MSYS_NO_PATHCONV=1 docker run --rm \
    -v "${REPO}:/app" \
    -w /app \
    "${IMAGE}" \
    deno "$@"
