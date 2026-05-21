# Workflow API Reference

Base URL: `${WORKFLOW_API_URL:-https://sunleader.top:9888}` (default: `https://sunleader.top:9888`, override with `WORKFLOW_API_URL` env var)

## Endpoints

### Health Check

```
GET /api/health
```

Response:
```json
{"status": "ok", "workflows": 3}
```

### Create Workflow

```
POST /api/workflows
```

Body:
```json
{
  "title": "Task title",
  "description": "Task description",
  "nodes": [
    {
      "id": "n1",
      "type": "workflow",
      "position": {"x": 250, "y": 50},
      "data": {
        "label": "Step 1: Name",
        "description": "What this step does",
        "status": "pending"
      }
    }
  ],
  "edges": [
    {
      "id": "e1",
      "source": "n1",
      "target": "n2",
      "animated": true
    }
  ]
}
```

Response: Full workflow object with generated `id`.

### List Workflows

```
GET /api/workflows
```

Response: Array of workflow objects.

### Get Workflow

```
GET /api/workflows/:id
```

Response: Single workflow object.

### Update Workflow

```
PUT /api/workflows/:id
```

Body (all fields optional):
```json
{
  "title": "New title",
  "description": "New description",
  "nodes": [...],
  "edges": [...],
  "status": "running"
}
```

### Delete Workflow

```
DELETE /api/workflows/:id
```

Response: `{"ok": true}`

### Save Workflow (user edits)

```
POST /api/workflows/:id/save
```

Same body as `PUT /api/workflows/:id`. Called by the UI when the user saves edits before confirming. Triggers `workflow_saved` SSE event.

### Confirm Workflow

```
POST /api/workflows/:id/confirm
```

Changes status from `pending_user_confirm` to `confirmed`. Called by the user via the UI after reviewing/editing. Triggers `workflow_confirmed` SSE event.

### Start Workflow

```
POST /api/workflows/:id/start
```

Changes status to `running` and resets all node statuses to `pending`. Called by Claude Code before execution. Triggers `workflow_started` SSE event.

### Get Next Pending Node

```
GET /api/workflows/:id/next-node
```

Returns the next node that should be executed, respecting edge topology. A node is "ready" when all its predecessors (nodes with edges pointing to it) are in `completed` or `skipped` state.

Response:
```json
{
  "node": {
    "id": "n2",
    "type": "workflow",
    "position": {"x": 250, "y": 180},
    "data": {
      "label": "Step 2: Models",
      "description": "Create DB models",
      "status": "pending",
      "detail": ""
    }
  },
  "message": "Next node found"
}
```

If all nodes are completed:
```json
{"node": null, "message": "All nodes completed"}
```

### Update Node Status

```
POST /api/workflows/:id/nodes/:nodeId/status
```

Body:
```json
{
  "status": "in_progress",
  "detail": "Working on this step..."
}
```

Status values: `pending`, `in_progress`, `completed`, `failed`, `skipped`

If the node does not exist, returns 404.

### SSE Events (per workflow)

```
GET /api/workflows/:id/events
```

SSE stream. Event types:
- `workflow_created` — new workflow created
- `workflow_saved` — user saved edits
- `workflow_confirmed` — user confirmed
- `workflow_started` — execution started
- `workflow_updated` — workflow modified via PUT
- `node_status_changed` — node status changed

### SSE Events (global)

```
GET /api/events
```

Same as above but for all workflows.

## Data Models

### Workflow

```json
{
  "id": "abc123",
  "title": "Build REST API",
  "description": "FastAPI with auth",
  "nodes": [...],
  "edges": [...],
  "status": "pending_user_confirm",
  "created_at": "2026-05-21T00:00:00Z",
  "updated_at": "2026-05-21T00:00:00Z"
}
```

### Workflow Status Values

| Status | Description |
|--------|-------------|
| `pending_user_confirm` | Created, waiting for user review |
| `confirmed` | User approved |
| `running` | Executing |
| `completed` | All steps done |
| `failed` | One or more steps failed |

### Node

```json
{
  "id": "n1",
  "type": "workflow",
  "position": {"x": 250, "y": 50},
  "data": {
    "label": "Step 1: Setup",
    "description": "Initialize project",
    "status": "pending",
    "detail": ""
  }
}
```

### Edge

```json
{
  "id": "e1",
  "source": "n1",
  "target": "n2",
  "animated": true
}
```
