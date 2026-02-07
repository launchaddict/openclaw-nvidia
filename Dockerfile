FROM node:22-slim

RUN apt-get update && apt-get install -y git chromium && rm -rf /var/lib/apt/lists/*

ENV OPENCLAW_STATE_DIR=/data/.openclaw
ENV OPENCLAW_WORKSPACE_DIR=/data/workspace
ENV PATH="/usr/local/bin:${PATH}"

# Placeholder values - must be overridden in Railway
ENV NVIDIA_API_KEY=placeholder_nvidia_key
ENV TELEGRAM_BOT_TOKEN=placeholder_telegram_token

RUN npm install -g openclaw@latest && \
    mkdir -p /data/.openclaw/agents/main/agent /data/workspace && \
    which openclaw

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 18789

CMD ["/entrypoint.sh"]
