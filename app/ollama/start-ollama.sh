#!/bin/bash
set -e

DEFAULT_MODEL="${OLLAMA_MODEL:-gemma4:e4b}"
PULL_RETRY_INTERVAL="${PULL_RETRY_INTERVAL:-30}"
PULL_MAX_ATTEMPTS="${PULL_MAX_ATTEMPTS:-20}"

start_with_model() {
    local model="${1:-$DEFAULT_MODEL}"
    echo "=== Starting Ollama server ==="
    ollama serve &

    echo "Waiting for Ollama server..."
    local ready=0
    for i in $(seq 1 30); do
        if curl -sf http://localhost:11434/api/tags >/dev/null 2>&1; then
            ready=1
            break
        fi
        sleep 2
    done

    if [ "$ready" -ne 1 ]; then
        echo "ERROR: Ollama server did not start within 60s"
        exit 1
    fi

    echo "Pulling model: $model (retrying every ${PULL_RETRY_INTERVAL}s, max ${PULL_MAX_ATTEMPTS} attempts)"
    local attempt=1
    while [ $attempt -le $PULL_MAX_ATTEMPTS ]; do
        echo "Attempt $attempt/$PULL_MAX_ATTEMPTS: ollama pull $model"
        if ollama pull "$model"; then
            echo "Successfully pulled: $model"
            break
        fi

        echo "Pull attempt $attempt failed, retrying in ${PULL_RETRY_INTERVAL}s..."
        pkill -f "ollama pull" 2>/dev/null || true
        sleep "$PULL_RETRY_INTERVAL"
        attempt=$((attempt + 1))
    done

    if [ $attempt -gt $PULL_MAX_ATTEMPTS ]; then
        echo "ERROR: Failed to pull $model after $PULL_MAX_ATTEMPTS attempts"
        exit 1
    fi

    echo "=== Ollama ready with $model ==="
    wait
}

pull_and_quit() {
    local model="${1:-$DEFAULT_MODEL}"
    echo "=== Init container: pulling $model ==="
    ollama serve &
    local server_pid=$!

    echo "Waiting for Ollama server..."
    for i in $(seq 1 30); do
        if curl -sf http://localhost:11434/api/tags >/dev/null 2>&1; then
            break
        fi
        sleep 2
    done

    local attempt=1
    while [ $attempt -le $PULL_MAX_ATTEMPTS ]; do
        echo "Attempt $attempt/$PULL_MAX_ATTEMPTS: ollama pull $model"
        if timeout 120 ollama pull "$model"; then
            echo "Successfully pulled: $model"
            break
        fi

        echo "Pull attempt $attempt failed, re-kicking in ${PULL_RETRY_INTERVAL}s..."
        pkill -f "ollama pull" 2>/dev/null || true
        sleep "$PULL_RETRY_INTERVAL"
        attempt=$((attempt + 1))
    done

    if [ $attempt -gt $PULL_MAX_ATTEMPTS ]; then
        echo "ERROR: Failed to pull $model after $PULL_MAX_ATTEMPTS attempts"
    fi

    echo "Shutting down Ollama server..."
    kill $server_pid 2>/dev/null
    wait $server_pid 2>/dev/null || true
    echo "Init container complete."
}

case "${1:-}" in
    "serve")
        exec /bin/ollama serve
        ;;
    "start")
        start_with_model "${2:-$DEFAULT_MODEL}"
        ;;
    "pull")
        pull_and_quit "${2:-$DEFAULT_MODEL}"
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [COMMAND] [MODEL]"
        echo ""
        echo "Commands:"
        echo "  serve              Start Ollama server only"
        echo "  start [MODEL]      Pull model and serve (default: $DEFAULT_MODEL)"
        echo "  pull [MODEL]       Pull model and exit (init container mode)"
        echo "  help               Show this help"
        ;;
    "")
        start_with_model "$DEFAULT_MODEL"
        ;;
    *)
        exec /bin/ollama "$@"
        ;;
esac
