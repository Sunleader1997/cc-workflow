#!/bin/bash
# Build the Claude Code Workflow Orchestrator for Linux x86_64
# with maximum compatibility across distributions.
#
# Uses Docker to build in an older Linux environment (glibc 2.28),
# ensuring the binary runs on most modern Linux distros.
#
# Usage:
#   ./build-linux.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_IMAGE="${BASE_IMAGE:-rockylinux:8}"

echo "=== Building for Linux x86_64 (compatible) ==="
echo "Base image: $BASE_IMAGE"
echo ""

# Check Docker is available
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is required but not installed."
    exit 1
fi

# Create the PyInstaller spec file
cat > "$SCRIPT_DIR/workflow_orchestrator.spec" << 'SPECFILE'
# -*- mode: python ; coding: utf-8 -*-

block_cipher = None

a = Analysis(
    ['backend/app.py'],
    pathex=[],
    binaries=[],
    datas=[
        ('frontend/dist', 'frontend/dist'),
    ],
    hiddenimports=[
        'uvicorn',
        'uvicorn.logging',
        'uvicorn.loops',
        'uvicorn.loops.auto',
        'uvicorn.protocols',
        'uvicorn.protocols.http',
        'uvicorn.protocols.http.auto',
        'uvicorn.protocols.websockets',
        'uvicorn.protocols.websockets.auto',
        'uvicorn.lifespan',
        'uvicorn.lifespan.on',
        'fastapi',
        'sse_starlette',
        'pydantic',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='workflow-orchestrator',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
SPECFILE

echo "Step 1: Building inside Docker container..."
docker run --rm \
    -v "$SCRIPT_DIR:/build" \
    -w /build \
    "$BASE_IMAGE" \
    bash -c '
        set -e

        # Install system dependencies
        dnf install -y -q python3 python3-pip nodejs npm gcc

        # Install Python dependencies
        pip3 install -q pyinstaller fastapi uvicorn sse-starlette pydantic

        # Build frontend
        echo "  - Building frontend..."
        cd /build/frontend
        npm install --silent
        npm run build

        # Build executable
        echo "  - Building executable with PyInstaller..."
        cd /build
        pyinstaller --clean workflow_orchestrator.spec

        echo "  - Build complete inside container."
    '

echo ""
echo "Step 2: Cleaning up..."
rm -f "$SCRIPT_DIR/workflow_orchestrator.spec"
rm -rf "$SCRIPT_DIR/build/"

echo ""
echo "=== Build Complete ==="
echo ""
echo "Executable: dist/workflow-orchestrator"
echo ""
echo "To run:"
echo "  ./dist/workflow-orchestrator"
echo ""
echo "This binary should work on most Linux x86_64 distributions"
echo "with glibc >= 2.28 (Rocky Linux 8, Ubuntu 20.04+, Debian 10+, etc.)"
echo ""
echo "To target even older systems (glibc 2.17), set BASE_IMAGE:"
echo "  BASE_IMAGE=centos:7 ./build-linux.sh"
