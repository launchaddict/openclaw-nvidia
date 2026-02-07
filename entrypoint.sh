#!/bin/sh
set -e

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

# Create openclaw.json
cat > /data/.openclaw/openclaw.json << EOF
{
  "gateway": {
    "mode": "local",
    "port": 18789
  },
  "agents": {
    "defaults": {
      "provider": "moonshot",
      "model": {
        "primary": "moonshotai/kimi-k2.5"
      }
    },
    "channels": {
      "telegram": {
        "enabled": true,
        "botToken": "${TELEGRAM_BOT_TOKEN}"
      }
    }
  }
}
EOF

# Start OpenClaw gateway
exec /usr/local/bin/openclaw gateway start --port 18789 --bind 0.0.0.0
