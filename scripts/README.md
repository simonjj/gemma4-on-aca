# Build & Push Scripts

Scripts for building and pushing custom container images to your own registry.

## When to Use

The default template pulls pre-built images from `simon.azurecr.io/gemma4-on-aca`. Use these scripts if you want to:

- Host images in your own registry
- Modify the Ollama or nginx proxy Dockerfiles
- Pin to a specific Ollama version
- Add custom configuration to the images

## Usage

### Bash (Linux/macOS)

```bash
# Push to an Azure Container Registry
./scripts/build-and-push.sh myregistry.azurecr.io/gemma4-on-aca

# Push to Docker Hub
./scripts/build-and-push.sh docker.io/myuser/gemma4-on-aca
```

### PowerShell (Windows)

```powershell
# Push to an Azure Container Registry
.\scripts\build-and-push.ps1 myregistry.azurecr.io/gemma4-on-aca

# Push to Docker Hub
.\scripts\build-and-push.ps1 docker.io/myuser/gemma4-on-aca
```

### Then Deploy with Your Registry

```bash
azd up
# When prompted, or set beforehand:
azd env set IMAGE_REGISTRY myregistry.azurecr.io/gemma4-on-aca
```

Or pass it directly in `infra/main.bicep` via the `imageRegistry` parameter.

## How It Works

- For Azure Container Registries (`.azurecr.io`): uses `az acr build` for cloud-based builds (no local Docker needed)
- For other registries: uses `docker build` + `docker push` locally

## Images Built

| Image | Source | Description |
|-------|--------|-------------|
| `<registry>/ollama:latest` | `app/ollama/` | Ollama server with curl + model pull-on-start script |
| `<registry>/nginx-auth-proxy:latest` | `app/nginx-auth-proxy/` | Nginx reverse proxy with basic auth |
