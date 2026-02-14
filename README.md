# Moltaddict - OpenClaw z.ai Image

Pre-configured OpenClaw Docker image with:
- **Provider:** Z.ai (GLM models)
- **Model:** GLM-4.7
- **Channels:** Telegram bot support
- **Security:** Tailscale Serve for Mission Control access

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `ZAI_API_KEY` | Yes | Your Z.ai API key from https://z.ai/ |
| `TELEGRAM_BOT_TOKEN` | Yes | Telegram bot token from @BotFather |
| `TELEGRAM_ALLOW_FROM` | Optional | Telegram user ID to restrict access |
| `TAILSCALE_AUTH_KEY` | Recommended | Tailscale auth key for secure Mission Control access |
| `OPENCLAW_GATEWAY_TOKEN` | Optional | Custom gateway token (auto-generated if not set, unused with Tailscale) |

## Security: Tailscale Serve (Recommended)

Mission Control is secured via Tailscale Serve, which provides:
- **Identity-based authentication** - Only devices on your Tailscale tailnet can access
- **HTTPS** - Automatic TLS via Tailscale
- **No tokens needed** - Your Tailscale identity authenticates you

### Setup

1. Create a Tailscale account at https://tailscale.com/
2. Generate an auth key at https://login.tailscale.com/admin/settings/keys
   - Enable "Reusable" and "Preapproved" for Railway deployments
3. Add `TAILSCALE_AUTH_KEY` to your Railway variables
4. Access Mission Control at `https://<your-machine-name>.<your-tailnet>.ts.net/`

### Without Tailscale

If `TAILSCALE_AUTH_KEY` is not set:
- Gateway binds to LAN (`0.0.0.0`)
- Requires token authentication via `OPENCLAW_GATEWAY_TOKEN`
- Less secure - token can be leaked or shared

## Browser/Chrome Tool

OpenClaw's browser tool is enabled by default. The agent can:
- Navigate web pages, click, type, take screenshots
- Use Chrome/Chromium for web automation

The Dockerfile includes Chromium. Just ask the agent via Telegram to browse something.

## Usage in Railway

1. Create empty service
2. Source: `ghcr.io/launchaddict/moltaddict:latest`
3. Add env vars:
   - `ZAI_API_KEY` (required)
   - `TELEGRAM_BOT_TOKEN` (required)
   - `TELEGRAM_ALLOW_FROM` (recommended - your Telegram user ID)
   - `TAILSCALE_AUTH_KEY` (recommended for secure access)
4. Add volume at `/data` (persists state, sessions, workspace)
5. Deploy

## Manual Docker

```bash
docker run -d \
  -e ZAI_API_KEY=your_key \
  -e TELEGRAM_BOT_TOKEN=your_token \
  -e TAILSCALE_AUTH_KEY=tskey-auth-xxx \
  -v openclaw-data:/data \
  -p 18789:18789 \
  ghcr.io/launchaddict/moltaddict:latest
```
