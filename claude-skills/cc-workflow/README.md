# Workflow Orchestrator Skill

Visual workflow orchestration for Claude Code. Plan tasks as interactive graphs, get user approval, then execute with real-time progress.

## Features

- **Visual Planning**: Tasks broken into interactive Vue Flow graph
- **User Collaboration**: Users can add, remove, or edit nodes before confirmation
- **Real-time Updates**: Node status updates via SSE events
- **Dynamic Execution**: Handle mid-execution changes gracefully
- **Multiple Modes**: Sequential or dynamic node execution

## Quick Start

1. **Install skill** (if not already installed):
   ```bash
   bash install_skill.sh
   ```

2. **Verify service running**:
   ```bash
   bash scripts/check_service.sh
   ```

3. **Use in Claude Code**:
   - Just describe a multi-step task
   - Claude Code will automatically use this skill
   - Review and edit the workflow on the UI
   - Click "Confirm" to start execution

## Documentation

| Document | Description |
|----------|-------------|
| [SKILL.md](SKILL.md) | Main skill instructions for Claude Code |
| [QUICK_START.md](references/QUICK_START.md) | Quick reference guide |
| [API Reference](references/api.md) | Full API documentation |
| [Architecture](references/ARCHITECTURE.md) | System design and data flow |

## Scripts

| Script | Purpose |
|--------|---------|
| `check_service.sh` | Verify service is running |
| `create_workflow.sh` | Create new workflow |
| `poll_status.sh` | Wait for user confirmation |
| `get_workflow.sh` | Fetch workflow state |
| `check_node.sh` | Verify node exists |
| `next_node.sh` | Get next pending node |
| `update_node.sh` | Update node status |
| `update_workflow.sh` | Replace nodes/edges |

## Configuration

Default API URL: `https://sunleader.top:9888`

Override with environment variable:
```bash
export WORKFLOW_API_URL="http://your-server:port"
```

## Examples

### Basic Workflow

```bash
# Create workflow
WF_ID=$(bash scripts/create_workflow.sh \
  "Build API" \
  "REST API with auth" \
  '[{"id":"n1","type":"workflow","position":{"x":250,"y":50},"data":{"label":"Setup","description":"Initialize project","status":"pending"}}]' \
  '[{"id":"e1","source":"n1","target":"n2","animated":true}]')

# Wait for confirmation
workflow_json=$(bash scripts/poll_status.sh "$WF_ID" | tail -n 1)

# Execute
bash scripts/update_node.sh "$WF_ID" n1 in_progress "Setting up..."
# ... do work ...
bash scripts/update_node.sh "$WF_ID" n1 completed "Done!"
```

### Dynamic Execution

```bash
while true; do
    node=$(bash scripts/next_node.sh "$WF_ID")
    [ "$node" = "null" ] && break
    
    node_id=$(echo "$node" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
    bash scripts/update_node.sh "$WF_ID" "$node_id" in_progress "Working..."
    # ... execute ...
    bash scripts/update_node.sh "$WF_ID" "$node_id" completed "Done!"
done
```

## Contributing

See [ARCHITECTURE.md](references/ARCHITECTURE.md) for system design details.

## License

Part of the Claude Code Workflow Orchestrator project.
