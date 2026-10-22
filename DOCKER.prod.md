# Production-Grade Docker Build Guide

This document describes the production-optimized multi-stage Dockerfile (`Dockerfile.prod`) for `opencode-free-bridge`.

## Overview

`Dockerfile.prod` is a production-grade multi-stage build that creates minimal, secure container images with the following improvements over the standard `Dockerfile`:

### Key Features

1. **Multi-stage build**: Separates build-time operations from runtime, reducing attack surface
2. **Minimal image size**: Only includes necessary runtime files (excludes tests, docs, git history)
3. **Security hardening**: 
   - Runs as non-root `bun` user
   - Proper file permissions (644 for files, 755 for scripts)
   - Production environment variables
4. **Validation layer**: Verifies critical files exist before creating the runtime image
5. **OCI metadata**: Includes standard container labels for better registry integration
6. **Production defaults**: Sets `NODE_ENV=production` and `AUTO_UPDATE=0`

## Build Comparison

| Feature | Original Dockerfile | Dockerfile.prod |
|---------|-------------------|-----------------|
| Build stages | Single stage | Multi-stage (builder + runtime) |
| Image size | 172MB | 172MB (same, but cleaner) |
| File validation | None | Pre-flight checks in builder |
| Production ENV | Partial | Full (`NODE_ENV`, `AUTO_UPDATE=0`) |
| OCI labels | No | Yes (title, description, source, license) |
| File permissions | Basic | Explicit (644/755) |

## Building the Production Image

### Basic build

```bash
docker build -f Dockerfile.prod -t opencode-free-bridge:prod .
```

### Build with custom tag

```bash
docker build -f Dockerfile.prod -t myregistry/opencode-free-bridge:2.2.1 .
```

### Multi-platform build

```bash
docker buildx build --platform linux/amd64,linux/arm64 \
  -f Dockerfile.prod \
  -t opencode-free-bridge:prod .
```

## Running the Production Container

### Using docker run

```bash
docker run -d \
  --name opencode-bridge \
  -p 127.0.0.1:20129:20129 \
  -v bridge-cache:/data/cache \
  -v bridge-state:/data/state \
  --restart unless-stopped \
  --security-opt no-new-privileges \
  --cap-drop ALL \
  opencode-free-bridge:prod
```

### Using docker-compose

Create a `docker-compose.prod.yml`:

```yaml
version: '3.8'

services:
  bridge:
    image: opencode-free-bridge:prod
    container_name: opencode-bridge
    restart: unless-stopped
    ports:
      - "127.0.0.1:20129:20129"
    volumes:
      - bridge-cache:/data/cache
      - bridge-state:/data/state
    environment:
      - PORT=20129
      - HOST=0.0.0.0
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL

volumes:
  bridge-cache:
  bridge-state:
```

Then run:

```bash
docker-compose -f docker-compose.prod.yml up -d
```

## Build Verification

After building, verify the image works correctly:

```bash
# 1. Check image was created
docker images opencode-free-bridge:prod

# 2. Run health check
docker run --rm -d -p 20130:20129 opencode-free-bridge:prod
sleep 5
curl http://127.0.0.1:20130/health

# 3. Check models endpoint
curl http://127.0.0.1:20130/v1/models

# 4. Stop test container
docker stop $(docker ps -q --filter ancestor=opencode-free-bridge:prod)
```

## Environment Variables

All standard environment variables from the main `Dockerfile` are supported:

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `20129` | HTTP server port |
| `HOST` | `0.0.0.0` | Bind address (use `0.0.0.0` in containers) |
| `OPENCODE_CACHE_DIR` | `/data/cache` | Catalog cache directory |
| `OPENCODE_BRIDGE_STATE_DIR` | `/data/state` | Proxy config directory |
| `NODE_ENV` | `production` | Environment mode |
| `AUTO_UPDATE` | `0` | Disable self-updates (image is unit of deployment) |

## Security Considerations

1. **Non-root user**: Container runs as `bun` user (UID 1000)
2. **No privileged operations**: Drops all capabilities
3. **Minimal attack surface**: No build tools, tests, or documentation in runtime image
4. **Network isolation**: Bind to loopback only unless behind authenticated proxy

## Differences from Standard Dockerfile

The production Dockerfile adds:

1. **Builder stage validation**: Fails fast if critical files are missing
2. **Explicit permissions**: Sets 644 for files, 755 for scripts
3. **Production environment**: `NODE_ENV=production`, `AUTO_UPDATE=0`
4. **OCI labels**: Standard container metadata

The standard `Dockerfile` remains simpler and suitable for development or quick deployments.
