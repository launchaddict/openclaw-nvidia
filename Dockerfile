FROM node:20-slim

RUN apt-get update && apt-get install -y git chromium && rm -rf /var/lib/apt/lists/*

ENV OPENCLAW_STATE_DIR=/data/.openclaw
ENV OPENCLAW_WORKSPACE_DIR=/data/workspace
ENV PATH="/usr/local/bin:${PATH}"

RUN npm install -g openclaw && \
    mkdir -p /data/.openclaw/agents/main/agent /data/workspace && \
    which openclaw

EXPOSE 18789

CMD ["sh","-c","echo '{\"version\":1,\"profiles\":{\"moonshot:default\":{\"type\":\"api_key\",\"provider\":\"moonshot\",\"key\":\"'\"$NVIDIA_API_KEY\"'\"}},\"lastGood\":{\"moonshot\":\"moonshot:default\"}}' > /data/.openclaw/agents/main/agent/auth-profiles.json && echo '{\"gateway\":{\"mode\":\"local\",\"port\":18789},\"agents\":{\"defaults\":{\"provider\":\"moonshot\",\"model\":{\"primary\":\"moonshotai/kimi-k2.5\"}},\"channels\":{\"telegram\":{\"enabled\":true,\"botToken\":\"'\"$TELEGRAM_BOT_TOKEN\"'\"}}}' > /data/.openclaw/openclaw.json && /usr/local/bin/openclaw gateway start --port 18789 --bind 0.0.0.0"]
