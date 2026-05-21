---
name: workflow
description: >
  Orchestrate and visualize task workflows on a Vue Flow interactive graph.
  Use this skill proactively at the START of any multi-step task (3+ steps) to
  plan the workflow before executing. Also trigger when the user asks to "plan",
  "orchestrate", "visualize", "workflow", "break down", "step by step", or
  "show progress". This skill creates a visual workflow on the UI, waits for
  user approval, then reports real-time progress as each step executes.
---

# Workflow Orchestrator

This skill connects Claude Code to a Vue Flow workflow visualization service.
When you receive a complex task, plan it as a graph of steps, present it to
the user for approval on a visual UI, then execute while streaming progress updates.

## Why use this skill?

Without this skill, you'd just start working silently. With it:
- The user sees your plan before you start (and can adjust it)
- Progress is visible in real-time on a visual graph
- The user knows exactly what you're doing at each moment

## Prerequisites

The workflow service must be running. Check with:

```bash
bash scripts/check_service.sh
```

If the service is not running, tell the user:

> The workflow service is not running. Please start it with `./start.sh` in the project root, then try again.

If the service is unavailable, fall back to executing the task normally without visualization.

## Workflow

### 1. Plan the steps

Analyze the task and break it into 3-8 concrete steps. Each step should be:
- **Specific**: "Create user model with SQLAlchemy" not "Handle database"
- **Atomic**: one clear outcome per step
- **Ordered**: dependencies flow top-to-bottom

### 2. Create the workflow

Use the helper script to create a workflow:

```bash
bash scripts/create_workflow.sh "<title>" "<description>" '<nodes_json>' '<edges_json>'
```

**Example:**

```bash
bash scripts/create_workflow.sh \
  "Build REST API" \
  "FastAPI with auth and tests" \
  '[
    {"id":"n1","type":"workflow","position":{"x":250,"y":50},"data":{"label":"Step 1: Setup","description":"Initialize project","status":"pending"}},
    {"id":"n2","type":"workflow","position":{"x":250,"y":180},"data":{"label":"Step 2: Models","description":"Create DB models","status":"pending"}},
    {"id":"n3","type":"workflow","position":{"x":250,"y":310},"data":{"label":"Step 3: Auth","description":"Implement authentication","status":"pending"}}
  ]' \
  '[
    {"id":"e1","source":"n1","target":"n2","animated":true},
    {"id":"e2","source":"n2","target":"n3","animated":true}
  ]'
```

The script prints the workflow ID. Save it — you need it for all subsequent calls.

**Layout rules:**
- Space nodes 130px apart vertically (y: 50, 180, 310, 440, ...)
- Center horizontally at x=250
- For parallel branches, offset x by ±200
- Edge IDs: `e<source>_<target>` (e.g., `e1_2`)

### 3. Tell the user and wait for confirmation

Say:

> I've created a workflow with N steps. Review it at http://localhost:5173 — you can modify nodes and edges, then click "Confirm Workflow" when ready.

Then poll for confirmation:

```bash
bash scripts/poll_status.sh <workflow_id>
```

This polls every 5 seconds until the status changes to `confirmed`. If the user says "just go ahead" or "skip confirmation" in the chat, stop polling and proceed.

### 4. Execute and report progress

For each step, update the node status before and after:

**Before starting a step:**
```bash
bash scripts/update_node.sh <workflow_id> <node_id> in_progress "<what you are doing>"
```

**After completing a step:**
```bash
bash scripts/update_node.sh <workflow_id> <node_id> completed "<what was accomplished>"
```

**If a step fails:**
```bash
bash scripts/update_node.sh <workflow_id> <node_id> failed "<what went wrong>"
```

**If you need to skip a step:**
```bash
bash scripts/update_node.sh <workflow_id> <node_id> skipped "<why>"
```

### 5. Detail field guidelines

The `detail` field appears below the node on the UI. Keep it:
- **Short**: one line, under 60 characters
- **Informative**: what was done, not what you're about to do
- **Quantitative when possible**: "Created 5 files, 200 lines" beats "Done"

Good examples:
- `"Writing database models..."`
- `"Created 3 API routes with auth"`
- `"Failed: missing dependency 'sqlalchemy'"`
- `"All 12 tests passed in 0.3s"`

### 6. If the plan changes mid-execution

If you discover the plan needs adjustment during execution, update the workflow:

```bash
bash scripts/update_workflow.sh <workflow_id> '<new_nodes_json>' '<new_edges_json>'
```

Tell the user what changed and why.

## Status Values

| Status | Meaning | When to use |
|--------|---------|-------------|
| `pending` | Not started | Default state |
| `in_progress` | Currently working | When you begin a step |
| `completed` | Successfully done | When a step finishes |
| `failed` | Error occurred | When a step fails |
| `skipped` | Intentionally skipped | When a step is unnecessary |

## Troubleshooting

If any script fails, check:
1. Is the backend running? `curl -s http://localhost:9800/api/health`
2. Is the workflow ID valid? `curl -s http://localhost:9800/api/workflows/<id>`
3. Is the node ID correct? Check the workflow response for valid node IDs

For the full API reference, read `references/api.md`.
