# Runs any Deno command inside the pinned Docker image, so the Deno runtime
# never has to be installed on the host. Used for the Supabase Edge Functions
# under supabase/functions/, which run on Deno in production.
#
# Usage:
#   .\tool\deno.ps1 test supabase/functions/narrator
#   .\tool\deno.ps1 check supabase/functions/narrator/index.ts

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

$image = "denoland/deno:latest"
$repo  = (Resolve-Path "$PSScriptRoot\..").Path

docker run --rm `
    -v "${repo}:/app" `
    -w /app `
    $image `
    deno @Args
