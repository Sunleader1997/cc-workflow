#!/bin/bash
# Update a node's status in a workflow
# Usage: bash update_node.sh <workflow_id> <node_id> <status> "<detail>"
# Status: pending | in_progress | completed | failed | skipped
#
# Example:
#   bash scripts/update_node.sh abc123 n1 in_progress "Working on setup..."
#   bash scripts/update_node.sh abc123 n1 completed "Setup done!"

set -e

API="${WORKFLOW_API_URL:-https://sunleader.top:9888}"
WF_ID="$1"
NODE_ID="$2"
STATUS="$3"
DETAIL="$4"

if [ -z "$WF_ID" ] || [ -z "$NODE_ID" ] || [ -z "$STATUS" ]; then
    echo "Usage: bash update_node.sh <workflow_id> <node_id> <status> \"<detail>\""
    echo "Status values: pending | in_progress | completed | failed | skipped"
    exit 1
fi

# Validate status
case "$STATUS" in
    pending|in_progress|completed|failed|skipped) ;;
    *)
        echo "ERROR: Invalid status '$STATUS'. Use: pending|in_progress|completed|failed|skipped" >&2
        exit 1
        ;;
esac

response=$(curl -s -X POST "$API/api/workflows/$WF_ID/nodes/$NODE_ID/status" \
    -H 'Content-Type: application/json' \
    -d "{\"status\": \"$STATUS\", \"detail\": \"$DETAIL\"}")

if [ -z "$response" ]; then
    echo "ERROR: Cannot reach workflow service" >&2
    exit 1
fi

node_status=$(echo "$response" | python3 -c "
import sys, json
d = json.load(sys.stdin)
if 'data' in d:
    print(d['data'].get('status',''))
elif 'detail' in d:
    print('ERROR: ' + str(d['detail']))
else:
    print('')
" 2>/dev/null)

if [ "$node_status" = "$STATUS" ]; then
    echo "OK: $NODE_ID -> $STATUS"
elif [[ "$node_status" == ERROR:* ]]; then
    echo "$node_status" >&2
    exit 1
else
    echo "ERROR: Failed to update node $NODE_ID" >&2
    echo "Response: $response" >&2
    exit 1
fi
