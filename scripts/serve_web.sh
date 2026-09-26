#!/bin/bash
# Serves the Flutter web build locally on port 8080
# Run: bash scripts/serve_web.sh
cd "$(dirname "$0")/.." || exit 1

BUILD_DIR="build/web"

if [ ! -d "$BUILD_DIR" ]; then
  echo "Web build not found. Building first..."
  flutter build web --release
fi

echo ""
echo "╔════════════════════════════════════════════╗"
echo "║  JalRakshak Web App                        ║"
echo "║  Open http://localhost:8080 in your browser ║"
echo "╚════════════════════════════════════════════╝"
echo ""

cd "$BUILD_DIR" && python3 -m http.server 8080
