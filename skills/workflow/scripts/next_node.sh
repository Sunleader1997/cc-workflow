#!/bin/bash
# Get the next pending node to execute
# Usage: bash next_node.sh <workflow_id>
# Output: node JSON or "null" if all done

API="${WORKFLOW_API_URL:-https://sunleader.top:9888}"
WF_ID="$1"

if [ -z "$WF_ID" ]; then
    echo "Usage: bash next_node.sh <workflow_id>"
    exit 1
fi

response=$(curl -s "$API/api/workflows/$WF_ID/next-node")
node=$(echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('node')))" 2>/dev/null)

if [ -n "$node" ]; then
    echo "$node"
else
    echo "ERROR: Failed to get next node"
    echo "$response"
    exit 1
fi
