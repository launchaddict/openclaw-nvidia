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

# Start Tailscale if auth key is provided
if [ -n "$TAILSCALE_AUTH_KEY" ]; then
  echo "Starting Tailscale daemon..."
  mkdir -p /data/tailscale /var/run/tailscale
  tailscaled --state=/data/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock &
  sleep 2

  echo "Connecting to Tailscale..."
  tailscale up --authkey="$TAILSCALE_AUTH_KEY" --accept-routes --ssh

  # Get the Tailscale hostname for display
  TAILSCALE_HOST=$(tailscale status --json 2>/dev/null | grep -o '"HostName":"[^"]*"' | head -1 | cut -d'"' -f4)
  echo "✓ Connected to Tailscale as: $TAILSCALE_HOST"
else
  echo "⚠️  TAILSCALE_AUTH_KEY not set - Mission Control will use token auth only"
  echo "   For secure Tailscale access, set TAILSCALE_AUTH_KEY in Railway Variables"
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

# Determine bind mode: use loopback with Tailscale Serve, otherwise lan
if [ -n "$TAILSCALE_AUTH_KEY" ]; then
  GATEWAY_BIND="loopback"
  TAILSCALE_CONFIG='"tailscale": { "mode": "serve" }'
  AUTH_CONFIG='"auth": { "allowTailscale": true }'
else
  GATEWAY_BIND="lan"
  TAILSCALE_CONFIG=""
  AUTH_CONFIG='"auth": { "mode": "token" }'
fi

if [ -n "$TELEGRAM_ALLOW_FROM" ]; then
cat > /data/.openclaw/openclaw.json << EOF
{
  "gateway": {
    "mode": "local",
    "port": ${PORT},
    "bind": "${GATEWAY_BIND}",
    ${AUTH_CONFIG}${TAILSCALE_CONFIG:+,
    ${TAILSCALE_CONFIG}}
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
    "bind": "${GATEWAY_BIND}",
    ${AUTH_CONFIG}${TAILSCALE_CONFIG:+,
    ${TAILSCALE_CONFIG}}
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

# Use Tailscale serve mode if configured
if [ -n "$TAILSCALE_AUTH_KEY" ]; then
  echo "✓ Tailscale Serve enabled - access Mission Control via https://<your-magic-dns>/"
  exec /usr/local/bin/openclaw gateway --port "${PORT}" --bind loopback --tailscale serve --verbose 2>&1
else
  export OPENCLAW_GATEWAY_TOKEN=${OPENCLAW_GATEWAY_TOKEN:-$(openssl rand -hex 32)}
  exec /usr/local/bin/openclaw gateway --port "${PORT}" --bind lan --verbose 2>&1
fi
