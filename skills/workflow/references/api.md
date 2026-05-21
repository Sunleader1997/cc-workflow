# Workflow API Reference

Base URL: `${WORKFLOW_API_URL:-https://sunleader.top:9888}`

## Endpoints

### Health

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/health` | Service health check |

### Workflow CRUD

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/workflows` | Create workflow |
| GET | `/api/workflows` | List all workflows |
| GET | `/api/workflows/:id` | Get workflow by ID |
| PUT | `/api/workflows/:id` | Update workflow |
| DELETE | `/api/workflows/:id` | Delete workflow |

### Workflow Actions

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/workflows/:id/save` | Save user edits (before confirm) |
| POST | `/api/workflows/:id/confirm` | User confirms workflow |
| POST | `/api/workflows/:id/start` | Start execution (resets nodes) |

### Node Operations

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/workflows/:id/next-node` | Get next pending node |
| POST | `/api/workflows/:id/nodes/:nodeId/status` | Update node status |

### SSE Events

| Path | Scope |
|------|-------|
| GET | `/api/workflows/:id/events` | Per-workflow events |
| GET | `/api/events` | All workflow events |

---

## Request/Response Examples

### Create Workflow

```http
POST /api/workflows
Content-Type: application/json

{
  "title": "Build REST API",
  "description": "FastAPI with auth and tests",
  "nodes": [
    {
      "id": "n1",
      "type": "workflow",
      "position": {"x": 250, "y": 50},
      "data": {
        "label": "Step 1: Setup",
        "description": "Initialize project",
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

### Get Next Node

```http
GET /api/workflows/:id/next-node
```

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

### Update Node Status

```http
POST /api/workflows/:id/nodes/:nodeId/status
Content-Type: application/json

{
  "status": "in_progress",
  "detail": "Working on this step..."
}
```

---

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

### Workflow Status

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

### Node Status

| Status | Meaning |
|--------|---------|
| `pending` | Not started |
| `in_progress` | Currently executing |
| `completed` | Successfully done |
| `failed` | Error occurred |
| `skipped` | Intentionally skipped |

### Edge

```json
{
  "id": "e1",
  "source": "n1",
  "target": "n2",
  "animated": true
}
```

---

## SSE Events

### Event Types

| Event | Trigger | Data |
|-------|---------|------|
| `workflow_created` | POST /workflows | Full workflow |
| `workflow_saved` | POST /workflows/:id/save | Full workflow |
| `workflow_confirmed` | POST /workflows/:id/confirm | Full workflow |
| `workflow_started` | POST /workflows/:id/start | Full workflow |
| `workflow_updated` | PUT /workflows/:id | Full workflow |
| `node_status_changed` | POST /.../nodes/:id/status | `{workflow_id, node_id, status, detail, workflow_status}` |

### Example

```javascript
const es = new EventSource('/api/workflows/abc123/events')

es.addEventListener('node_status_changed', (e) => {
  const data = JSON.parse(e.data)
  console.log(`Node ${data.node_id}: ${data.status}`)
})
```
