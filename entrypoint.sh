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
      "dmPolicy": "allowlist",
      "allowFrom": ["${TELEGRAM_ALLOW_FROM}"],
      "commands": {
        "native": "auto"
      }
    }
  },
  "browser": {
    "enabled": true,
    "defaultProfile": "openclaw"
  }
}
EOF

# GitHub state sync (DISABLED - was restoring stale state)
# State will be fresh per deployment - only backup is enabled
# if [ -n "$GITHUB_PAT" ] && [ -n "$GITHUB_CONFIG_REPO" ]; then
#   echo "📥 Restoring state from GitHub..."
#   TEMP_DIR=$(mktemp -d)
#   if git clone --depth 1 "https://${GITHUB_PAT}@github.com/${GITHUB_CONFIG_REPO}.git" "$TEMP_DIR" 2>/dev/null; then
#     cp "$TEMP_DIR"/memory* /data/.openclaw/ 2>/dev/null || true
#     cp -r "$TEMP_DIR/sessions" /data/.openclaw/agents/main/ 2>/dev/null || true
#     echo "✅ State restored"
#   fi
#   rm -rf "$TEMP_DIR"
# fi

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
echo "📁 Data dir contents before start:"
ls -la /data/.openclaw/ 2>&1 || echo "(ls failed)"
echo "📄 Config file check:"
head -5 /data/.openclaw/openclaw.json 2>&1 || echo "(no config yet)"

# Ensure data directories exist with correct permissions
mkdir -p /data/.openclaw/credentials /data/.openclaw/agents/main/sessions
chmod 700 /data/.openclaw
chmod 600 /data/.openclaw/openclaw.json 2>/dev/null || true

# Start gateway in foreground (required for containers)
# Skip doctor --fix as it may not properly enable Telegram
exec /usr/local/bin/openclaw gateway --port "${PORT}" --bind lan --verbose 2>&1
