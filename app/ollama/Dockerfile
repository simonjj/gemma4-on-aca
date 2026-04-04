FROM ollama/ollama:latest

RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*

COPY start-ollama.sh /start-ollama.sh
RUN chmod +x /start-ollama.sh

EXPOSE 11434

ENTRYPOINT ["/start-ollama.sh"]
CMD ["start"]
