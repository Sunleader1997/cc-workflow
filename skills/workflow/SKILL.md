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

Visual workflow for Claude Code. Plan → Confirm → Execute with real-time progress.

## Quick Start

```bash
# 1. Check service
bash scripts/check_service.sh

# 2. Create workflow (returns workflow_id)
bash scripts/create_workflow.sh "Title" "Description" '<nodes>' '<edges>'

# 3. Wait for user to edit & confirm on UI
bash scripts/poll_status.sh <workflow_id>  # returns workflow JSON

# 4. Execute loop (repeat for each node)
bash scripts/update_node.sh <workflow_id> <node_id> in_progress "Working..."
# ... do work ...
bash scripts/update_node.sh <workflow_id> <node_id> completed "Done!"
```

## Execution Modes

### Mode 1: Sequential (default)
Use when workflow structure won't change during execution.

```bash
# After poll_status.sh returns, extract node IDs and iterate
workflow_json=$(bash scripts/poll_status.sh <wf_id> | tail -n 1)
node_ids=$(echo "$workflow_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(' '.join(n['id'] for n in d['nodes']))")

for node_id in $node_ids; do
    # Verify node still exists (user may have deleted it)
    bash scripts/check_node.sh <wf_id> "$node_id" || { echo "Skipped (deleted)"; continue; }
    
    bash scripts/update_node.sh <wf_id> "$node_id" in_progress "..."
    # ... execute step ...
    bash scripts/update_node.sh <wf_id> "$node_id> completed "..."
done
```

### Mode 2: Dynamic (for live collaboration)
Use when user may edit workflow during execution.

```bash
while true; do
    # Get next pending node (respects edge dependencies)
    node=$(bash scripts/next_node.sh <wf_id>)
    
    # Check if done
    if [ "$node" = "null" ]; then break; fi
    
    node_id=$(echo "$node" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
    
    bash scripts/update_node.sh <wf_id> "$node_id" in_progress "..."
    # ... execute step ...
    bash scripts/update_node.sh <wf_id> "$node_id" completed "..."
done
```

## Helper Scripts

| Script | Purpose | Returns |
|--------|---------|---------|
| `check_service.sh` | Verify service running | OK/ERROR |
| `create_workflow.sh` | Create workflow | workflow ID |
| `poll_status.sh` | Wait for user confirm | workflow JSON |
| `get_workflow.sh` | Fetch current state | workflow JSON |
| `check_node.sh` | Verify node exists | node JSON / exit 1 |
| `next_node.sh` | Get next pending node | node JSON / "null" |
| `update_node.sh` | Update node status | OK/ERROR |
| `update_workflow.sh` | Replace nodes/edges | OK/ERROR |

## Node Status Values

| Status | Meaning | When to use |
|--------|---------|-------------|
| `pending` | Not started | Default |
| `in_progress` | Working | Begin a step |
| `completed` | Done | Finish a step |
| `failed` | Error | Step failed |
| `skipped` | Skip | Unnecessary step |

## Tips

- **Detail field**: Keep under 60 chars, be specific: `"Created 5 files, 200 lines"` not `"Done"`
- **Layout**: Space nodes 200px horizontally (x: 50, 250, 450...), center at y=200
- **Edge IDs**: Use `e<source>_<target>` format (e.g., `e1_2`)
- **User edits**: Always call `check_node.sh` before updating to handle mid-execution changes

## Prerequisites

Service must be running. Default: `https://sunleader.top:9888`

```bash
export WORKFLOW_API_URL="http://your-server:port"  # Override if needed
bash scripts/check_service.sh  # Verify
```

If service unavailable, fall back to executing without visualization.

## Troubleshooting

```bash
# 1. Check service health
curl -s ${WORKFLOW_API_URL:-https://sunleader.top:9888}/api/health

# 2. Verify workflow exists
curl -s ${WORKFLOW_API_URL:-https://sunleader.top:9888}/api/workflows/<id>

# 3. Check node exists
bash scripts/check_node.sh <workflow_id> <node_id>
```

For full API reference: `references/api.md`
