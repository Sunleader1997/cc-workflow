#!/bin/bash
# Build the Claude Code Workflow Orchestrator for Linux with cross-device compatibility
# Uses Docker to build inside a manylinux container with older glibc

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Building Claude Code Workflow Orchestrator (Linux Compatible) ==="
echo ""

# Step 1: Build frontend
echo "Step 1: Building frontend..."
cd "$SCRIPT_DIR/frontend"
npm install --silent
npm run build
echo "Frontend built to frontend/dist/"
echo ""

# Step 2: Build inside Docker container with manylinux2014 (glibc 2.17)
echo "Step 2: Building executable inside Docker container..."
echo "Using manylinux2014_x86_64 for maximum Linux compatibility..."
echo ""

cd "$SCRIPT_DIR"

# Create a Dockerfile for the build environment
cat > Dockerfile.build << 'DOCKERFILE'
FROM quay.io/pypa/manylinux2014_x86_64

# Install Python dependencies
RUN /opt/python/cp311-cp311/bin/pip install --no-cache-dir \
    pyinstaller \
    fastapi==0.115.12 \
    uvicorn==0.34.2 \
    sse-starlette==2.3.5 \
    pydantic==2.11.3

# Set working directory
WORKDIR /app

# Copy project files (frontend/dist already built on host)
COPY . .

# Build executable with PyInstaller
RUN cd /app && \
    /opt/python/cp311-cp311/bin/pyinstaller --clean --onefile \
    --name workflow-orchestrator \
    --add-data "frontend/dist:frontend/dist" \
    --hidden-import uvicorn \
    --hidden-import uvicorn.logging \
    --hidden-import uvicorn.loops \
    --hidden-import uvicorn.loops.auto \
    --hidden-import uvicorn.protocols \
    --hidden-import uvicorn.protocols.http \
    --hidden-import uvicorn.protocols.http.auto \
    --hidden-import uvicorn.protocols.websockets \
    --hidden-import uvicorn.protocols.websockets.auto \
    --hidden-import uvicorn.lifespan \
    --hidden-import uvicorn.lifespan.on \
    --hidden-import fastapi \
    --hidden-import sse_starlette \
    --hidden-import pydantic \
    backend/app.py

# Copy the built executable to output
RUN cp dist/workflow-orchestrator /app/dist/workflow-orchestrator-linux
DOCKERFILE

# Build the Docker image
echo "Building Docker image..."
docker build -f Dockerfile.build -t workflow-builder .

# Extract the built executable
echo "Extracting built executable..."
mkdir -p "$SCRIPT_DIR/dist"
docker create --name temp-container workflow-builder
docker cp temp-container:/app/dist/workflow-orchestrator-linux "$SCRIPT_DIR/dist/workflow-orchestrator"
docker rm temp-container

# Cleanup
echo "Cleaning up..."
rm -f Dockerfile.build
docker rmi workflow-builder 2>/dev/null || true

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
echo ""
echo "This binary is compatible with Linux x86_64 systems with glibc 2.17+"
echo "(CentOS 7, Ubuntu 16.04+, Debian 8+, etc.)"
