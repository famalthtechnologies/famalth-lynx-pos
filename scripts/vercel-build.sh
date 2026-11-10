#!/usr/bin/env bash
# ==============================================================================
# Vercel Custom Build Script for Flutter Web
# Automatically installs Flutter SDK if missing in Vercel build environment
# ==============================================================================
set -e

echo "🚀 Starting Vercel Flutter Web build process..."

# Check if pre-built web artifacts already exist from GitHub Actions
if [ -f "build/web/index.html" ]; then
  echo "✅ Pre-built Flutter web artifacts detected at build/web. Ready for deployment."
  exit 0
fi

# If Flutter is already in PATH
if command -v flutter >/dev/null 2>&1; then
  echo "⚡ Flutter SDK detected in PATH."
  flutter pub get
  flutter build web --release --web-renderer auto
  echo "✅ Flutter Web built successfully!"
  exit 0
fi

# Install Flutter SDK in ephemeral Vercel build environment
echo "📥 Flutter not found in PATH. Fetching lightweight Flutter SDK..."
mkdir -p /tmp/flutter_sdk
git clone --depth 1 -b stable https://github.com/flutter/flutter.git /tmp/flutter_sdk

export PATH="/tmp/flutter_sdk/bin:$PATH"

echo "🎯 Flutter SDK installed at /tmp/flutter_sdk/bin"
flutter doctor -v

echo "📦 Fetching packages..."
flutter pub get

echo "🔨 Compiling Flutter Web..."
flutter build web --release --web-renderer auto

echo "✅ Vercel Flutter Web build completed successfully at build/web!"
