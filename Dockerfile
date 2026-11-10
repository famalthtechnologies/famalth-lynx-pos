# ==============================================================================
# UNIVERSAL CLOUD DOCKERFILE - COMPATIBLE WITH RENDER, DIGITALOCEAN & DOCKER CLOUD
# Multi-stage production container: Builds Flutter Web + Node.js Backend API
# ==============================================================================

# ------------------------------------------------------------------------------
# STAGE 1: Flutter Web Application Builder
# Uses official Ubuntu base + Flutter SDK install (CirrusCI image discontinued)
# ------------------------------------------------------------------------------
FROM ubuntu:22.04 AS flutter-builder

# Avoid interactive prompts during apt installs
ENV DEBIAN_FRONTEND=noninteractive

# Install Flutter SDK dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter stable SDK
ARG FLUTTER_VERSION=3.41.6
RUN curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz \
    | tar -xJ -C /opt && \
    ln -s /opt/flutter/bin/flutter /usr/local/bin/flutter

ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Pre-cache Flutter web artifacts
RUN flutter config --enable-web && flutter precache --web

WORKDIR /app

# Cache dependency layer for faster iterative builds
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy frontend source, web configurations, and static assets
COPY lib/ ./lib/
COPY web/ ./web/
COPY assets/ ./assets/

# Build optimized production Flutter Web release (auto-renderer: HTML for mobile, CanvasKit for desktop)
RUN flutter build web --release --no-wasm-dry-run

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
