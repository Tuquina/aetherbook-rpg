# Runs any Flutter/Dart command inside the pinned Docker image, so the SDK
# never has to be installed on the host. Project files live on the host via
# a bind mount; the pub cache lives in a named Docker volume.
#
# Usage:
#   .\tool\flutter.ps1 test
#   .\tool\flutter.ps1 analyze
#   .\tool\flutter.ps1 run -d web-server --web-hostname 0.0.0.0 --web-port 8080
#
# To play the game in the browser, prefer:  .\tool\run-web.ps1

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

$image = "ghcr.io/cirruslabs/flutter:stable"
$repo  = (Resolve-Path "$PSScriptRoot\..").Path

docker run --rm `
    -v "${repo}:/app" `
    -v aetherbook_pubcache:/root/.pub-cache `
    -w /app `
    $image `
    flutter @Args
