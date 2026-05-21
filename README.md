# Claude Code Workflow Orchestrator

A Vue Flow-based workflow visualization system for Claude Code. When Claude Code starts a task, it automatically creates a visual workflow, waits for user confirmation, then shows real-time progress as each step executes.

## Features

- **Auto Orchestration**: Claude Code automatically plans task steps as a workflow graph
- **Visual Editor**: Review and modify workflows using Vue Flow drag-and-drop interface
- **User Confirmation**: Approve or adjust the workflow before execution begins
- **Real-time Progress**: Node status updates instantly via SSE (pending → in_progress → completed)
- **Dark Theme**: Catppuccin-inspired UI with animated status indicators

## Architecture

```
┌──────────────┐     HTTP/SSE      ┌──────────────┐     Vue Flow     ┌──────────────┐
│  Claude Code │ ◄──────────────── │   Backend    │ ◄─────────────── │   Frontend   │
│  (Skill)     │   curl commands   │  (FastAPI)   │   SSE stream     │  (Vue 3)     │
└──────────────┘                   └──────────────┘                  └──────────────┘
     Port 9800                          Port 5173
```

## Prerequisites

- Python 3.9+
- Node.js 18+
- npm
- Claude Code CLI

## Installation

### 1. Clone or download the project

```bash
cd /path/to/cc_work
```

### 2. Install backend dependencies

```bash
cd backend
pip3 install -r requirements.txt
```

### 3. Install frontend dependencies

```bash
cd ../frontend
npm install
```

## Starting the Services

### Option A: One-command start (recommended)

```bash
./start.sh
```

This starts both backend (port 9800) and frontend (port 5173) automatically.

### Option B: Start manually

**Terminal 1 - Backend:**
```bash
cd backend
python3 app.py
```

**Terminal 2 - Frontend:**
```bash
cd frontend
npx vite --host
```

### Verify services are running

```bash
# Check backend
curl http://localhost:9800/api/health

# Open frontend in browser
open http://localhost:5173
```

## Installing the Skill

The skill file is located at `.claude/skills/workflow.md`. Claude Code automatically discovers skills in the `.claude/skills/` directory.

To verify the skill is installed:

```bash
ls -la .claude/skills/workflow.md
```

No additional installation steps are needed - Claude Code will automatically load the skill when it starts in this project directory.

## Using the Skill

### Automatic Usage

When you give Claude Code a multi-step task, it will automatically:

1. **Plan the workflow** - Break the task into logical steps
2. **Create the workflow** - POST the workflow graph to the API
3. **Display on UI** - The workflow appears on http://localhost:5173
4. **Wait for confirmation** - Claude Code polls until you click "Confirm Workflow"
5. **Execute and update** - As each step runs, node status updates in real-time

### Example

```
You: Create a REST API with user authentication, database models, and unit tests

Claude Code:
  [Creates workflow with 4 nodes]
  → Step 1: Design database schema
  → Step 2: Create API routes
  → Step 3: Implement authentication
  → Step 4: Write unit tests

  [Waits for your confirmation on the UI]

  [After confirmation, executes each step with real-time updates]
```

### Manual Skill Invocation

You can explicitly ask Claude Code to use the workflow skill:

```
Use the workflow skill to plan and execute: "Build a todo app with React and FastAPI"
```

### Workflow Lifecycle

| Status | Description |
|--------|-------------|
| `pending_user_confirm` | Workflow created, waiting for user review |
| `confirmed` | User approved, ready to execute |
| `running` | Claude Code is executing steps |
| `completed` | All steps finished successfully |
| `failed` | One or more steps failed |

### Node Status

| Status | Icon | Visual |
|--------|------|--------|
| `pending` | ⏳ | Gray border |
| `in_progress` | ⚡ | Blue border + pulsing glow |
| `completed` | ✅ | Green border |
| `failed` | ❌ | Red border |
| `skipped` | ⏭️ | Dim border |

## Implementation Details

### How Claude Code Waits for User Confirmation

The system uses a **polling pattern** to synchronize Claude Code with the browser UI. Claude Code cannot directly receive callbacks from a web page, so it polls the backend API to detect state changes.

```
Claude Code                    Backend API                  Browser UI
    │                              │                            │
    │  POST /api/workflows         │                            │
    │  (create workflow)           │                            │
    │─────────────────────────────>│                            │
    │                              │  SSE: workflow_created     │
    │                              │───────────────────────────>│
    │                              │                            │
    │                              │         [User reviews workflow]
    │                              │                            │
    │  GET /api/workflows/:id      │                            │
    │  (poll status every 5s)      │                            │
    │─────────────────────────────>│                            │
    │  { status: "pending_..." }   │                            │
    │<─────────────────────────────│                            │
    │                              │                            │
    │  GET /api/workflows/:id      │         POST /confirm      │
    │  (poll again)                │<───────────────────────────│
    │─────────────────────────────>│                            │
    │  { status: "confirmed" }     │  SSE: workflow_confirmed   │
    │<─────────────────────────────│───────────────────────────>│
    │                              │                            │
    │  [Starts executing tasks]    │                            │
```

**Key code (`.claude/skills/workflow.md`):**

```bash
# Claude Code polls this endpoint every 5-10 seconds
curl -s http://localhost:9800/api/workflows/$WF_ID | python3 -c \
  "import sys,json; print(json.load(sys.stdin)['status'])"
```

The polling loop continues until `status` changes from `pending_user_confirm` to `confirmed`. If the user says "just go ahead" in the chat, Claude Code skips polling and proceeds directly.

**Why polling instead of WebSocket?**

Claude Code executes shell commands via the Bash tool — it cannot maintain persistent connections. Polling with `curl` is the simplest and most reliable approach that works within Claude Code's execution model.

---

### How Claude Code Reports Real-time Progress

Progress reporting uses **HTTP POST → Backend → SSE Push**. Claude Code calls the API to update node status, and the backend broadcasts the change to all connected browsers via Server-Sent Events.

```
Claude Code                    Backend API                  Browser UI
    │                              │                            │
    │  [Starts working on node_1]  │                            │
    │                              │                            │
    │  POST /nodes/n1/status       │                            │
    │  { status: "in_progress",    │                            │
    │    detail: "Writing code..." }                           │
    │─────────────────────────────>│                            │
    │                              │  SSE: node_status_changed  │
    │                              │  { node_id: "n1",          │
    │                              │    status: "in_progress" } │
    │                              │───────────────────────────>│
    │                              │                            │
    │                              │    [Node glows blue,       │
    │                              │     shows "Writing code..."]
    │                              │                            │
    │  [Finishes node_1]           │                            │
    │                              │                            │
    │  POST /nodes/n1/status       │                            │
    │  { status: "completed",      │                            │
    │    detail: "Created 5 files" }                           │
    │─────────────────────────────>│                            │
    │                              │  SSE: node_status_changed  │
    │                              │  { node_id: "n1",          │
    │                              │    status: "completed" }   │
    │                              │───────────────────────────>│
    │                              │                            │
    │                              │    [Node turns green,      │
    │                              │     shows checkmark]       │
```

**Key code (`.claude/skills/workflow.md`):**

```bash
# Mark node as in_progress
curl -X POST http://localhost:9800/api/workflows/$WF_ID/nodes/node_1/status \
  -H 'Content-Type: application/json' \
  -d '{"status": "in_progress", "detail": "Analyzing requirements..."}'

# Mark node as completed
curl -X POST http://localhost:9800/api/workflows/$WF_ID/nodes/node_1/status \
  -H 'Content-Type: application/json' \
  -d '{"status": "completed", "detail": "Created 3 files, 150 lines"}'
```

**Backend SSE broadcast (`backend/app.py`):**

```python
async def _broadcast(workflow_id: str, event: str, data: dict):
    msg = {"event": event, "data": data}
    for queue in _subscribers.get(workflow_id, []):
        await queue.put(msg)
```

**Frontend SSE listener (`frontend/src/App.vue`):**

```javascript
es.addEventListener('node_status_changed', (e) => {
  const data = JSON.parse(e.data)
  // Create new array reference to trigger Vue reactivity
  nodes.value = nodes.value.map(n => {
    if (n.id === data.node_id) {
      return { ...n, data: { ...n.data, status: data.status, detail: data.detail } }
    }
    return n
  })
})
```

### Why SSE instead of WebSocket?

- **SSE is unidirectional** — perfect for server-to-client push, which is all we need
- **SSE auto-reconnects** — browsers automatically reconnect if the connection drops
- **Simpler implementation** — no WebSocket handshake, no upgrade protocol
- **HTTP/1.1 compatible** — works through proxies and load balancers without issues

### Data Flow Summary

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Complete Data Flow                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. Claude Code creates workflow                                    │
│     curl POST → Backend stores workflow → SSE pushes to browser     │
│                                                                     │
│  2. User reviews and confirms                                       │
│     Browser POST /confirm → Backend updates status                  │
│     → SSE pushes "confirmed" to browser                             │
│                                                                     │
│  3. Claude Code polls and detects confirmation                      │
│     curl GET → reads status: "confirmed" → starts execution         │
│                                                                     │
│  4. Claude Code updates progress                                    │
│     curl POST /nodes/:id/status → Backend stores status             │
│     → SSE pushes "node_status_changed" to browser                   │
│                                                                     │
│  5. Browser receives SSE and updates Vue Flow                       │
│     EventSource listener → nodes.value = nodes.map(...)             │
│     → Vue reactivity triggers re-render → CSS animations play       │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## API Reference

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/workflows` | Create a workflow |
| `GET` | `/api/workflows` | List all workflows |
| `GET` | `/api/workflows/:id` | Get workflow by ID |
| `PUT` | `/api/workflows/:id` | Update workflow |
| `DELETE` | `/api/workflows/:id` | Delete workflow |
| `POST` | `/api/workflows/:id/confirm` | User confirms workflow |
| `POST` | `/api/workflows/:id/start` | Start execution |
| `POST` | `/api/workflows/:id/nodes/:nodeId/status` | Update node progress |
| `GET` | `/api/workflows/:id/events` | SSE stream for workflow |
| `GET` | `/api/events` | SSE stream for all events |
| `GET` | `/api/health` | Health check |

## Troubleshooting

### SSE not showing updates

- Check browser console (F12) for `[SSE]` logs
- Ensure backend is running: `curl http://localhost:9800/api/health`
- Try connecting directly: set `API = 'http://localhost:9800/api'` in App.vue

### Frontend not loading

- Run `npm install` in the frontend directory
- Check port 5173 is not in use: `lsof -i:5173`

### Backend errors

- Check logs in terminal where `python3 app.py` is running
- Ensure Python dependencies are installed: `pip3 install -r requirements.txt`

## Project Structure

```
cc_work/
├── backend/
│   ├── app.py              # FastAPI server (REST + SSE)
│   ├── models.py           # Pydantic models
│   └── requirements.txt
├── frontend/
│   ├── src/
│   │   ├── App.vue         # Main UI with Vue Flow
│   │   ├── components/
│   │   │   └── WorkflowNode.vue  # Custom node component
│   │   └── main.js
│   ├── index.html
│   ├── package.json
│   └── vite.config.js
├── .claude/skills/
│   └── workflow.md         # Claude Code skill definition
├── CLAUDE.md               # Project context for Claude Code
├── README.md               # This file
└── start.sh                # One-command startup script
```
