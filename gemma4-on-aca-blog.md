# Run Gemma 4 on Azure Container Apps — One Command, Real GPU

Deploy Google's Gemma 4 on Azure Container Apps serverless GPU with a single `azd up`. Then wire it up as a backend for [OpenCode](https://opencode.ai) or any OpenAI-compatible tool.

## Your Own LLM Backend in Minutes

Standing up a self-hosted LLM usually means wrestling with VMs, CUDA drivers, networking, and model weight management. Azure Container Apps serverless GPU changes that equation entirely — you get a T4 or A100 GPU on demand, no infrastructure to manage, and you only pay while the container runs.

We built an `azd` template that takes this from zero to a working Gemma 4 endpoint in a single command. No VMs, no Kubernetes manifests, no driver installs.

```bash
git clone https://github.com/simonjj/gemma4-on-aca.git
cd gemma4-on-aca
azd up
```

The interactive setup asks three questions — GPU tier, model size, and a proxy password — then provisions everything: a Container Apps environment with a GPU workload profile, an Ollama instance that pulls and serves Gemma 4, and an nginx auth proxy that protects the endpoint with basic authentication.

## Why Gemma 4?

Google's Gemma 4 family hits a sweet spot for self-hosted inference. The models range from a tiny 2B parameter variant to a 31B dense model, all running efficiently on Ollama with quantized weights. The standout is the **26B Mixture-of-Experts** model — it activates only 4B parameters per token, delivering quality that punches well above its compute cost.

Every Gemma 4 model supports an OpenAI-compatible API out of the box through Ollama, so your existing tools and SDKs work without changes.

## Pick Your GPU, Pick Your Model

The template lets you choose between two GPU tiers during setup:

| GPU | VRAM | Default Model | Throughput | Best For |
|-----|------|---------------|-----------|----------|
| **T4** | 16 GB | `gemma4:e4b` | ~51 tok/s | Cost-effective dev/test, lighter workloads |
| **A100** | 80 GB | `gemma4:26b` | ~113 tok/s | Production quality, complex reasoning |

Here are the full benchmarks across all model sizes (tested on ACA serverless GPU in Sweden Central):

| Model | Params | T4 (16 GB) | A100 (80 GB) |
|-------|--------|-----------|-------------|
| `gemma4:e2b` | 2B | ~81 tok/s | ~184 tok/s |
| `gemma4:e4b` | 4B | ~51 tok/s | ~129 tok/s |
| `gemma4:26b` | 26B MoE | — | ~113 tok/s |
| `gemma4:31b` | 31B Dense | — | ~40 tok/s |

The 26B MoE model on A100 delivers **113 tokens per second** — faster than the 4B model on T4, with significantly better reasoning quality. That's the power of pairing a well-architected model with the right GPU tier.

## Verify It Works

After `azd up` completes (typically 8–12 minutes including the model download), test your endpoint:

```bash
# Get your endpoint URL
azd env get-values | grep OLLAMA_ENDPOINT

# Send a request
curl -u admin:<your-password> \
  https://<your-endpoint>/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemma4:e4b",
    "messages": [{"role": "user", "content": "Write a Python binary search function"}]
  }'
```

The endpoint speaks the OpenAI chat completions API, so any tool built for OpenAI works here — just point it at your proxy URL.

## Connect OpenCode

[OpenCode](https://opencode.ai) is a terminal-based AI coding agent that supports 75+ LLM providers. Point it at your deployed endpoint and you have a full coding assistant running on your own GPU infrastructure.

Create `opencode.json` in your project root:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "gemma4-aca": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Gemma 4 on ACA",
      "options": {
        "baseURL": "https://<your-endpoint>/v1",
        "headers": {
          "Authorization": "Basic <base64-of-admin:your-password>"
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

Then run `opencode`, select your model with `/models`, and start coding. All inference runs on your ACA GPU — no tokens leaving your Azure subscription.

The endpoint is also fully OpenAI-compatible, so any tool that supports OpenAI's API works — just point it at your proxy URL.

## What's Under the Hood

The template creates a minimal set of Azure resources:

- **Container Apps Environment** with a GPU workload profile (T4 or A100)
- **Ollama container** — built from `ollama/ollama:latest` with a startup script that pulls the selected model and begins serving
- **Nginx auth proxy** — a lightweight reverse proxy that adds HTTP basic authentication in front of the Ollama API
- **Container Registry** — stores both container images
- **Managed Identity** — for secure, passwordless ACR access

There's no VNet, no persistent storage, and no complex networking. The model is pulled fresh on each cold start (~1–2 minutes for smaller models, ~5 minutes for the larger ones). This keeps the template simple and the deployment fast.

> Serverless GPU is available in these regions: `australiaeast`, `brazilsouth`, `canadacentral`, `eastus`, `italynorth`, `swedencentral`, `uksouth`, `westus`, `westus3`.

## Tear It Down

When you're done:

```bash
azd down
```

Everything is cleaned up. Since there's no persistent storage, there's nothing left behind.

## Get Started

👉 **[Clone the template and deploy](https://github.com/simonjj/gemma4-on-aca)** — you'll have a working Gemma 4 endpoint in under 15 minutes.

The full source, Bicep infrastructure, and documentation are in the repo. PRs and issues welcome.

> Running your own LLM backend doesn't have to be a weekend project. With ACA serverless GPU, it's a single command.
