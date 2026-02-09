#!/bin/sh
set -e

# Validate environment variables
if [ -z "$ZAI_API_KEY" ]; then
  echo "⚠️  WARNING: ZAI_API_KEY not set!"
  echo "   Get your API key from: https://z.ai/"
  echo "   Set it in Railway Variables and redeploy."
  echo ""
fi

if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
  echo "⚠️  WARNING: TELEGRAM_BOT_TOKEN not set!"
  echo "   Get your bot token from @BotFather on Telegram"
  echo "   Set it in Railway Variables and redeploy."
  echo ""
fi

# Ensure required directories exist
PORT=${PORT:-18789}
mkdir -p /data/.openclaw/agents/main/agent /data/workspace

# Optional config regeneration (set OPENCLAW_REGENERATE_CONFIG=1 to force)
if [ "$OPENCLAW_REGENERATE_CONFIG" = "1" ]; then
  rm -f /data/.openclaw/openclaw.json
  rm -f /data/.openclaw/agents/main/agent/auth-profiles.json
  rm -f /data/.openclaw/agents/main/agent/auth.json
fi

# Create auth-profiles.json for Z.ai (only if missing or regen forced)
if [ "$OPENCLAW_REGENERATE_CONFIG" = "1" ] || [ ! -f /data/.openclaw/agents/main/agent/auth-profiles.json ]; then
cat > /data/.openclaw/agents/main/agent/auth-profiles.json << EOF
{
  "version": 1,
  "profiles": {
    "zai:default": {
      "type": "api_key",
      "provider": "zai",
      "key": "${ZAI_API_KEY}"
    }
  },
  "lastGood": {
    "zai": "zai:default"
  }
}
EOF
fi

# Create openclaw.json with Z.ai GLM 4.7 as the provider (only if missing or regen forced)
if [ "$OPENCLAW_REGENERATE_CONFIG" = "1" ] || [ ! -f /data/.openclaw/openclaw.json ]; then
if [ -n "$TELEGRAM_ALLOW_FROM" ]; then
cat > /data/.openclaw/openclaw.json << EOF
{
  "gateway": {
    "mode": "local",
    "port": ${PORT},
    "bind": "lan"
  },
  "models": {
    "mode": "merge",
    "providers": {
      "zai": {
        "baseUrl": "https://api.z.ai/api/coding/paas/v4",
        "apiKey": "${ZAI_API_KEY}",
        "api": "openai-completions",
        "models": [
          {
            "id": "glm-4.7",
            "name": "GLM-4.7",
            "reasoning": true,
            "input": ["text", "image"],
            "contextWindow": 128000
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "workspace": "/data/workspace",
      "model": {
        "primary": "zai/glm-4.7"
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
    "port": ${PORT},
    "bind": "lan"
  },
  "models": {
    "mode": "merge",
    "providers": {
      "zai": {
        "baseUrl": "https://api.z.ai/api/coding/paas/v4",
        "apiKey": "${ZAI_API_KEY}",
        "api": "openai-completions",
        "models": [
          {
            "id": "glm-4.7",
            "name": "GLM-4.7",
            "reasoning": true,
            "input": ["text", "image"],
            "contextWindow": 128000
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "workspace": "/data/workspace",
      "model": {
        "primary": "zai/glm-4.7"
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
fi

echo "Running OpenClaw doctor to fix config..."
/usr/local/bin/openclaw doctor --fix --yes 2>/dev/null || true

echo "Starting OpenClaw gateway on port ${PORT}..."

export OPENCLAW_GATEWAY_TOKEN=${OPENCLAW_GATEWAY_TOKEN:-$(openssl rand -hex 32)}
exec /usr/local/bin/openclaw gateway --port "${PORT}" --bind lan --verbose 2>&1
