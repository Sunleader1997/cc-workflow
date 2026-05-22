#!/bin/bash
# Check if a node exists in a workflow and get its current status
# Usage: bash check_node.sh <workflow_id> <node_id>
# Output: node JSON if found, error message if not found (exit 1)
#
# Example:
#   node=$(bash scripts/check_node.sh abc123 n1)
#   status=$(echo "$node" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['status'])")

set -e

API="${WORKFLOW_API_URL:-https://sunleader.top:9888}"
WF_ID="$1"
NODE_ID="$2"

if [ -z "$WF_ID" ] || [ -z "$NODE_ID" ]; then
    echo "Usage: bash check_node.sh <workflow_id> <node_id>"
    exit 1
fi

response=$(curl -s "$API/api/workflows/$WF_ID")

if [ -z "$response" ]; then
    echo "ERROR: Cannot reach workflow service" >&2
    exit 1
fi

node=$(echo "$response" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for n in d.get('nodes', []):
    if n['id'] == '$NODE_ID':
        print(json.dumps(n))
        sys.exit(0)
print('')  # Not found
" 2>/dev/null)

if [ -n "$node" ]; then
    echo "$node"
else
    echo "ERROR: Node $NODE_ID not found in workflow $WF_ID" >&2
    exit 1
fi
