# OpenClaw NVIDIA Image

Pre-configured OpenClaw Docker image with:
- **Provider:** Moonshot (via NVIDIA NIM)
- **Model:** moonshotai/kimi-k2.5
- **Channels:** Telegram bot support

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `NVIDIA_API_KEY` | Yes | Your NVIDIA API key for Moonshot/Kimi |
| `TELEGRAM_BOT_TOKEN` | Yes | Telegram bot token from @BotFather |
| `OPENCLAW_GATEWAY_TOKEN` | Optional | Custom gateway token (auto-generated if not set) |

## Usage in Railway

1. Create empty service
2. Source: `ghcr.io/launchaddict/openclaw-nvidia:latest`
3. Add env vars
4. Add volume at `/data`
5. Deploy

## Manual Docker

```bash
docker run -d \
  -e NVIDIA_API_KEY=your_key \
  -e TELEGRAM_BOT_TOKEN=your_token \
  -p 18789:18789 \
  ghcr.io/launchaddict/openclaw-nvidia:latest
```
