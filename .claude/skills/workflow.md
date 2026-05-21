---
name: workflow
description: >
  Orchestrate and visualize task workflows on Vue Flow.
  Use this skill at the START of any non-trivial task to plan the workflow,
  then update progress as you work through each step.
trigger: >
  When given a multi-step task, complex request, or when the user asks to
  "plan", "orchestrate", or "visualize" a workflow. Also use proactively
  for tasks with 3+ steps.
---

# Workflow Orchestrator Skill

This skill integrates Claude Code with a Vue Flow-based workflow visualization system.

## API Base URL

The workflow API runs at: **http://localhost:9800**

## Step 1: Plan the Workflow

When starting a task, first analyze what needs to be done and break it into clear steps.

## Step 2: Create the Workflow

Use `curl` to create a workflow via the API:

```bash
curl -s -X POST http://localhost:9800/api/workflows \
  -H 'Content-Type: application/json' \
  -d '{
    "title": "<task title>",
    "description": "<task description>",
    "nodes": [
      {
        "id": "node_1",
        "type": "workflow",
        "position": {"x": 250, "y": 50},
        "data": {"label": "Step 1: <name>", "description": "<what this does>", "status": "pending"}
      },
      {
        "id": "node_2",
        "type": "workflow",
        "position": {"x": 250, "y": 180},
        "data": {"label": "Step 2: <name>", "description": "<what this does>", "status": "pending"}
      }
    ],
    "edges": [
      {"id": "e_1_2", "source": "node_1", "target": "node_2", "animated": true}
    ]
  }'
```

Save the returned `id` as `WF_ID`.

### Layout Guidelines

- Space nodes vertically by ~130px (y increments)
- Center horizontally at x=250
- For parallel branches, offset x by ±200
- Use descriptive labels: "Step 1: Setup Database", "Step 2: Create API Routes"
- Keep descriptions concise but informative

## Step 3: Wait for User Confirmation

After creating the workflow, tell the user:

> Workflow created and displayed on the UI. Please review and confirm it at http://localhost:5173.
> The workflow is ready for your review. You can modify nodes and edges on the page, then click "Confirm Workflow" when ready.

Then **wait** for the user to confirm. Check periodically:

```bash
curl -s http://localhost:9800/api/workflows/$WF_ID | python3 -c "import sys,json; print(json.load(sys.stdin)['status'])"
```

Poll every 5-10 seconds until status changes from `pending_user_confirm` to `confirmed`.

## Step 4: Execute and Update Progress

Once confirmed, work through each step and update the node status:

### Mark a node as in_progress:
```bash
curl -s -X POST http://localhost:9800/api/workflows/$WF_ID/nodes/node_1/status \
  -H 'Content-Type: application/json' \
  -d '{"status": "in_progress", "detail": "Currently working on this..."}'
```

### Mark a node as completed:
```bash
curl -s -X POST http://localhost:9800/api/workflows/$WF_ID/nodes/node_1/status \
  -H 'Content-Type: application/json' \
  -d '{"status": "completed", "detail": "Done: created 3 files, 150 lines"}'
```

### Mark a node as failed:
```bash
curl -s -X POST http://localhost:9800/api/workflows/$WF_ID/nodes/node_1/status \
  -H 'Content-Type: application/json' \
  -d '{"status": "failed", "detail": "Error: connection timeout"}'
```

## Status Values

- `pending` - Not started yet
- `in_progress` - Currently being worked on
- `completed` - Successfully finished
- `failed` - Encountered an error
- `skipped` - Intentionally skipped

## Important Rules

1. **Always create the workflow BEFORE starting work** - the user needs to see and approve the plan
2. **Update status in real-time** - mark nodes as in_progress when you start, completed when done
3. **Use detail field** - briefly describe what was done or what failed
4. **Keep the workflow accurate** - if the plan changes during execution, update the workflow via PUT
5. **Don't block on confirmation forever** - if the user says "just go ahead", proceed without waiting
