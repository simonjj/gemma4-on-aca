# Build and push gemma4-on-aca container images to a registry.
# Usage:
#   .\scripts\build-and-push.ps1 -Registry <registry>
#
# Examples:
#   .\scripts\build-and-push.ps1 -Registry myregistry.azurecr.io/gemma4-on-aca
#   .\scripts\build-and-push.ps1 -Registry ghcr.io/myuser/gemma4-on-aca

param(
    [Parameter(Mandatory=$true, HelpMessage="Registry prefix, e.g. myregistry.azurecr.io/gemma4-on-aca")]
    [string]$Registry
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

Write-Host "Building and pushing images to: $Registry"
Write-Host ""

# Detect if this is an Azure Container Registry
if ($Registry -match '\.azurecr\.io') {
    $AcrName = ($Registry -split '\.')[0]
    Write-Host "Detected Azure Container Registry: $AcrName"
    Write-Host ""

    $ImagePrefix = ($Registry -replace "^[^/]+/", "")

    Write-Host "[1/2] Building ollama image..."
    az acr build --registry $AcrName `
        --image "$ImagePrefix/ollama:latest" `
        --file "$RepoRoot\app\ollama\Dockerfile" `
        "$RepoRoot\app\ollama\"

    Write-Host ""
    Write-Host "[2/2] Building nginx-auth-proxy image..."
    az acr build --registry $AcrName `
        --image "$ImagePrefix/nginx-auth-proxy:latest" `
        --file "$RepoRoot\app\nginx-auth-proxy\Dockerfile" `
        "$RepoRoot\app\nginx-auth-proxy\"
} else {
    Write-Host "[1/2] Building ollama image..."
    docker build -t "$Registry/ollama:latest" -f "$RepoRoot\app\ollama\Dockerfile" "$RepoRoot\app\ollama\"
    docker push "$Registry/ollama:latest"

    Write-Host ""
    Write-Host "[2/2] Building nginx-auth-proxy image..."
    docker build -t "$Registry/nginx-auth-proxy:latest" -f "$RepoRoot\app\nginx-auth-proxy\Dockerfile" "$RepoRoot\app\nginx-auth-proxy\"
    docker push "$Registry/nginx-auth-proxy:latest"
}

Write-Host ""
Write-Host "Done! Images pushed to:"
Write-Host "  $Registry/ollama:latest"
Write-Host "  $Registry/nginx-auth-proxy:latest"
Write-Host ""
Write-Host "To use these images, deploy with:"
Write-Host "  azd env set IMAGE_REGISTRY `"$Registry`""
Write-Host "  azd up"
