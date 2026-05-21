#!/bin/bash
# Get the next pending node to execute
# Usage: bash next_node.sh <workflow_id>
# Output: node JSON if available, "null" if all done, error on failure
#
# A node is "ready" when all its predecessors (edges pointing to it)
# are completed or skipped.
#
# Example:
#   node=$(bash scripts/next_node.sh abc123)
#   if [ "$node" = "null" ]; then
#     echo "All done!"
#   else
#     node_id=$(echo "$node" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
#   fi

set -e

API="${WORKFLOW_API_URL:-https://sunleader.top:9888}"
WF_ID="$1"

if [ -z "$WF_ID" ]; then
    echo "Usage: bash next_node.sh <workflow_id>"
    exit 1
fi

response=$(curl -s "$API/api/workflows/$WF_ID/next-node")

if [ -z "$response" ]; then
    echo "ERROR: Cannot reach workflow service" >&2
    exit 1
fi

node=$(echo "$response" | python3 -c "
import sys, json
d = json.load(sys.stdin)
node = d.get('node')
if node is None:
    print('null')
else:
    print(json.dumps(node))
" 2>/dev/null)

if [ -z "$node" ]; then
    echo "ERROR: Invalid response from service" >&2
    echo "Response: $response" >&2
    exit 1
fi

echo "$node"
