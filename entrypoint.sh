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

# GitHub sync configuration (optional - for persistent state across redeploys)
GITHUB_REPO=${GITHUB_REPO:-""}
GITHUB_PAT=${GITHUB_PAT:-""}
GITHUB_BRANCH=${GITHUB_BRANCH:-"main"}

# Functions for GitHub sync
restore_from_github() {
  if [ -z "$GITHUB_REPO" ] || [ -z "$GITHUB_PAT" ]; then
    return 0
  fi

  echo "📥 Restoring /data from GitHub ($GITHUB_REPO)..."

  # Setup git config
  git config --global user.email "claw@openclaw.local"
  git config --global user.name "OpenClaw"

  # Clone or pull
  TEMP_DIR=$(mktemp -d)
  if git clone --depth 1 --branch "$GITHUB_BRANCH" "https://${GITHUB_PAT}@github.com/${GITHUB_REPO}.git" "$TEMP_DIR" 2>/dev/null; then
    # Restore data (preserve existing if newer)
    if [ -d "$TEMP_DIR/data" ]; then
      rsync -a --ignore-existing "$TEMP_DIR/data/" /data/ 2>/dev/null || cp -r "$TEMP_DIR/data/"* /data/ 2>/dev/null || true
      echo "✅ Restored state from GitHub"
    fi
    rm -rf "$TEMP_DIR"
  else
    echo "⚠️  Could not restore from GitHub (repo may be empty or PAT invalid)"
    rm -rf "$TEMP_DIR"
  fi
}

backup_to_github() {
  if [ -z "$GITHUB_REPO" ] || [ -z "$GITHUB_PAT" ]; then
    return 0
  fi

  echo "📤 Backing up /data to GitHub ($GITHUB_REPO)..."

  TEMP_DIR=$(mktemp -d)
  cd "$TEMP_DIR"

  # Clone existing repo or init fresh
  if ! git clone --depth 1 --branch "$GITHUB_BRANCH" "https://${GITHUB_PAT}@github.com/${GITHUB_REPO}.git" . 2>/dev/null; then
    git init
    git checkout -b "$GITHUB_BRANCH" 2>/dev/null || true
  fi

  # Copy current /data (exclude sensitive files)
  mkdir -p data
  # Copy everything except auth files with secrets
  find /data -type f ! -name "auth-profiles.json" ! -name "auth.json" ! -name "*.key" ! -name "*.pem" -exec cp --parents {} data/ \; 2>/dev/null || true

  # Commit and push
  git add -A 2>/dev/null || true
  if git diff --cached --quiet 2>/dev/null; then
    echo "📤 No changes to backup"
  else
    git commit -m "backup: claw state $(date -u +%Y-%m-%d_%H:%M:%S)" 2>/dev/null || true
    if git push "https://${GITHUB_PAT}@github.com/${GITHUB_REPO}.git" "$GITHUB_BRANCH" 2>/dev/null; then
      echo "✅ Backed up to GitHub"
    else
      echo "⚠️  GitHub push failed"
    fi
  fi

  cd /
  rm -rf "$TEMP_DIR"
}

# Trap SIGTERM for graceful shutdown with backup
trap 'echo "🛑 SIGTERM received, backing up..."; backup_to_github; exit 0' TERM INT

# Restore state on startup
restore_from_github

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

# Start openclaw in background so we can trap signals
/usr/local/bin/openclaw gateway --port "${PORT}" --bind lan --verbose 2>&1 &
CLAW_PID=$!

# Wait for claw to exit (or receive SIGTERM)
wait $CLAW_PID
CLAW_EXIT=$?

# Backup on exit
echo "💾 Claw exited (code: $CLAW_EXIT), backing up state..."
backup_to_github

exit $CLAW_EXIT
