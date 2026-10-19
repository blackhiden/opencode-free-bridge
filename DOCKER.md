# Docker Deployment Guide

This guide covers running `opencode-free-bridge` in Docker containers.

## Quick Start

### Using Docker Compose (Recommended)

```bash
# Build and start the bridge
docker-compose up -d

# View logs
docker-compose logs -f

# Check health
curl -s http://localhost:20129/health | jq

# Stop the bridge
docker-compose down
```

### Using Docker CLI

```bash
# Build the image
docker build -t opencode-free-bridge:latest .

# Run the container
docker run -d \
  --name opencode-free-bridge \
  -p 20129:20129 \
  -e PORT=20129 \
  -e HOST=0.0.0.0 \
  -v opencode-cache:/app/.cache \
  --restart unless-stopped \
  opencode-free-bridge:latest

# View logs
docker logs -f opencode-free-bridge

# Check health
curl -s http://localhost:20129/health | jq

# Stop and remove
docker stop opencode-free-bridge
docker rm opencode-free-bridge
```

---

## Configuration

### Environment Variables

All standard bridge environment variables are supported:

| Variable | Default | Description |
|---|---|---|
| `PORT` | `20129` | Server port |
| `HOST` | `0.0.0.0` | Bind address (use `0.0.0.0` for Docker) |
| `UPDATE_MODE` | `reactive` | Identity update mode (`reactive` or `always`) |
| `AUTO_UPDATE` | `1` | Enable self-update |
| `OPENCODE_CACHE_DIR` | `/app/.cache` | Catalog cache directory |
| `UPSTREAM_TIMEOUT_MS` | `120000` | Upstream request timeout |
| `IDENTITY_TTL_MS` | `900000` | Identity cache TTL (15 min) |
| `GATE_RETRY_COOLDOWN_MS` | `30000` | Gate retry cooldown (30 sec) |
| `CORS_ORIGIN` | `""` | CORS origin (empty = disabled) |

### Port Mapping

The default port is `20129`. To run on a different host port:

```bash
# Run on port 3000
docker run -d -p 3000:20129 opencode-free-bridge:latest

# Or with docker-compose (edit docker-compose.yml)
ports:
  - "3000:20129"
```

### Volume Mounts

**Cache persistence** (recommended):
```bash
docker run -d \
  -v opencode-cache:/app/.cache \
  opencode-free-bridge:latest
```

Without a volume, the catalog cache is lost on container restart, causing a 5-10s cold start delay.

---

## Multi-Host Setup

Run multiple bridge instances to bypass single-IP rate limits:

### Multiple Containers on Same Host

```yaml
# docker-compose.yml
version: '3.8'

services:
  bridge-1:
    build: .
    ports:
      - "20129:20129"
    volumes:
      - cache-1:/app/.cache
  
  bridge-2:
    build: .
    ports:
      - "20130:20129"
    volumes:
      - cache-2:/app/.cache

volumes:
  cache-1:
  cache-2:
```

### Remote Bridge via SSH Tunnel

```bash
# On remote host
docker run -d -p 20129:20129 opencode-free-bridge:latest

# On local machine
ssh -N -L 20130:localhost:20129 user@remote-host
```

---

## Verification

### Health Check

```bash
# Using curl
curl -s http://localhost:20129/health | jq

# Using docker exec
docker exec opencode-free-bridge curl -s http://localhost:20129/health
```

Expected output includes:
- `status: "healthy"`
- `identity.version` (OpenCode CLI version)
- `identity.gate.anchors` (gate validation state)

### Quick Verification

```bash
# Run verify.js inside container
docker exec opencode-free-bridge bun verify.js --quick

# Expected exit code: 0 (at least one model answered)
# Exit code 1: all models failed
# Exit code 2: gate closed (IP throttled)
```

### TLS Fingerprint Check

```bash
docker exec opencode-free-bridge bun transport-fingerprint.js --check

# Expected output: "TLS fingerprint matches baseline"
# Exit code 0: match, Exit code 1: drift detected
```

### List Active Models

```bash
curl -s http://localhost:20129/v1/models | jq '.data[].id'
```

### Test Chat Completion

```bash
curl -s http://localhost:20129/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"mimo","messages":[{"role":"user","content":"Reply with OK"}]}' | jq
```

---

## Production Deployment

### Best Practices

1. **Use a reverse proxy** (nginx, Traefik, Caddy) for SSL termination and load balancing.
2. **Persist cache volume** to avoid cold start delays.
3. **Set resource limits** to prevent memory leaks.
4. **Configure restart policy** (`unless-stopped` or `always`).
5. **Monitor health endpoint** for alerting.

### Example Nginx Reverse Proxy

```nginx
upstream opencode_bridge {
    server localhost:20129;
    keepalive 32;
}

server {
    listen 443 ssl http2;
    server_name bridge.example.com;
    
    ssl_certificate /etc/ssl/certs/bridge.crt;
    ssl_certificate_key /etc/ssl/private/bridge.key;
    
    location / {
        proxy_pass http://opencode_bridge;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_buffering off;
        proxy_read_timeout 120s;
    }
}
```

### Resource Limits

```yaml
# docker-compose.yml
deploy:
  resources:
    limits:
      cpus: '2.0'
      memory: 1G
    reservations:
      cpus: '0.5'
      memory: 256M
```

---

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker logs opencode-free-bridge

# Common issues: port conflict, insufficient memory, volume permissions
```

### Health Check Failing

```bash
# Check if server is responding
docker exec opencode-free-bridge curl -v http://localhost:20129/health

# Verify Bun runtime
docker exec opencode-free-bridge bun --version
```

### Models Not Loading

```bash
# Check catalog cache
docker exec opencode-free-bridge ls -la /app/.cache/

# Force catalog refresh
docker exec opencode-free-bridge rm -f /app/.cache/catalog.json
docker restart opencode-free-bridge
```

### 403 FreeTierError

```bash
# Check gate state
docker exec opencode-free-bridge curl -s http://localhost:20129/health | jq '.identity.gate'

# Run gate drill
docker exec opencode-free-bridge bun gate-drill.js session-shape
```

---

## Security & Monitoring

### Security Best Practices

1. **Non-root user**: Container runs as user `bridge` (UID 1001).
2. **Read-only filesystem**: Add `--read-only` with tmpfs mounts for enhanced security.
3. **Network isolation**: Use Docker networks for service communication.
4. **Image scanning**: Regularly scan with `docker scan` or Trivy.

### Health Monitoring

```bash
# Simple uptime check
watch -n 10 'curl -s http://localhost:20129/health | jq -r .status'

# Watch for auto-updates
docker logs -f opencode-free-bridge | grep -i update
```

---

## FAQ

**Q: Why does the container exit immediately?**  
A: Check logs with `docker logs`. Common causes: port conflict, Bun runtime issues.

**Q: Can I run this on Kubernetes?**  
A: Yes. Use the Dockerfile to build an image, deploy with standard K8s manifests.

**Q: Does it work on ARM (Raspberry Pi, Apple Silicon)?**  
A: Yes, if Bun supports your architecture (`linux/amd64`, `linux/arm64` supported).

**Q: How do I disable auto-update?**  
A: Set `AUTO_UPDATE=0` in environment variables.

---

For bridge-specific issues, refer to `README.md`, `AGENTS.md`, and `CODE_GRAPH.md`.
