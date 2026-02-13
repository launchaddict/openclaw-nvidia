#!/bin/sh
set -e

PORT=${PORT:-8080}
mkdir -p /data/.openclaw/agents/main/agent /data/workspace

# GitHub PAT setup (for claw to push)
if [ -n "$GITHUB_PAT" ]; then
  git config --global user.email "claw@openclaw.local"
  git config --global user.name "OpenClaw"
  git config --global credential.helper store
  echo "https://launchaddict:${GITHUB_PAT}@github.com" > ~/.git-credentials
fi

# Write fresh config with env vars EXPANDED (this actually works)
cat > /data/.openclaw/openclaw.json << EOF
{
  "gateway": {
    "mode": "local",
    "port": ${PORT},
    "bind": "lan",
    "auth": {
      "token": "${OPENCLAW_GATEWAY_TOKEN:-$(openssl rand -hex 32)}"
    }
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
  },
  "browser": {
    "enabled": true,
    "defaultProfile": "openclaw"
  }
}
EOF

# Auth profiles (with actual API key)
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

# GitHub state sync (optional - only syncs memory/state, not config)
if [ -n "$GITHUB_PAT" ] && [ -n "$GITHUB_CONFIG_REPO" ]; then
  echo "📥 Restoring state from GitHub..."
  TEMP_DIR=$(mktemp -d)
  if git clone --depth 1 "https://${GITHUB_PAT}@github.com/${GITHUB_CONFIG_REPO}.git" "$TEMP_DIR" 2>/dev/null; then
    # Restore only state files (not config)
    cp "$TEMP_DIR"/memory* /data/.openclaw/ 2>/dev/null || true
    cp -r "$TEMP_DIR/sessions" /data/.openclaw/agents/main/ 2>/dev/null || true
    echo "✅ State restored"
  fi
  rm -rf "$TEMP_DIR"
fi

# Backup function for state only
backup_state() {
  if [ -z "$GITHUB_PAT" ] || [ -z "$GITHUB_CONFIG_REPO" ]; then
    return 0
  fi
  echo "📤 Backing up state..."
  TEMP_DIR=$(mktemp -d)
  cd "$TEMP_DIR"
  git clone --depth 1 "https://${GITHUB_PAT}@github.com/${GITHUB_CONFIG_REPO}.git" . 2>/dev/null || git init
  
  # Copy state only
  cp /data/.openclaw/memory* . 2>/dev/null || true
  cp -r /data/.openclaw/agents/main/sessions . 2>/dev/null || true
  
  git add -A 2>/dev/null || true
  git commit -m "state: $(date -u +%Y-%m-%d_%H:%M:%S)" 2>/dev/null || true
  git push "https://${GITHUB_PAT}@github.com/${GITHUB_CONFIG_REPO}.git" main 2>/dev/null || true
  cd /
  rm -rf "$TEMP_DIR"
}

trap 'backup_state' TERM INT

echo "🦞 Starting OpenClaw..."

# Ensure data directories exist
mkdir -p /data/.openclaw/credentials /data/.openclaw/agents/main/sessions

# Run doctor --fix to enable Telegram (as suggested by the logs)
/usr/local/bin/openclaw doctor --fix --yes

# Start gateway in foreground (required for containers)
exec /usr/local/bin/openclaw gateway --port "${PORT}" --bind lan --verbose 2>&1
