# ==============================================================================
# SLIM PRODUCTION DOCKERFILE - Node.js only (~200MB vs ~3GB)
# Flutter Web is pre-built by GitHub Actions and committed to build/web
# Compatible with Render, DigitalOcean & Docker Cloud
# ==============================================================================

# ------------------------------------------------------------------------------
# Single Stage: Node.js 20 Alpine Full-Stack Server
# Flutter web assets are already built by GitHub Actions CI
# ------------------------------------------------------------------------------
FROM node:20-alpine

WORKDIR /app

# Install postgresql-client for pg_dump/backups and tzdata for accurate timezone support
RUN apk add --no-cache postgresql-client tzdata wget

# Copy package definitions and install production dependencies
COPY backend/package*.json ./
RUN npm ci --only=production || npm install --omit=dev

# Copy backend source code
COPY backend/ .

# Copy pre-built Flutter Web SPA assets (built by GitHub Actions, committed to repo)
COPY build/web ./public

# Expose container port (Default 3000, dynamically overridden by cloud hosts)
EXPOSE 3000 8080 10000

# Set standard cloud production environment variables
ENV NODE_ENV=production \
    PORT=3000 \
    HOST=0.0.0.0 \
    TZ=Asia/Kolkata \
    DEFAULT_TIMEZONE=Asia/Kolkata

# Built-in health check for zero-downtime rolling deploys on Render & DigitalOcean
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:${PORT:-3000}/api/system/server-time || exit 1

# Start full-stack server
CMD ["node", "server.js"]
