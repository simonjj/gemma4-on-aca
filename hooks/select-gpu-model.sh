#!/usr/bin/env bash
set -euo pipefail

# ─── GPU Profile Selection ───
if [ -z "${GPU_PROFILE_TYPE:-}" ]; then
  echo ""
  echo "Select GPU profile:"
  echo "  1) T4  (16 GB VRAM) — good for smaller Gemma4 models (e2b, e4b)"
  echo "  2) A100 (80 GB VRAM) — supports all Gemma4 models including 26b and 31b"
  echo ""
  read -rp "Enter choice [1/2] (default: 1): " gpu_choice
  gpu_choice="${gpu_choice:-1}"

  case "$gpu_choice" in
    2) GPU_PROFILE_TYPE="Consumption-GPU-NC24-A100" ;;
    *) GPU_PROFILE_TYPE="Consumption-GPU-NC8as-T4" ;;
  esac

  azd env set GPU_PROFILE_TYPE "$GPU_PROFILE_TYPE"
  azd env config set infra.parameters.gpuProfileType "$GPU_PROFILE_TYPE" 2>/dev/null || true
fi

# ─── Model Selection (based on GPU) ───
if [ -z "${OLLAMA_MODEL:-}" ]; then
  echo ""
  if [ "$GPU_PROFILE_TYPE" = "Consumption-GPU-NC24-A100" ]; then
    echo "Select Gemma 4 model for A100:"
    echo "  1) gemma4:e4b   — 4B params, fast, multimodal (text+image+audio)"
    echo "  2) gemma4:26b   — 26B MoE, strong reasoning, 256K context"
    echo "  3) gemma4:31b   — 31B dense, highest quality, 256K context"
    echo "  4) gemma4:e2b   — 2B params, ultra-fast, multimodal"
    echo ""
    read -rp "Enter choice [1-4] (default: 2): " model_choice
    model_choice="${model_choice:-2}"

    case "$model_choice" in
      1) OLLAMA_MODEL="gemma4:e4b" ;;
      3) OLLAMA_MODEL="gemma4:31b" ;;
      4) OLLAMA_MODEL="gemma4:e2b" ;;
      *) OLLAMA_MODEL="gemma4:26b" ;;
    esac
  else
    echo "Select Gemma 4 model for T4:"
    echo "  1) gemma4:e4b   — 4B params, good balance of speed and quality"
    echo "  2) gemma4:e2b   — 2B params, fastest, best for simple tasks"
    echo ""
    read -rp "Enter choice [1/2] (default: 1): " model_choice
    model_choice="${model_choice:-1}"

    case "$model_choice" in
      2) OLLAMA_MODEL="gemma4:e2b" ;;
      *) OLLAMA_MODEL="gemma4:e4b" ;;
    esac
  fi

  azd env set OLLAMA_MODEL "$OLLAMA_MODEL"
fi

echo ""
echo "Configuration:"
echo "  GPU Profile : $GPU_PROFILE_TYPE"
echo "  Model       : ${OLLAMA_MODEL}"
echo ""
