#!/bin/bash
# Post-provision hook: generates opencode.json for connecting OpenCode to the deployed Gemma 4 endpoint.

ENDPOINT=$(azd env get-value OLLAMA_PROXY_ENDPOINT 2>/dev/null)
MODEL=$(azd env get-value OLLAMA_MODEL 2>/dev/null)
PASSWORD=$(azd env get-value PROXY_AUTH_PASSWORD 2>/dev/null)

if [ -z "$ENDPOINT" ] || [ -z "$MODEL" ]; then
    echo "⚠ Could not read deployment outputs. Skipping opencode.json generation."
    exit 0
fi

# Prompt for password if not in env
if [ -z "$PASSWORD" ]; then
    printf "Enter your proxy auth password (for opencode.json): "
    read -r PASSWORD
fi

if [ -z "$PASSWORD" ]; then
    echo "⚠ No password provided. Skipping opencode.json generation."
    exit 0
fi

AUTH_BASIC=$(printf "admin:%s" "$PASSWORD" | base64)

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
          "name": "Gemma 4 ${MODEL##*:}"
        }
      }
    }
  }
}
EOF

echo "✅ Generated opencode.json → gemma4-aca/${MODEL}"
echo ""
echo "Usage:"
echo "  opencode run -m \"gemma4-aca/${MODEL}\" \"your prompt here\""
echo "  opencode   # then /models → pick Gemma 4"
