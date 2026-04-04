# Gemma 4 on Azure Container Apps

Deploy Google's [Gemma 4](https://ai.google.dev/gemma/docs/core) on Azure Container Apps with serverless GPU — in minutes.

## What You Get

- **Ollama + Gemma 4** running on ACA serverless GPU (T4 or A100)
- **Nginx auth proxy** protecting the API endpoint
- **OpenAI-compatible API** ready for [OpenCode](https://opencode.ai), `curl`, or any app
- **One command deploy** via `azd up`

## Prerequisites

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) installed and authenticated
- [Azure Developer CLI (azd)](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/) installed
- An Azure subscription with the `Microsoft.App` provider enabled

## Quick Start

```bash
git clone https://github.com/simonjj/gemma4-on-aca.git
cd gemma4-on-aca
azd up
```

During setup you'll be prompted to:
1. **Choose a GPU** — T4 (16 GB) or A100 (80 GB)
2. **Pick a Gemma 4 model** — options depend on your GPU choice
3. **Set a proxy password** — protects your Ollama API endpoint

> **GPU region availability:** Serverless GPUs are available in select regions. When prompted for a location, choose from: `australiaeast`, `brazilsouth`, `canadacentral`, `eastus`, `italynorth`, `swedencentral`, `uksouth`, `westus`, `westus3`. [Full list →](https://learn.microsoft.com/en-us/azure/container-apps/workload-profiles-overview#gpu-workload-profiles)

## GPU + Model Options

| GPU | VRAM | Recommended Models | Best For |
|-----|------|--------------------|----------|
| **T4** | 16 GB | `gemma4:e4b` (default), `gemma4:e2b` | Cost-effective, lighter workloads |
| **A100** | 80 GB | `gemma4:26b` (default), `gemma4:31b`, `gemma4:e4b`, `gemma4:e2b` | Maximum quality, heavy workloads |

### Model Details

| Model | Params | Architecture | Context | Modalities | Disk Size |
|-------|--------|-------------|---------|------------|-----------|
| `gemma4:e2b` | ~2B | Dense | 128K | Text, Image, Audio | ~7 GB |
| `gemma4:e4b` | ~4B | Dense | 128K | Text, Image, Audio | ~10 GB |
| `gemma4:26b` | 26B | MoE (4B active) | 256K | Text, Image | ~18 GB |
| `gemma4:31b` | 31B | Dense | 256K | Text, Image | ~20 GB |

### Performance

Benchmarked on ACA serverless GPU in Sweden Central (Ollama v0.20, Q4_K_M quantization, 32K context):

| Model | GPU | Tokens/sec | TTFT | Notes |
|-------|-----|-----------|------|-------|
| `gemma4:e2b` | T4 | ~81 | ~15ms | Fastest on T4 |
| `gemma4:e4b` | T4 | ~51 | ~17ms | **Default T4 choice** |
| `gemma4:e2b` | A100 | ~184 | ~9ms | Ultra-fast |
| `gemma4:e4b` | A100 | ~129 | ~12ms | Good for lighter workloads |
| `gemma4:26b` | A100 | ~113 | ~14ms | **Default A100 choice** — best quality/speed |
| `gemma4:31b` | A100 | ~40 | ~30ms | Highest quality, slower |

> 26b and 31b require A100 — they don't fit in T4's 16 GB VRAM.

## Verify Your Deployment

After `azd up` completes, get your endpoint and test it:

```bash
# Get deployment outputs
azd env get-values

# Test with curl (replace with your values)
curl -u admin:<YOUR_PASSWORD> \
  https://<YOUR_PROXY_ENDPOINT>/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemma4:e4b",
    "messages": [{"role": "user", "content": "Hello, what can you do?"}]
  }'
```

## Connect OpenCode

[OpenCode](https://opencode.ai) is a terminal-based AI coding agent that supports 75+ LLM providers. Point it at your deployed Gemma 4 endpoint to use it as a coding assistant — all inference runs on your own GPU.

### Configure

Create or edit `opencode.json` in your project root:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "gemma4-aca": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Gemma 4 on ACA",
      "options": {
        "baseURL": "https://<YOUR_PROXY_ENDPOINT>/v1",
        "headers": {
          "Authorization": "Basic <BASE64_OF_admin:YOUR_PASSWORD>"
        }
      },
      "models": {
        "gemma4:e4b": {
          "name": "Gemma 4 e4b (4B)"
        }
      }
    }
  }
}
```

> Generate the Base64 value with: `echo -n "admin:<YOUR_PASSWORD>" | base64`

### Use It

```bash
# Start OpenCode TUI
opencode

# Select your model
/models
# → Pick "Gemma 4 e4b (4B)"

# Start coding
> Write a REST API for user management in Go
```

Or run non-interactively:

```bash
opencode run -m "gemma4-aca/gemma4:e4b" "Write a binary search in Rust"
```

### Direct API (No Agent)

The endpoint is fully OpenAI-compatible, so any tool that supports OpenAI's API works:

```bash
curl -u admin:<YOUR_PASSWORD> \
  https://<YOUR_PROXY_ENDPOINT>/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemma4:e4b",
    "messages": [
      {"role": "system", "content": "You are a helpful coding assistant."},
      {"role": "user", "content": "Write a binary search in Rust"}
    ],
    "temperature": 0.7
  }'
```

## Pre-built Container Images

This template uses pre-built images hosted on a public Azure Container Registry. No local Docker builds are needed.

| Image | URL | Digest |
|-------|-----|--------|
| Ollama | `simon.azurecr.io/gemma4-on-aca/ollama:latest` | `sha256:887a9231e17e...` |
| Nginx Auth Proxy | `simon.azurecr.io/gemma4-on-aca/nginx-auth-proxy:latest` | `sha256:4249385fd282...` |

Both images support anonymous pull. To use your own registry, see [`scripts/README.md`](scripts/README.md).

## Architecture

```
[Your App / OpenCode / curl]
        │
        ▼
┌─────────────────────────┐
│  Nginx Auth Proxy       │  ← external HTTPS, basic auth
│  (Consumption profile)  │
└─────────┬───────────────┘
          │ internal
          ▼
┌─────────────────────────┐
│  Ollama + Gemma 4       │  ← GPU workload profile
│  (T4 or A100)           │
│                         │
│  start-ollama.sh:       │
│    1. ollama serve      │
│    2. ollama pull model │
│    3. serve forever     │
└─────────────────────────┘
```

**Resources created:**
- ACA Environment (with GPU workload profile)
- 2 Container Apps (using pre-built images from a public registry)

No VNet, no storage accounts, no container registry — kept intentionally simple. The model is pulled fresh on each cold start (~1-2 min for smaller models, ~5 min for 26b/31b).

## Configuration

### Change Model After Deployment

```bash
# Update the model environment variable
az containerapp update \
  --name <ollama-app-name> \
  --resource-group <resource-group> \
  --set-env-vars OLLAMA_MODEL="gemma4:26b"

# Restart to pull the new model
az containerapp revision restart \
  --name <ollama-app-name> \
  --resource-group <resource-group>
```

### Tear Down

```bash
azd down
```

## Project Structure

```
gemma4-on-aca/
├── azure.yaml              # azd configuration
├── README.md
├── LICENSE
├── app/
│   ├── ollama/             # Ollama image source
│   │   ├── Dockerfile      # ollama/ollama:latest + curl + start script
│   │   └── start-ollama.sh # Pull model on startup, then serve
│   └── nginx-auth-proxy/   # Auth proxy image source
│       ├── Dockerfile
│       ├── entrypoint.sh
│       └── default.conf.template
├── hooks/
│   ├── select-gpu-model.sh   # Linux/macOS setup
│   └── select-gpu-model.ps1  # Windows setup
├── scripts/
│   ├── build-and-push.sh     # Rebuild images to your own registry
│   └── build-and-push.ps1
└── infra/
    ├── main.bicep
    ├── main.parameters.json
    └── resources.bicep
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Deployment takes a long time | The model is downloaded on first start. Gemma4 models range from 7-20 GB. Check the Ollama container logs in the Azure Portal. |
| `curl` returns 502/503 | The model may still be loading. Wait a few minutes and retry. Check Ollama logs via: `az containerapp logs show --name <ollama-app-name> -g <rg>` |
| Out of memory errors | Your chosen model is too large for the selected GPU. Redeploy with a smaller model or upgrade to A100. |
| Authentication errors | Verify your proxy password. Check with: `curl -u admin:<password> https://<endpoint>/api/tags` |

## Contributing

Changes and improvements are welcome via pull requests. For issues or questions, [raise an issue](https://github.com/simonjj/gemma4-on-aca/issues).

## License

Apache 2.0 — see [LICENSE](LICENSE).
