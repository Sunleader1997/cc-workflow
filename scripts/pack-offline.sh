#!/bin/bash
# Pack cc-workflow as an offline-installable npm package
# Pre-downloads Python wheels so the target device doesn't need internet.
#
# IMPORTANT: Wheels are platform-specific. Run this on the SAME platform
# as the target device (same OS + same Python version + same CPU arch).
#
# Usage: bash scripts/pack-offline.sh
# Output: cc-workflow-<version>-offline.tgz

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BACKEND_DIR="$ROOT_DIR/backend"
WHEELS_DIR="$BACKEND_DIR/wheels"

cd "$ROOT_DIR"

# Get version from package.json
VERSION=$(node -p "require('./package.json').version")

# Show platform info
echo "[pack-offline] Building on: $(python3 -c 'import platform; print(platform.platform())')"
echo "[pack-offline] Python version: $(python3 --version)"
echo ""

echo "[pack-offline] Building frontend..."
cd frontend && npm install && npm run build
cd "$ROOT_DIR"

echo "[pack-offline] Downloading Python wheels..."
rm -rf "$WHEELS_DIR"
mkdir -p "$WHEELS_DIR"
pip3 download -r "$BACKEND_DIR/requirements.txt" -d "$WHEELS_DIR" --only-binary=:all:

echo ""
echo "[pack-offline] Downloaded $(ls "$WHEELS_DIR" | wc -l | tr -d ' ') wheel packages:"
ls -1 "$WHEELS_DIR" | sed 's/^/  - /'
echo ""

echo "[pack-offline] Creating offline package..."
npm pack

# Rename to indicate offline capability
mv "cc-workflow-$VERSION.tgz" "cc-workflow-$VERSION-offline.tgz"

SIZE=$(ls -lh "cc-workflow-$VERSION-offline.tgz" | awk '{print $5}')
echo ""
echo "[pack-offline] Done: cc-workflow-$VERSION-offline.tgz ($SIZE)"
echo ""
echo "Install on offline device:"
echo "  1. Install Node.js 18+ and Python 3.10+ on target device"
echo "  2. npm install -g cc-workflow-$VERSION-offline.tgz"
echo "  3. cc-workflow"
echo ""

# Clean up wheels so they don't pollute normal publishes
rm -rf "$WHEELS_DIR"
