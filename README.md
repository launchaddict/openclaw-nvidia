# OpenClaw z.ai Image

Pre-configured OpenClaw Docker image with:
- **Provider:** Z.ai (GLM models)
- **Model:** GLM-4.7
- **Channels:** Telegram bot support

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `ZAI_API_KEY` | Yes | Your Z.ai API key from https://z.ai/ |
| `TELEGRAM_BOT_TOKEN` | Yes | Telegram bot token from @BotFather |
| `TELEGRAM_ALLOW_FROM` | Optional | Telegram user ID to restrict access |
| `OPENCLAW_GATEWAY_TOKEN` | Optional | Custom gateway token (auto-generated if not set) |

## Usage in Railway

1. Create empty service
2. Source: `ghcr.io/launchaddict/openclaw-nvidia:latest`
3. Add env vars (`ZAI_API_KEY` and `TELEGRAM_BOT_TOKEN`)
4. Add volume at `/data`
5. Deploy

## Manual Docker

```bash
docker run -d \
  -e ZAI_API_KEY=your_key \
  -e TELEGRAM_BOT_TOKEN=your_token \
  -p 18789:18789 \
  ghcr.io/launchaddict/openclaw-nvidia:latest
```
