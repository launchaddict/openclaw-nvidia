FROM node:22-slim

# Install Tailscale
RUN apt-get update && apt-get install -y \
    git \
    chromium \
    ca-certificates \
    curl \
    gnupg \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg | tee /etc/apt/keyrings/tailscale-archive-keyring.gpg >/dev/null \
    && curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list \
    && apt-get update \
    && apt-get install -y tailscale \
    && rm -rf /var/lib/apt/lists/*

ENV OPENCLAW_STATE_DIR=/data/.openclaw
ENV OPENCLAW_WORKSPACE_DIR=/data/workspace
ENV PATH="/usr/local/bin:${PATH}"

ENV ZAI_API_KEY=
ENV TELEGRAM_BOT_TOKEN=

RUN npm install -g openclaw@latest && \
    mkdir -p /data/.openclaw/agents/main/agent /data/workspace && \
    which openclaw

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 18789

CMD ["/entrypoint.sh"]
