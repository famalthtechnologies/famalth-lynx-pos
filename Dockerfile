# ==============================================================================
# UNIVERSAL CLOUD DOCKERFILE - COMPATIBLE WITH RENDER, DIGITALOCEAN & DOCKER CLOUD
# Multi-stage production container: Builds Flutter Web + Node.js Backend API
# ==============================================================================

# ------------------------------------------------------------------------------
# STAGE 1: Flutter Web Application Builder
# ------------------------------------------------------------------------------
FROM ghcr.io/cirrusci/flutter:stable AS flutter-builder

WORKDIR /app

# Cache dependency layer for faster iterative builds
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy frontend source, web configurations, and static assets
COPY lib/ ./lib/
COPY web/ ./web/
COPY assets/ ./assets/

# Build optimized production Flutter Web release (auto-renderer: HTML for mobile, CanvasKit for desktop)
RUN flutter build web --release --web-renderer auto

# ------------------------------------------------------------------------------
# STAGE 2: Node.js 20 Alpine Full-Stack Server
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

# Copy compiled Flutter Web SPA assets into backend static public folder
COPY --from=flutter-builder /app/build/web ./public

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
