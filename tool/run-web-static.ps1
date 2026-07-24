# Builds a release web bundle and serves it statically from inside Docker —
# no debug/hot-reload service involved. Prefer this over run-web.ps1 when
# testing from another device (e.g. your phone): `flutter run -d web-server`
# starts Flutter's debug service (DWDS/VM Service), which only accepts
# connections from localhost — a phone on the LAN gets stuck on a blank
# screen because the debug-mode app waits on that connection to finish
# booting. A release build has no such dependency.
#
# Open http://localhost:8080, or from your phone http://<tu-IP-LAN>:8080
# (buscá la IP con `ipconfig` -> IPv4).
#
# No hot-reload here: repetí este comando después de cada cambio de código.

$image = "ghcr.io/cirruslabs/flutter:stable"
$repo  = (Resolve-Path "$PSScriptRoot\..").Path

Write-Host "Compilando y sirviendo Aetherbook (web, release) en http://localhost:8080 ..." -ForegroundColor Cyan

docker run --rm -it `
    -p 8080:8080 `
    -v "${repo}:/app" `
    -v aetherbook_pubcache:/root/.pub-cache `
    -w /app `
    $image `
    sh -c "flutter build web && dart run tool/static_server.dart 8080"
