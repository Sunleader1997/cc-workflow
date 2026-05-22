#!/bin/bash
# Package the Claude Code Workflow Orchestrator into a single binary executable
# Output: bin/workflow-orchestrator

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"
FRONTEND_DIR="$SCRIPT_DIR/frontend"
BACKEND_DIR="$SCRIPT_DIR/backend"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

log_info "=== Packaging Claude Code Workflow Orchestrator ==="
echo ""

# Platform check
OS=$(uname -s)
ARCH=$(uname -m)
if [ "$OS" != "Linux" ]; then
    log_warn "Current OS is $OS ($ARCH). For Linux x86_64 deployment, run this script on a Linux machine."
    log_warn "Mac builds are not compatible with Linux due to glibc differences."
    echo ""
fi

# Ensure bin directory exists
mkdir -p "$BIN_DIR"

# Step 1: Build frontend
log_info "Step 1: Building frontend..."
cd "$FRONTEND_DIR"
if [ ! -d "node_modules" ]; then
    log_info "  Installing frontend dependencies..."
    npm install --silent
fi
npm run build
log_info "  Frontend built to frontend/dist/"
echo ""

# Step 2: Install Python dependencies and PyInstaller
log_info "Step 2: Installing Python dependencies..."
cd "$BACKEND_DIR"
pip3 install -q -r requirements.txt 2>/dev/null || pip3 install -q fastapi uvicorn sse-starlette pydantic
pip3 install -q pyinstaller 2>/dev/null
log_info "  Dependencies installed."
echo ""

# Step 3: Create PyInstaller spec file
log_info "Step 3: Creating PyInstaller spec..."
cd "$SCRIPT_DIR"

SPEC_FILE="$SCRIPT_DIR/.workflow-orchestrator.spec"
cat > "$SPEC_FILE" << 'SPECFILE'
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
    name='cc-workflow',
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

log_info "  Spec file created."
echo ""

# Step 4: Run PyInstaller
log_info "Step 4: Building executable with PyInstaller..."
pyinstaller --clean --distpath "$BIN_DIR" --workpath "$SCRIPT_DIR/.build" "$SPEC_FILE"
echo ""

# Step 5: Cleanup intermediate files
log_info "Step 5: Cleaning up intermediate files..."
rm -f "$SPEC_FILE"
rm -rf "$SCRIPT_DIR/.build"
log_info "  Cleanup complete."
echo ""

# Step 6: Verify output
OUTPUT="$BIN_DIR/cc-workflow"
if [ ! -f "$OUTPUT" ]; then
    log_error "Build failed: executable not found at $OUTPUT"
    exit 1
fi

chmod +x "$OUTPUT"
SIZE=$(du -h "$OUTPUT" | cut -f1)

log_info "=== Package Complete ==="
echo ""
echo "  Executable: $OUTPUT"
echo "  Size:       $SIZE"
echo "  Platform:   $(uname -s) $(uname -m)"
echo ""
echo "To install as a systemd service:"
echo "  sudo ./install.sh"
echo ""
echo "To run directly:"
echo "  $OUTPUT"
echo ""
echo "The service will be available at http://localhost:9800"
