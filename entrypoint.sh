#!/bin/sh
set -e

# Validate environment variables
if [ "$NVIDIA_API_KEY" = "placeholder_nvidia_key" ] || [ -z "$NVIDIA_API_KEY" ]; then
  echo "⚠️  WARNING: NVIDIA_API_KEY not set!"
  echo "   Get your API key from: https://build.nvidia.com/"
  echo "   Set it in Railway Variables and redeploy."
  echo ""
fi

if [ "$TELEGRAM_BOT_TOKEN" = "placeholder_telegram_token" ] || [ -z "$TELEGRAM_BOT_TOKEN" ]; then
  echo "⚠️  WARNING: TELEGRAM_BOT_TOKEN not set!"
  echo "   Get your bot token from @BotFather on Telegram"
  echo "   Set it in Railway Variables and redeploy."
  echo ""
fi

# Create auth-profiles.json
cat > /data/.openclaw/agents/main/agent/auth-profiles.json << EOF
{
  "version": 1,
  "profiles": {
    "moonshot:default": {
      "type": "api_key",
      "provider": "moonshot",
      "key": "${NVIDIA_API_KEY}"
    }
  },
  "lastGood": {
    "moonshot": "moonshot:default"
  }
}
EOF

# Create openclaw.json - using printf to handle variable expansion safely
printf '{
  "gateway": {
    "mode": "local",
    "port": 18789,
    "bind": "0.0.0.0"
  },
  "agent": {
    "workspace": "/data/workspace",
    "model": {
      "primary": "moonshotai/kimi-k2.5"
    }
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "botToken": "%s"
    }
  }
}\n' "$TELEGRAM_BOT_TOKEN" > /data/.openclaw/openclaw.json

echo "Starting OpenClaw gateway..."

# Start OpenClaw gateway
exec /usr/local/bin/openclaw gateway start --port 18789 --bind 0.0.0.0
