---
name: workflow
description: >
  Orchestrate and visualize task workflows on a Vue Flow interactive graph.
  Use this skill proactively at the START of any multi-step task (3+ steps) to
  plan the workflow before executing. Also trigger when the user asks to "plan",
  "orchestrate", "visualize", "workflow", "break down", or "step by step".
  This skill creates a visual workflow on the UI, waits for user approval,
  then reports real-time progress as each step executes.
---

# Workflow Orchestrator

This skill connects Claude Code to a Vue Flow workflow visualization service.
When you receive a complex task, you plan it as a graph of steps, present it to
the user for approval on a visual UI, then execute while streaming progress updates.

## Why use this skill?

Without this skill, you'd just start working on the task silently. With it:
- The user sees your plan before you start (and can adjust it)
- Progress is visible in real-time on a visual graph
- The user knows exactly what you're doing at each moment

## API

The workflow service runs at `http://localhost:9800`. Check it's alive first:

```bash
curl -s http://localhost:9800/api/health
```

If it's not running, tell the user to start it with `./start.sh` in the project root.

## Workflow

### 1. Check the service is available

```bash
curl -s http://localhost:9800/api/health
```

If this fails, tell the user: "The workflow service is not running. Please start it with `./start.sh`." Then fall back to executing the task normally without visualization.

### 2. Plan the steps

Analyze the task and break it into 3-8 concrete steps. Each step should be:
- **Specific**: "Create user model with SQLAlchemy" not "Handle database"
- **Atomic**: one clear outcome per step
- **Ordered**: dependencies flow top-to-bottom

### 3. Create the workflow

POST the workflow to the API. Use short, descriptive node IDs like `n1`, `n2`, etc.

```bash
curl -s -X POST http://localhost:9800/api/workflows \
  -H 'Content-Type: application/json' \
  -d '{
    "title": "<short task title>",
    "description": "<one-line summary>",
    "nodes": [
      {
        "id": "n1",
        "type": "workflow",
        "position": {"x": 250, "y": 50},
        "data": {
          "label": "Step 1: <concise name>",
          "description": "<what this step does>",
          "status": "pending"
        }
      },
      {
        "id": "n2",
        "type": "workflow",
        "position": {"x": 250, "y": 180},
        "data": {
          "label": "Step 2: <concise name>",
          "description": "<what this step does>",
          "status": "pending"
        }
      }
    ],
    "edges": [
      {"id": "e1", "source": "n1", "target": "n2", "animated": true}
    ]
  }'
```

Save the returned `id` — you'll need it for all subsequent calls as `$WF_ID`.

**Layout rules:**
- Space nodes 130px apart vertically (y: 50, 180, 310, 440, ...)
- Center horizontally at x=250
- For parallel branches, offset x by ±200
- Edge IDs: `e<source>_<target>` (e.g., `e1_2`)

### 4. Tell the user and wait for confirmation

Say something like:

> I've created a workflow with N steps. Review it at http://localhost:5173 — you can modify nodes and edges, then click "Confirm Workflow" when ready.

Then poll for confirmation:

```bash
curl -s http://localhost:9800/api/workflows/$WF_ID \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['status'])"
```

Poll every 5-10 seconds. Stop when status becomes `confirmed`.

**Important**: If the user says "just go ahead" or "skip confirmation" in the chat, stop polling and proceed immediately.

### 5. Execute and report progress

For each step, update the node status before and after:

**Before starting a step:**
```bash
curl -s -X POST http://localhost:9800/api/workflows/$WF_ID/nodes/<node_id>/status \
  -H 'Content-Type: application/json' \
  -d '{"status": "in_progress", "detail": "<what you are doing>"}'
```

**After completing a step:**
```bash
curl -s -X POST http://localhost:9800/api/workflows/$WF_ID/nodes/<node_id>/status \
  -H 'Content-Type: application/json' \
  -d '{"status": "completed", "detail": "<what was accomplished>"}'
```

**If a step fails:**
```bash
curl -s -X POST http://localhost:9800/api/workflows/$WF_ID/nodes/<node_id>/status \
  -H 'Content-Type: application/json' \
  -d '{"status": "failed", "detail": "<what went wrong>"}'
```

**If you need to skip a step:**
```bash
curl -s -X POST http://localhost:9800/api/workflows/$WF_ID/nodes/<node_id>/status \
  -H 'Content-Type: application/json' \
  -d '{"status": "skipped", "detail": "<why it was skipped>"}'
```

### 6. Detail field guidelines

The `detail` field appears below the node on the UI. Keep it:
- **Short**: one line, under 60 characters
- **Informative**: what was done, not what you're about to do
- **Quantitative when possible**: "Created 5 files, 200 lines" is better than "Done"

Good examples:
- `"Writing database models..."`
- `"Created 3 API routes with auth"`
- `"Failed: missing dependency 'sqlalchemy'"`
- `"All 12 tests passed in 0.3s"`

### 7. If the plan changes mid-execution

If you discover the plan needs adjustment during execution:
1. Use PUT to update the workflow:

```bash
curl -s -X PUT http://localhost:9800/api/workflows/$WF_ID \
  -H 'Content-Type: application/json' \
  -d '{
    "nodes": [/* updated nodes */],
    "edges": [/* updated edges */]
  }'
```

2. Tell the user what changed and why.

## Status Values

| Status | Meaning | When to use |
|--------|---------|-------------|
| `pending` | Not started | Default state |
| `in_progress` | Currently working | When you begin a step |
| `completed` | Successfully done | When a step finishes |
| `failed` | Error occurred | When a step fails |
| `skipped` | Intentionally skipped | When a step is unnecessary |

## Quick Reference

```bash
# Health check
curl -s http://localhost:9800/api/health

# Create workflow
curl -s -X POST http://localhost:9800/api/workflows -H 'Content-Type: application/json' -d '{...}'

# Get workflow status
curl -s http://localhost:9800/api/workflows/$WF_ID

# Update node status
curl -s -X POST http://localhost:9800/api/workflows/$WF_ID/nodes/$NODE_ID/status \
  -H 'Content-Type: application/json' -d '{"status": "...", "detail": "..."}'

# Update entire workflow (plan change)
curl -s -X PUT http://localhost:9800/api/workflows/$WF_ID \
  -H 'Content-Type: application/json' -d '{...}'
```
