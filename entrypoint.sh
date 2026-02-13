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

# GitHub PAT for pushing (optional - enables claw to push to GitHub)
if [ -n "$GITHUB_PAT" ]; then
  echo "🔑 Configuring Git with GitHub PAT..."
  git config --global user.email "claw@openclaw.local"
  git config --global user.name "OpenClaw"
  # Store PAT for HTTPS auth
  git config --global credential.helper store
  echo "https://launchaddict:${GITHUB_PAT}@github.com" > ~/.git-credentials
fi

# GitHub config sync (optional - for persistent config across redeploys)
GITHUB_CONFIG_REPO=${GITHUB_CONFIG_REPO:-""}
CONFIG_BACKUP_INTERVAL=${CONFIG_BACKUP_INTERVAL:-86400}  # 24 hours default (set to 0 to disable)

if [ -n "$GITHUB_PAT" ]; then
  echo "🔑 Configuring Git with GitHub PAT..."
  git config --global user.email "claw@openclaw.local"
  git config --global user.name "OpenClaw"
  git config --global credential.helper store
  echo "https://launchaddict:${GITHUB_PAT}@github.com" > ~/.git-credentials

  # Sync config from GitHub if repo specified
  if [ -n "$GITHUB_CONFIG_REPO" ]; then
    echo "📥 Syncing config from GitHub ($GITHUB_CONFIG_REPO)..."
    TEMP_DIR=$(mktemp -d)
    if git clone --depth 1 "https://${GITHUB_PAT}@github.com/${GITHUB_CONFIG_REPO}.git" "$TEMP_DIR" 2>/dev/null; then
      # Restore config files (but not auth files with secrets)
      find "$TEMP_DIR" -name "*.json" ! -name "auth-profiles.json" ! -name "auth.json" -exec cp {} /data/.openclaw/ \; 2>/dev/null || true
      find "$TEMP_DIR" -name "*.yaml" -o -name "*.yml" | xargs -I {} cp {} /data/.openclaw/ 2>/dev/null || true
      # Expand env vars in restored config (e.g., ${TELEGRAM_BOT_TOKEN})
      if [ -f /data/.openclaw/openclaw.json ]; then
        echo "🔧 Expanding env vars in config..."
        envsubst < /data/.openclaw/openclaw.json > /data/.openclaw/openclaw.json.tmp && mv /data/.openclaw/openclaw.json.tmp /data/.openclaw/openclaw.json
      fi
      echo "✅ Config restored from GitHub"
    fi
    rm -rf "$TEMP_DIR"
  fi
fi

# Function to backup config to GitHub
backup_config() {
  if [ -z "$GITHUB_PAT" ] || [ -z "$GITHUB_CONFIG_REPO" ]; then
    return 0
  fi

  echo "📤 Backing up config to GitHub..."
  TEMP_DIR=$(mktemp -d)
  cd "$TEMP_DIR"

  # Clone or init
  if ! git clone --depth 1 "https://${GITHUB_PAT}@github.com/${GITHUB_CONFIG_REPO}.git" . 2>/dev/null; then
    git init
    git remote add origin "https://${GITHUB_PAT}@github.com/${GITHUB_CONFIG_REPO}.git"
  fi

  # Copy config (exclude secrets)
  cp /data/.openclaw/*.json . 2>/dev/null || true
  cp /data/.openclaw/*.yaml . 2>/dev/null || true
  rm -f auth-profiles.json auth.json 2>/dev/null || true

  # Commit and push
  git add -A 2>/dev/null || true
  if ! git diff --cached --quiet 2>/dev/null; then
    git commit -m "config: $(date -u +%Y-%m-%d_%H:%M:%S)" 2>/dev/null || true
    git push origin HEAD:main 2>/dev/null || git push -u origin HEAD:main 2>/dev/null || echo "⚠️  Config backup failed"
  fi

  cd /
  rm -rf "$TEMP_DIR"
}

# Trap SIGTERM for backup on graceful shutdown
trap 'echo "🛑 SIGTERM - backing up config..."; backup_config; exit 0' TERM INT

# Start periodic backup in background if enabled
if [ -n "$GITHUB_PAT" ] && [ -n "$GITHUB_CONFIG_REPO" ] && [ "$CONFIG_BACKUP_INTERVAL" -gt 0 ]; then
  (
    while true; do
      sleep "$CONFIG_BACKUP_INTERVAL"
      backup_config
    done
  ) &
  BACKUP_PID=$!
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
