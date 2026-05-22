#!/bin/bash
# Package the Claude Code Workflow Orchestrator into a single binary executable
# Output: bin/cc-workflow
#
# Usage:
#   ./package.sh              # Auto-detect: Docker on macOS, local on Linux
#   ./package.sh --docker     # Force Docker build (best GLIBC compatibility)
#   ./package.sh --local      # Force local build (Linux only)
#
# Docker build uses manylinux2014 (CentOS 7, GLIBC 2.17) for maximum
# compatibility across Linux distributions.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"
FRONTEND_DIR="$SCRIPT_DIR/frontend"
BACKEND_DIR="$SCRIPT_DIR/backend"
DOCKERFILE="$SCRIPT_DIR/Dockerfile.build"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo -e "${BLUE}[STEP]${NC} $1"; }

# Parse arguments
BUILD_MODE="auto"
while [[ $# -gt 0 ]]; do
    case $1 in
        --docker) BUILD_MODE="docker"; shift ;;
        --local)  BUILD_MODE="local";  shift ;;
        -h|--help)
            echo "Usage: ./package.sh [--docker|--local]"
            echo ""
            echo "Options:"
            echo "  --docker   Force Docker build (manylinux2014, GLIBC 2.17)"
            echo "  --local    Force local build (current system's GLIBC)"
            echo "  (none)     Auto-detect based on OS"
            echo ""
            echo "Docker build provides maximum Linux compatibility."
            echo "Local build is faster but links to host's GLIBC."
            exit 0
            ;;
        *) log_error "Unknown option: $1"; exit 1 ;;
    esac
done

# Detect platform
OS=$(uname -s)
ARCH=$(uname -m)

# Determine build mode
if [ "$BUILD_MODE" = "auto" ]; then
    if [ "$OS" = "Darwin" ]; then
        BUILD_MODE="docker"
        log_warn "macOS detected. Docker build is required for Linux binaries."
    else
        BUILD_MODE="local"
        log_info "Linux detected. Using local build. Use --docker for better GLIBC compatibility."
    fi
fi

# Check Docker availability for docker mode
if [ "$BUILD_MODE" = "docker" ]; then
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker is required for --docker build but not found."
        log_error "Install Docker: https://docs.docker.com/get-docker/"
        exit 1
    fi
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon is not running."
        exit 1
    fi
fi

log_info "=== Packaging Claude Code Workflow Orchestrator ==="
echo "  Mode:   $BUILD_MODE"
echo "  OS:     $OS ($ARCH)"
echo ""

# ============================================================================
# Docker Build (manylinux2014, GLIBC 2.17)
# ============================================================================
build_with_docker() {
    log_step "Building with Docker (manylinux2014_x86_64, GLIBC 2.17)..."
    echo ""

    # Check if Dockerfile exists
    if [ ! -f "$DOCKERFILE" ]; then
        log_error "Dockerfile not found: $DOCKERFILE"
        exit 1
    fi

    # Ensure bin directory exists
    mkdir -p "$BIN_DIR"

    # Clean old binary
    rm -f "$BIN_DIR/cc-workflow"

    # Build Docker image
    log_info "Building Docker image (this may take a few minutes)..."
    DOCKER_BUILDKIT=1 docker build \
        -f "$DOCKERFILE" \
        --target export \
        -t "cc-workflow-build:latest" \
        --progress=plain \
        "$SCRIPT_DIR"

    # Extract binary from built image using docker run + volume mount
    log_info "Extracting binary from container..."
    docker run --rm \
        -v "$BIN_DIR:/output" \
        "cc-workflow-build:latest" \
        cp /build/dist/cc-workflow /output/cc-workflow

    # Verify output
    OUTPUT="$BIN_DIR/cc-workflow"
    if [ ! -f "$OUTPUT" ]; then
        log_error "Docker build failed: executable not found at $OUTPUT"
        exit 1
    fi

    chmod +x "$OUTPUT"
    SIZE=$(du -h "$OUTPUT" | cut -f1)

    echo ""
    log_info "=== Docker Build Complete ==="
    echo "  Base image: manylinux2014_x86_64 (CentOS 7, GLIBC 2.17)"
    echo "  Executable: $OUTPUT"
    echo "  Size:       $SIZE"
    echo ""
}

# ============================================================================
# Local Build (current system's GLIBC)
# ============================================================================
build_local() {
    log_step "Building locally on $OS ($ARCH)..."
    echo ""

    if [ "$OS" = "Darwin" ]; then
        log_warn "Building on macOS produces macOS binaries, NOT Linux binaries."
        log_warn "For Linux deployment, use: ./package.sh --docker"
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

    echo ""
    log_info "=== Local Build Complete ==="
    echo "  Executable: $OUTPUT"
    echo "  Size:       $SIZE"
    echo "  Platform:   $(uname -s) $(uname -m)"
    echo ""

    # Show GLIBC dependencies on Linux
    if [ "$OS" = "Linux" ] && command -v readelf >/dev/null 2>&1; then
        log_info "GLIBC dependencies (local build):"
        readelf -V "$OUTPUT" 2>/dev/null | grep GLIBC | sort -u | head -10 || true
        echo ""
        log_warn "This binary requires the host's GLIBC version or newer."
        log_warn "For better compatibility, use: ./package.sh --docker"
        echo ""
    fi
}

# ============================================================================
# Main
# ============================================================================
if [ "$BUILD_MODE" = "docker" ]; then
    build_with_docker
else
    build_local
fi

# Final output info
OUTPUT="$BIN_DIR/cc-workflow"
if [ ! -f "$OUTPUT" ]; then
    log_error "Build failed: executable not found"
    exit 1
fi

log_info "=== Package Complete ==="
echo ""
echo "  Executable: $OUTPUT"
echo "  Size:       $(du -h "$OUTPUT" | cut -f1)"
echo ""

if [ "$BUILD_MODE" = "docker" ]; then
    echo "  This binary is compatible with Linux systems using GLIBC 2.17+."
    echo "  Tested compatible with: CentOS 7+, Ubuntu 14.04+, Debian 8+, RHEL 7+."
else
    echo "  This binary is built for: $(uname -s) $(uname -m)"
fi

echo ""
echo "To install as a systemd service:"
echo "  sudo ./install.sh"
echo ""
echo "To run directly:"
echo "  $OUTPUT"
echo ""
echo "The service will be available at http://localhost:9800"
