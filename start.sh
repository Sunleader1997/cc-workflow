#!/bin/bash
# Start the Claude Code Workflow Orchestrator (backend + frontend)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Claude Code Workflow Orchestrator ==="
echo ""

# Kill existing processes on our ports
lsof -ti:9800 | xargs kill -9 2>/dev/null || true
lsof -ti:5173 | xargs kill -9 2>/dev/null || true
sleep 1

# Start backend
echo "Starting backend on port 9800..."
cd "$SCRIPT_DIR/backend"
pip3 install -q -r requirements.txt 2>/dev/null
python3 app.py &
BACKEND_PID=$!
echo "Backend PID: $BACKEND_PID"

# Wait for backend to be ready
sleep 2

# Start frontend
echo "Starting frontend on port 5173..."
cd "$SCRIPT_DIR/frontend"
if [ ! -d "node_modules" ]; then
  echo "Installing frontend dependencies..."
  npm install --silent
fi
npx vite --host &
FRONTEND_PID=$!
echo "Frontend PID: $FRONTEND_PID"

echo ""
echo "=== Services Started ==="
echo "Backend API: http://localhost:9800"
echo "Frontend UI: http://localhost:5173"
echo ""
echo "Open http://localhost:5173 in your browser to see the workflow UI."
echo "Claude Code will use the 'workflow' skill to create and manage workflows."
echo ""
echo "Press Ctrl+C to stop all services."

# Cleanup on exit
trap "kill $BACKEND_PID $FRONTEND_PID 2>/dev/null; exit" INT TERM
wait
