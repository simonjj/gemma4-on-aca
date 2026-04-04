# Post-provision hook: generates opencode.json and displays deployment info.

$endpoint = azd env get-value OLLAMA_PROXY_ENDPOINT 2>$null
$model = azd env get-value OLLAMA_MODEL 2>$null
$password = azd env get-value PROXY_AUTH_PASSWORD 2>$null

if (-not $endpoint -or -not $model) {
    Write-Host "⚠ Could not read deployment outputs. Skipping opencode.json generation."
    exit 0
}

# ─── Display Deployment Info ───
Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════"
Write-Host "  Deployment complete!"
Write-Host "════════════════════════════════════════════════════════════════"
Write-Host ""
Write-Host "  Proxy endpoint: https://$endpoint"
Write-Host "  Model:          $model"
Write-Host ""
Write-Host "  Test with curl:"
Write-Host "    curl -u admin:<password> https://$endpoint/v1/models"
Write-Host ""

# ─── Generate opencode.json ───
if (-not $password) {
    Write-Host "  To generate opencode.json, re-enter your proxy password."
    Write-Host "  (This is the same password you entered earlier during provisioning.)"
    Write-Host ""
    $password = Read-Host "  Proxy password"
}

if (-not $password) {
    Write-Host ""
    Write-Host "  ⚠ No password provided. Skipping opencode.json generation."
    Write-Host "  You can configure OpenCode manually — see README.md."
    exit 0
}

# Store password for future runs
azd env set PROXY_AUTH_PASSWORD $password 2>$null | Out-Null

$authBasic = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("admin:$password"))
$modelShort = ($model -split ':')[-1]

$config = @"
{
  "`$schema": "https://opencode.ai/config.json",
  "provider": {
    "gemma4-aca": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Gemma 4 on ACA",
      "options": {
        "baseURL": "https://$endpoint/v1",
        "headers": {
          "Authorization": "Basic $authBasic"
        }
      },
      "models": {
        "$model": {
          "name": "Gemma 4 $modelShort"
        }
      }
    }
  }
}
"@

$config | Set-Content -Path "opencode.json" -Encoding UTF8

Write-Host ""
Write-Host "  ✅ Generated opencode.json"
Write-Host ""
Write-Host "  Usage:"
Write-Host "    opencode run -m `"gemma4-aca/$model`" `"your prompt here`""
Write-Host "    opencode   # then /models → pick Gemma 4"
Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════"
