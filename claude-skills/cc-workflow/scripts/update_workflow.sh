#!/bin/bash
# Update an existing workflow's nodes and edges
# Usage: bash update_workflow.sh <workflow_id> '<nodes_json>' '<edges_json>'
#
# Example:
#   bash scripts/update_workflow.sh abc123 \
#     '[{"id":"n1","type":"workflow","position":{"x":250,"y":50},"data":{"label":"Step 1","description":"Init","status":"completed"}}]' \
#     '[{"id":"e1","source":"n1","target":"n2","animated":true}]'

set -e

API="${WORKFLOW_API_URL:-https://sunleader.top:9888}"
WF_ID="$1"
NODES="$2"
EDGES="$3"

if [ -z "$WF_ID" ] || [ -z "$NODES" ]; then
    echo "Usage: bash update_workflow.sh <workflow_id> '<nodes_json>' '<edges_json>'"
    exit 1
fi

# Build JSON payload safely
payload=$(python3 -c "
import json, sys
data = {}
if sys.argv[2]:
    data['nodes'] = json.loads(sys.argv[2])
if sys.argv[3]:
    data['edges'] = json.loads(sys.argv[3])
print(json.dumps(data))
" "$WF_ID" "$NODES" "$EDGES" 2>/dev/null)

if [ -z "$payload" ]; then
    echo "ERROR: Invalid JSON in nodes or edges" >&2
    exit 1
fi

response=$(curl -s -X PUT "$API/api/workflows/$WF_ID" \
    -H 'Content-Type: application/json' \
    -d "$payload")

if [ -z "$response" ]; then
    echo "ERROR: Cannot reach workflow service" >&2
    exit 1
fi

status=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null)

if [ -n "$status" ]; then
    echo "OK: Workflow updated (status: $status)"
else
    echo "ERROR: Failed to update workflow" >&2
    echo "Response: $response" >&2
    exit 1
fi
