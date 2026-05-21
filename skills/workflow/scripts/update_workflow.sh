#!/bin/bash
# Update an existing workflow's nodes and edges
# Usage: bash update_workflow.sh <workflow_id> '<nodes_json>' '<edges_json>'

API="http://localhost:9800"
WF_ID="$1"
NODES="$2"
EDGES="$3"

if [ -z "$WF_ID" ] || [ -z "$NODES" ]; then
    echo "Usage: bash update_workflow.sh <workflow_id> '<nodes_json>' '<edges_json>'"
    exit 1
fi

response=$(curl -s -X PUT "$API/api/workflows/$WF_ID" \
    -H 'Content-Type: application/json' \
    -d "{\"nodes\": $NODES, \"edges\": $EDGES}")

status=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin)['status'])" 2>/dev/null)

if [ -n "$status" ]; then
    echo "OK: Workflow updated (status: $status)"
else
    echo "ERROR: Failed to update workflow"
    echo "$response"
    exit 1
fi
