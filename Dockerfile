# opencode-free-bridge Dockerfile
# Requires Bun runtime for TLS fingerprint parity with OpenCode CLI

FROM oven/bun:1.1.38-alpine AS base

# Install runtime dependencies
RUN apk add --no-cache \
    ca-certificates \
    curl

# Create non-root user
RUN addgroup -g 1001 -S bridge && \
    adduser -u 1001 -S bridge -G bridge

WORKDIR /app

# Copy application files
COPY --chown=bridge:bridge server.js ./
COPY --chown=bridge:bridge identity.js ./
COPY --chown=bridge:bridge token-budget.js ./
COPY --chown=bridge:bridge verify.js ./
COPY --chown=bridge:bridge gate-drill.js ./
COPY --chown=bridge:bridge transport-fingerprint.js ./
COPY --chown=bridge:bridge transport-baseline.json ./
COPY --chown=bridge:bridge tunnel-doctor.sh ./
COPY --chown=bridge:bridge package.json ./

# Make scripts executable
RUN chmod +x server.js verify.js gate-drill.js transport-fingerprint.js tunnel-doctor.sh

# Create cache directory with proper permissions BEFORE switching to non-root user
RUN mkdir -p /app/.cache && \
    chown -R bridge:bridge /app/.cache

# Switch to non-root user
USER bridge

# Expose default port
EXPOSE 20129

# Environment variables (can be overridden at runtime)
ENV PORT=20129 \
    HOST=0.0.0.0 \
    NODE_ENV=production \
    OPENCODE_CACHE_DIR=/app/.cache

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:${PORT}/health || exit 1

# Start the bridge
CMD ["bun", "server.js"]
