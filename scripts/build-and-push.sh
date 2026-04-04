#!/usr/bin/env bash
set -euo pipefail

# Build and push gemma4-on-aca container images to a registry.
# Usage:
#   ./scripts/build-and-push.sh <registry>
#
# Examples:
#   ./scripts/build-and-push.sh myregistry.azurecr.io/gemma4-on-aca
#   ./scripts/build-and-push.sh ghcr.io/myuser/gemma4-on-aca

REGISTRY="${1:-}"
if [ -z "$REGISTRY" ]; then
  echo "Usage: $0 <registry-prefix>"
  echo ""
  echo "Examples:"
  echo "  $0 myregistry.azurecr.io/gemma4-on-aca"
  echo "  $0 ghcr.io/myuser/gemma4-on-aca"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Building and pushing images to: $REGISTRY"
echo ""

# Detect if this is an Azure Container Registry (use ACR build for speed)
if [[ "$REGISTRY" == *.azurecr.io* ]]; then
  ACR_NAME=$(echo "$REGISTRY" | cut -d'.' -f1)
  echo "Detected Azure Container Registry: $ACR_NAME"
  echo ""

  echo "[1/2] Building ollama image..."
  az acr build --registry "$ACR_NAME" \
    --image "${REGISTRY#*.azurecr.io/}/ollama:latest" \
    --file "$REPO_ROOT/app/ollama/Dockerfile" \
    "$REPO_ROOT/app/ollama/"

  echo ""
  echo "[2/2] Building nginx-auth-proxy image..."
  az acr build --registry "$ACR_NAME" \
    --image "${REGISTRY#*.azurecr.io/}/nginx-auth-proxy:latest" \
    --file "$REPO_ROOT/app/nginx-auth-proxy/Dockerfile" \
    "$REPO_ROOT/app/nginx-auth-proxy/"
else
  echo "[1/2] Building ollama image..."
  docker build -t "$REGISTRY/ollama:latest" -f "$REPO_ROOT/app/ollama/Dockerfile" "$REPO_ROOT/app/ollama/"
  docker push "$REGISTRY/ollama:latest"

  echo ""
  echo "[2/2] Building nginx-auth-proxy image..."
  docker build -t "$REGISTRY/nginx-auth-proxy:latest" -f "$REPO_ROOT/app/nginx-auth-proxy/Dockerfile" "$REPO_ROOT/app/nginx-auth-proxy/"
  docker push "$REGISTRY/nginx-auth-proxy:latest"
fi

echo ""
echo "Done! Images pushed to:"
echo "  $REGISTRY/ollama:latest"
echo "  $REGISTRY/nginx-auth-proxy:latest"
echo ""
echo "To use these images, deploy with:"
echo "  azd env set IMAGE_REGISTRY \"$REGISTRY\""
echo "  azd up"
