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

# Remove old config files to ensure fresh config
rm -f /data/.openclaw/openclaw.json
rm -f /data/.openclaw/agents/main/agent/auth-profiles.json
rm -f /data/.openclaw/agents/main/agent/auth.json

# Create auth-profiles.json for NVIDIA NIM
cat > /data/.openclaw/agents/main/agent/auth-profiles.json << EOF
{
  "version": 1,
  "profiles": {
    "nvidia:default": {
      "type": "api_key",
      "provider": "nvidia",
      "key": "${NVIDIA_API_KEY}"
    }
  },
  "lastGood": {
    "nvidia": "nvidia:default"
  }
}
EOF

# Create openclaw.json with NVIDIA NIM as custom provider
if [ -n "$TELEGRAM_ALLOW_FROM" ]; then
cat > /data/.openclaw/openclaw.json << EOF
{
  "gateway": {
    "mode": "local",
    "port": 18789,
    "bind": "lan"
  },
  "models": {
    "mode": "merge",
    "providers": {
      "nvidia": {
        "baseUrl": "https://integrate.api.nvidia.com/v1",
        "apiKey": "${NVIDIA_API_KEY}",
        "api": "openai-completions",
        "models": [
          {
            "id": "moonshotai/kimi-k2.5",
            "name": "kimi-k2.5",
            "reasoning": true,
            "input": ["text", "image"],
            "contextWindow": 262144
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "workspace": "/data/workspace",
      "model": {
        "primary": "nvidia/moonshotai/kimi-k2.5"
      }
    }
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "botToken": "${TELEGRAM_BOT_TOKEN}",
      "allowFrom": ["${TELEGRAM_ALLOW_FROM}"]
    }
  }
}
EOF
else
cat > /data/.openclaw/openclaw.json << EOF
{
  "gateway": {
    "mode": "local",
    "port": 18789,
    "bind": "lan"
  },
  "models": {
    "mode": "merge",
    "providers": {
      "nvidia": {
        "baseUrl": "https://integrate.api.nvidia.com/v1",
        "apiKey": "${NVIDIA_API_KEY}",
        "api": "openai-completions",
        "models": [
          {
            "id": "moonshotai/kimi-k2.5",
            "name": "kimi-k2.5",
            "reasoning": true,
            "input": ["text", "image"],
            "contextWindow": 262144
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "workspace": "/data/workspace",
      "model": {
        "primary": "nvidia/moonshotai/kimi-k2.5"
      }
    }
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "botToken": "${TELEGRAM_BOT_TOKEN}"
    }
  }
}
EOF
fi

echo "Running OpenClaw doctor to fix config..."
/usr/local/bin/openclaw doctor --fix --yes 2>/dev/null || true

echo "Starting OpenClaw gateway..."

# For containers, run the gateway in foreground mode
# Using 'gateway' (not 'gateway start') with explicit foreground options
export OPENCLAW_GATEWAY_TOKEN=${OPENCLAW_GATEWAY_TOKEN:-$(openssl rand -hex 32)}
exec /usr/local/bin/openclaw gateway --port 18789 --bind lan --verbose 2>&1
