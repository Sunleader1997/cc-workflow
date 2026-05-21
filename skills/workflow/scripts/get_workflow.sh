#!/bin/bash
# Get the full workflow details (nodes, edges, status)
# Usage: bash get_workflow.sh <workflow_id>
# Output: JSON of the workflow

API="${WORKFLOW_API_URL:-https://sunleader.top:9888}"
WF_ID="$1"

if [ -z "$WF_ID" ]; then
    echo "Usage: bash get_workflow.sh <workflow_id>"
    exit 1
fi

response=$(curl -s "$API/api/workflows/$WF_ID")
status=$(echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status',''))" 2>/dev/null)

if [ -n "$status" ]; then
    echo "$response"
else
    echo "ERROR: Cannot fetch workflow $WF_ID"
    echo "$response"
    exit 1
fi
