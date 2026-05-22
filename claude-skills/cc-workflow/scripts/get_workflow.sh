#!/bin/bash
# Get the full workflow details (nodes, edges, status)
# Usage: bash get_workflow.sh <workflow_id>
# Output: JSON of the workflow
#
# Example:
#   workflow=$(bash scripts/get_workflow.sh abc123)
#   status=$(echo "$workflow" | python3 -c "import sys,json; print(json.load(sys.stdin)['status'])")

set -e

API="${WORKFLOW_API_URL:-https://sunleader.top:9888}"
WF_ID="$1"

if [ -z "$WF_ID" ]; then
    echo "Usage: bash get_workflow.sh <workflow_id>"
    exit 1
fi

response=$(curl -s "$API/api/workflows/$WF_ID")

if [ -z "$response" ]; then
    echo "ERROR: Cannot reach workflow service" >&2
    exit 1
fi

status=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null)

if [ -n "$status" ]; then
    echo "$response"
else
    echo "ERROR: Invalid response from service" >&2
    echo "Response: $response" >&2
    exit 1
fi
