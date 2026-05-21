# Architecture

## System Overview

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Claude Code   │────▶│   Backend API   │────▶│   Frontend UI   │
│   (Skill)       │     │   (FastAPI)     │     │   (Vue Flow)    │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                       │                       │
        │                       │                       │
        ▼                       ▼                       ▼
   Shell Scripts           SSE Events            Real-time UI
```

## Components

### 1. Skill (`skills/workflow/`)

Claude Code skill that orchestrates tasks using visual workflows.

**Files:**
- `SKILL.md` — Main skill instructions
- `scripts/` — Shell scripts for API interaction
- `references/` — Detailed documentation

**Responsibilities:**
- Create workflows from task plans
- Poll for user confirmation
- Execute steps and report progress
- Handle mid-execution changes

### 2. Backend (`backend/`)

FastAPI server providing REST API and SSE events.

**Files:**
- `app.py` — API endpoints and business logic
- `models.py` — Pydantic data models

**Responsibilities:**
- CRUD operations for workflows
- Node status management
- SSE event broadcasting
- Topology-aware node ordering

### 3. Frontend (`frontend/`)

Vue 3 + Vue Flow interactive graph UI.

**Files:**
- `src/App.vue` — Main application component
- `src/components/WorkflowNode.vue` — Custom node component

**Responsibilities:**
- Visual workflow display
- Node editing (add/remove/modify)
- Real-time status updates via SSE
- User confirmation flow

## Data Flow

### Workflow Creation

```
Claude Code                    Backend                    Frontend
     │                           │                           │
     ├─ POST /workflows ────────▶│                           │
     │                           ├─ Broadcast SSE ──────────▶│
     │                           │                           │
     │◀─ Returns workflow_id ────┤                           │
     │                           │                           │
```

### User Confirmation

```
Claude Code                    Backend                    Frontend
     │                           │                           │
     ├─ GET /workflows/:id ─────▶│                           │
     │◀─ Returns workflow ───────┤                           │
     │                           │                           │
     │  (polling every 5s)       │                           │
     │                           │◀─ POST /confirm ──────────┤
     │                           ├─ Broadcast SSE ──────────▶│
     │                           │                           │
     │◀─ Returns confirmed ──────┤                           │
     │                           │                           │
```

### Step Execution

```
Claude Code                    Backend                    Frontend
     │                           │                           │
     ├─ POST .../nodes/:id/status│                           │
     │   (in_progress)           ├─ Broadcast SSE ──────────▶│
     │                           │                           │
     │  (execute step)           │                           │
     │                           │                           │
     ├─ POST .../nodes/:id/status│                           │
     │   (completed)             ├─ Broadcast SSE ──────────▶│
     │                           │                           │
```

### Dynamic Node Query

```
Claude Code                    Backend                    Frontend
     │                           │                           │
     ├─ GET .../next-node ──────▶│                           │
     │                           │                           │
     │◀─ Returns next pending ───┤                           │
     │   node (or null)          │                           │
     │                           │                           │
     │  (continue loop)          │                           │
     │                           │                           │
```

## Node Execution Order

The `/next-node` endpoint uses topological sorting based on edges:

1. Build adjacency list from edges
2. For each pending node, check if all predecessors are completed/skipped
3. Return first ready node (sorted by y-position for visual consistency)
4. If no node is ready (cycles or missing deps), fallback to first pending

## SSE Event Types

| Event | When | Data |
|-------|------|------|
| `workflow_created` | New workflow | Full workflow |
| `workflow_saved` | User saves edits | Full workflow |
| `workflow_confirmed` | User confirms | Full workflow |
| `workflow_started` | Execution starts | Full workflow |
| `workflow_updated` | PUT request | Full workflow |
| `node_status_changed` | Node status update | `{workflow_id, node_id, status, detail, workflow_status}` |

## File Structure

```
skills/workflow/
├── SKILL.md                    # Main skill instructions
├── install_skill.sh            # Installation script
├── evals/
│   └── evals.json             # Test cases
├── references/
│   ├── api.md                 # API documentation
│   ├── QUICK_START.md         # Quick reference guide
│   └── ARCHITECTURE.md        # This file
└── scripts/
    ├── check_service.sh       # Verify service running
    ├── create_workflow.sh     # Create new workflow
    ├── poll_status.sh         # Wait for confirmation
    ├── get_workflow.sh        # Fetch workflow state
    ├── check_node.sh          # Verify node exists
    ├── next_node.sh           # Get next pending node
    ├── update_node.sh         # Update node status
    └── update_workflow.sh     # Replace nodes/edges
```
