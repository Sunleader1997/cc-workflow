# Quick Start Guide

## 1. Setup

```bash
# Verify service is running
bash scripts/check_service.sh

# Override API URL if needed
export WORKFLOW_API_URL="http://localhost:9800"
```

## 2. Create Workflow

```bash
WF_ID=$(bash scripts/create_workflow.sh \
  "My Task" \
  "Task description" \
  '[
    {"id":"n1","type":"workflow","position":{"x":250,"y":50},"data":{"label":"Step 1","description":"First step","status":"pending"}},
    {"id":"n2","type":"workflow","position":{"x":250,"y":180},"data":{"label":"Step 2","description":"Second step","status":"pending"}}
  ]' \
  '[
    {"id":"e1","source":"n1","target":"n2","animated":true}
  ]')

echo "Workflow ID: $WF_ID"
```

## 3. Wait for User Confirmation

```bash
# This blocks until user confirms on UI
workflow_json=$(bash scripts/poll_status.sh "$WF_ID" | tail -n 1)
echo "User confirmed. Workflow: $workflow_json"
```

## 4. Execute Steps

### Option A: Sequential (simple)

```bash
# Extract node IDs from confirmed workflow
node_ids=$(echo "$workflow_json" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(' '.join(n['id'] for n in d['nodes']))
")

# Execute each node
for node_id in $node_ids; do
    # Check if node still exists (user may have deleted)
    if ! bash scripts/check_node.sh "$WF_ID" "$node_id" > /dev/null 2>&1; then
        echo "Node $node_id was deleted, skipping"
        continue
    fi
    
    # Mark in progress
    bash scripts/update_node.sh "$WF_ID" "$node_id" in_progress "Working on step..."
    
    # ... DO YOUR WORK HERE ...
    
    # Mark completed
    bash scripts/update_node.sh "$WF_ID" "$node_id" completed "Step done!"
done
```

### Option B: Dynamic (for live collaboration)

```bash
while true; do
    # Get next pending node (respects edge dependencies)
    node=$(bash scripts/next_node.sh "$WF_ID")
    
    # All done?
    if [ "$node" = "null" ]; then
        echo "All nodes completed!"
        break
    fi
    
    # Extract node ID
    node_id=$(echo "$node" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
    label=$(echo "$node" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['label'])")
    
    echo "Executing: $label"
    
    # Update status
    bash scripts/update_node.sh "$WF_ID" "$node_id" in_progress "Working on $label..."
    
    # ... DO YOUR WORK HERE ...
    
    # Mark done
    bash scripts/update_node.sh "$WF_ID" "$node_id" completed "Done!"
done
```

## 5. Handle Failures

```bash
# If a step fails
bash scripts/update_node.sh "$WF_ID" "$node_id" failed "Error: dependency not found"

# If a step should be skipped
bash scripts/update_node.sh "$WF_ID" "$node_id" skipped "Not applicable for this task"
```

## 6. Update Workflow During Execution

```bash
# Add a new node
bash scripts/update_workflow.sh "$WF_ID" '[
  {"id":"n1","type":"workflow","position":{"x":250,"y":50},"data":{"label":"Step 1","description":"Done","status":"completed"}},
  {"id":"n2","type":"workflow","position":{"x":250,"y":180},"data":{"label":"Step 2","description":"New step","status":"pending"}}
]' '[
  {"id":"e1","source":"n1","target":"n2","animated":true}
]'
```

## Common Patterns

### Extract node info

```bash
# Get all node IDs
echo "$workflow_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print([n['id'] for n in d['nodes']])"

# Get node label
bash scripts/get_workflow.sh "$WF_ID" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for n in d['nodes']:
    if n['id'] == 'n1':
        print(n['data']['label'])
"
```

### Check workflow status

```bash
# Get current status
bash scripts/get_workflow.sh "$WF_ID" | python3 -c "import sys,json; print(json.load(sys.stdin)['status'])"
```

## Layout Rules

- **Vertical spacing**: 130px apart (y: 50, 180, 310, 440, ...)
- **Horizontal center**: x=250
- **Parallel branches**: Offset x by ±200
- **Edge IDs**: `e<source>_<target>` (e.g., `e1_2`)
