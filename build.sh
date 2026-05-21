#!/bin/bash
# Build the Claude Code Workflow Orchestrator into a single executable

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Building Claude Code Workflow Orchestrator ==="
echo ""

# Step 1: Build frontend
echo "Step 1: Building frontend..."
cd "$SCRIPT_DIR/frontend"
npm install --silent
npm run build
echo "Frontend built to frontend/dist/"
echo ""

# Step 2: Install PyInstaller
echo "Step 2: Installing PyInstaller..."
pip3 install -q pyinstaller 2>/dev/null
echo "PyInstaller installed."
echo ""

# Step 3: Create PyInstaller spec file
echo "Step 3: Creating PyInstaller spec file..."
cd "$SCRIPT_DIR"
cat > workflow_orchestrator.spec << 'SPECFILE'
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
echo "Spec file created."
echo ""

# Step 4: Run PyInstaller
echo "Step 4: Building executable with PyInstaller..."
pyinstaller --clean workflow_orchestrator.spec
echo ""

# Step 5: Cleanup
echo "Step 5: Cleaning up..."
rm -f workflow_orchestrator.spec
rm -rf build/
echo ""

echo "=== Build Complete ==="
echo ""
echo "Executable: dist/workflow-orchestrator"
echo ""
echo "To run:"
echo "  ./dist/workflow-orchestrator"
echo ""
echo "The service will be available at http://localhost:9800"
echo "Open http://localhost:9800 in your browser to see the workflow UI."
