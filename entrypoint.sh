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
# If TELEGRAM_ALLOW_FROM is set, add it to auto-approve that user
if [ -n "$TELEGRAM_ALLOW_FROM" ]; then
  printf '{
    "gateway": {
      "mode": "local",
      "port": 18789,
      "bind": "lan"
    },
    "agents": {
      "defaults": {
        "workspace": "/data/workspace",
        "model": {
          "primary": "moonshotai/kimi-k2.5"
        }
      }
    },
    "channels": {
      "telegram": {
        "enabled": true,
        "botToken": "%s",
        "allowFrom": ["%s"]
      }
    }
  }\n' "$TELEGRAM_BOT_TOKEN" "$TELEGRAM_ALLOW_FROM" > /data/.openclaw/openclaw.json
else
  printf '{
    "gateway": {
      "mode": "local",
      "port": 18789,
      "bind": "lan"
    },
    "agents": {
      "defaults": {
        "workspace": "/data/workspace",
        "model": {
          "primary": "moonshotai/kimi-k2.5"
        }
      }
    },
    "channels": {
      "telegram": {
        "enabled": true,
        "botToken": "%s"
      }
    }
  }\n' "$TELEGRAM_BOT_TOKEN" > /data/.openclaw/openclaw.json
fi

echo "Running OpenClaw doctor to fix config..."
/usr/local/bin/openclaw doctor --fix --yes 2>/dev/null || true

echo "Starting OpenClaw gateway..."

# For containers, run the gateway in foreground mode
# Using 'gateway' (not 'gateway start') with explicit foreground options
export OPENCLAW_GATEWAY_TOKEN=${OPENCLAW_GATEWAY_TOKEN:-$(openssl rand -hex 32)}
exec /usr/local/bin/openclaw gateway --port 18789 --bind lan --verbose 2>&1
