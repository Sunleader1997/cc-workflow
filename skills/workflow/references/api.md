# Workflow API Reference

Base URL: `http://localhost:9800`

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

### Confirm Workflow

```
POST /api/workflows/:id/confirm
```

Changes status from `pending_user_confirm` to `confirmed`. Called by the user via the UI.

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

### SSE Events (per workflow)

```
GET /api/workflows/:id/events
```

SSE stream. Event types:
- `workflow_created` — new workflow created
- `workflow_confirmed` — user confirmed
- `workflow_started` — execution started
- `workflow_updated` — workflow modified
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
