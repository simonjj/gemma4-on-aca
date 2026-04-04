# Post-provision hook: generates opencode.json for connecting OpenCode to the deployed Gemma 4 endpoint.

$endpoint = azd env get-value OLLAMA_PROXY_ENDPOINT 2>$null
$model = azd env get-value OLLAMA_MODEL 2>$null
$password = azd env get-value PROXY_AUTH_PASSWORD 2>$null

if (-not $endpoint -or -not $model) {
    Write-Host "⚠ Could not read deployment outputs. Skipping opencode.json generation."
    exit 0
}

# Prompt for password if not in env
if (-not $password) {
    $password = Read-Host "Enter your proxy auth password (for opencode.json)"
}

if (-not $password) {
    Write-Host "⚠ No password provided. Skipping opencode.json generation."
    exit 0
}

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

Write-Host "✅ Generated opencode.json → gemma4-aca/$model"
Write-Host ""
Write-Host "Usage:"
Write-Host "  opencode run -m `"gemma4-aca/$model`" `"your prompt here`""
Write-Host "  opencode   # then /models → pick Gemma 4"
