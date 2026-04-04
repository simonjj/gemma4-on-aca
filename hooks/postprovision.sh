#!/bin/bash
# Post-provision hook: generates opencode.json and displays deployment info.

ENDPOINT=$(azd env get-value OLLAMA_PROXY_ENDPOINT 2>/dev/null)
MODEL=$(azd env get-value OLLAMA_MODEL 2>/dev/null)
PASSWORD=$(azd env get-value PROXY_AUTH_PASSWORD 2>/dev/null)

if [ -z "$ENDPOINT" ] || [ -z "$MODEL" ]; then
    echo "⚠ Could not read deployment outputs. Skipping opencode.json generation."
    exit 0
fi

# ─── Display Deployment Info ───
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  Deployment complete!"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "  Proxy endpoint: https://$ENDPOINT"
echo "  Model:          $MODEL"
echo ""
echo "  Test with curl:"
echo "    curl -u admin:<password> https://$ENDPOINT/v1/models"
echo ""

# ─── Generate opencode.json ───
if [ -z "$PASSWORD" ]; then
    echo "  To generate opencode.json, re-enter your proxy password."
    echo "  (This is the same password you entered earlier during provisioning.)"
    echo ""
    printf "  Proxy password: "
    read -r PASSWORD
fi

if [ -z "$PASSWORD" ]; then
    echo ""
    echo "  ⚠ No password provided. Skipping opencode.json generation."
    echo "  You can configure OpenCode manually — see README.md."
    exit 0
fi

# Store password for future runs
azd env set PROXY_AUTH_PASSWORD "$PASSWORD" 2>/dev/null || true

AUTH_BASIC=$(printf "admin:%s" "$PASSWORD" | base64)
MODEL_SHORT="${MODEL##*:}"

cat > opencode.json <<EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "provider": {
    "gemma4-aca": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Gemma 4 on ACA",
      "options": {
        "baseURL": "https://${ENDPOINT}/v1",
        "headers": {
          "Authorization": "Basic ${AUTH_BASIC}"
        }
      },
      "models": {
        "${MODEL}": {
          "name": "Gemma 4 ${MODEL_SHORT}"
        }
      }
    }
  }
}
EOF

echo ""
echo "  ✅ Generated opencode.json"
echo ""
echo "  Usage:"
echo "    opencode run -m \"gemma4-aca/${MODEL}\" \"your prompt here\""
echo "    opencode   # then /models → pick Gemma 4"
echo ""
echo "════════════════════════════════════════════════════════════════"
