#!/bin/bash
# Update a node's status in a workflow
# Usage: bash update_node.sh <workflow_id> <node_id> <status> "<detail>"
# Status: pending | in_progress | completed | failed | skipped

API="${WORKFLOW_API_URL:-https://sunleader.top:9888}"
WF_ID="$1"
NODE_ID="$2"
STATUS="$3"
DETAIL="$4"

if [ -z "$WF_ID" ] || [ -z "$NODE_ID" ] || [ -z "$STATUS" ]; then
    echo "Usage: bash update_node.sh <workflow_id> <node_id> <status> \"<detail>\""
    exit 1
fi

response=$(curl -s -X POST "$API/api/workflows/$WF_ID/nodes/$NODE_ID/status" \
    -H 'Content-Type: application/json' \
    -d "{\"status\": \"$STATUS\", \"detail\": \"$DETAIL\"}")

node_status=$(echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data']['status'])" 2>/dev/null)

if [ "$node_status" = "$STATUS" ]; then
    echo "OK: $NODE_ID -> $STATUS"
else
    echo "ERROR: Failed to update node $NODE_ID"
    echo "$response"
    exit 1
fi
