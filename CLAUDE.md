# Claude Code Workflow Orchestrator

## Project Overview

A Vue Flow-based workflow orchestration system for Claude Code.
When Claude Code starts a task, it creates a visual workflow, waits for user confirmation,
then shows real-time progress as each step is executed.

## Architecture

- **Backend** (`backend/`): FastAPI server on port 9800 with REST API + SSE
- **Frontend** (`frontend/`): Vue 3 + Vue Flow on port 5173
- **Skill** (`.claude/skills/workflow.md`): Claude Code skill for workflow orchestration

## Quick Start

```bash
./start.sh
```

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | /api/workflows | Create a workflow |
| GET | /api/workflows | List all workflows |
| GET | /api/workflows/:id | Get workflow by ID |
| PUT | /api/workflows/:id | Update workflow |
| DELETE | /api/workflows/:id | Delete workflow |
| POST | /api/workflows/:id/confirm | User confirms workflow |
| POST | /api/workflows/:id/start | Start execution |
| POST | /api/workflows/:id/nodes/:nodeId/status | Update node progress |
| GET | /api/workflows/:id/events | SSE stream for workflow |
| GET | /api/events | SSE stream for all events |

## Workflow Lifecycle

1. Claude Code creates a workflow with planned steps (status: pending_user_confirm)
2. User reviews and optionally modifies the workflow on the UI
3. User clicks "Confirm Workflow" (status: confirmed)
4. Claude Code executes steps, updating node status in real-time
5. All nodes complete → workflow status becomes "completed"

## Node Status Values

- `pending` - Not started
- `in_progress` - Currently executing
- `completed` - Successfully done
- `failed` - Error occurred
- `skipped` - Intentionally skipped
