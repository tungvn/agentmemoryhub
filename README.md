# agentmemoryhub

Docker image that runs [agentmemory](https://github.com/agentmemory/agentmemory) with an optional [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) for public HTTPS access — no reverse proxy or open inbound ports required.

## What's inside

| Component | Purpose |
|-----------|---------|
| `agentmemory` | MCP-compatible memory server (REST + streaming) |
| `iii` | Embedded runtime for agentmemory |
| `cloudflared` | Optional Cloudflare Tunnel (skipped if no token provided) |
| `all-MiniLM-L6-v2` | Local vector embedding model, baked into the image |

## Quick start

```bash
# Generate a secret
export AGENTMEMORY_SECRET=$(openssl rand -hex 32)

docker run -d \
  -e AGENTMEMORY_SECRET="$AGENTMEMORY_SECRET" \
  -p 3111:3111 \
  -p 3112:3112 \
  -p 3113:3113 \
  -v agentmemory-data:/data \
  ghcr.io/tungvn/agentmemoryhub:latest
```

Health check: `curl http://localhost:3111/agentmemory/livez`

Real-time viewer: `open http://localhost:3113`

## Docker Compose

```bash
cp .env.example .env   # fill in AGENTMEMORY_SECRET (and optionally CLOUDFLARE_TOKEN)
docker compose up -d
```

`.env` variables:

| Variable | Required | Description |
|----------|----------|-------------|
| `AGENTMEMORY_SECRET` | Yes | HMAC secret for authenticating all API and MCP requests |
| `CLOUDFLARE_TOKEN` | No | Cloudflare Tunnel token — omit to run localhost-only |

## Cloudflare Tunnel (optional)

Set `CLOUDFLARE_TOKEN` to expose agentmemory over a public HTTPS URL without opening any inbound ports.

1. Create a tunnel in the [Cloudflare Zero Trust dashboard](https://one.dash.cloudflare.com/)
2. Point the tunnel to `http://localhost:3111`
3. Copy the token and add it to `.env`

```env
CLOUDFLARE_TOKEN=eyJ...
```

## Persistent data

All state is written to `/data` inside the container. Mount a volume or bind-mount a host directory there to survive container restarts.

```bash
-v /path/on/host:/data
```

## Build

```bash
docker build -t agentmemoryhub .
```

Build args (all have defaults):

| Arg | Default |
|-----|---------|
| `AGENTMEMORY_VERSION` | `0.9.21` |
| `III_VERSION` | `0.11.2` |
| `III_SDK_VERSION` | `0.11.2` |

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| `3111` | HTTP | REST API + MCP endpoint |
| `3112` | WebSocket | iii streaming engine |
| `3113` | HTTP | Real-time viewer UI (`http://localhost:3113`) |

> The viewer server in the upstream npm package binds to `127.0.0.1` by default. This image patches the bind address to `0.0.0.0` at build time so port 3113 is reachable from the host without a tunnel.

## License

[MIT](LICENSE)
