# Serves the Flutter web app from inside Docker and exposes it on the host.
# Open http://localhost:8080 in your browser (or in your iPhone's Safari using
# your PC's LAN IP, e.g. http://192.168.x.x:8080, then "Add to Home Screen").

$image = "ghcr.io/cirruslabs/flutter:stable"
$repo  = (Resolve-Path "$PSScriptRoot\..").Path

Write-Host "Building & serving Aetherbook (web) at http://localhost:8080 ..." -ForegroundColor Cyan

docker run --rm -it `
    -p 8080:8080 `
    -v "${repo}:/app" `
    -v aetherbook_pubcache:/root/.pub-cache `
    -w /app `
    $image `
    flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
