#!/bin/bash
# Create a workflow via the API
# Usage: bash create_workflow.sh "<title>" "<description>" '<nodes_json>' '<edges_json>'
# Output: workflow ID
#
# Example:
#   bash create_workflow.sh "Build API" "REST API with auth" \
#     '[{"id":"n1","type":"workflow","position":{"x":250,"y":50},"data":{"label":"Setup","description":"Initialize","status":"pending"}}]' \
#     '[{"id":"e1","source":"n1","target":"n2","animated":true}]'

set -e

API="${WORKFLOW_API_URL:-https://sunleader.top:9888}"
TITLE="$1"
DESCRIPTION="$2"
NODES="$3"
EDGES="$4"

if [ -z "$TITLE" ] || [ -z "$NODES" ]; then
    echo "Usage: bash create_workflow.sh \"<title>\" \"<description>\" '<nodes_json>' '<edges_json>'"
    echo ""
    echo "Example:"
    echo '  bash create_workflow.sh "Build API" "REST API" '"'"'[{"id":"n1","type":"workflow","position":{"x":250,"y":50},"data":{"label":"Step 1","description":"Init","status":"pending"}}]'"'"' '"'"'[{"id":"e1","source":"n1","target":"n2","animated":true}]'"'"
    exit 1
fi

# Build JSON payload safely
payload=$(python3 -c "
import json, sys
data = {
    'title': sys.argv[1],
    'description': sys.argv[2],
    'nodes': json.loads(sys.argv[3]),
    'edges': json.loads(sys.argv[4]) if sys.argv[4] else []
}
print(json.dumps(data))
" "$TITLE" "$DESCRIPTION" "$NODES" "$EDGES" 2>/dev/null)

if [ -z "$payload" ]; then
    echo "ERROR: Invalid JSON in nodes or edges"
    exit 1
fi

response=$(curl -s -X POST "$API/api/workflows" \
    -H 'Content-Type: application/json' \
    -d "$payload")

wf_id=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null)

if [ -z "$wf_id" ]; then
    echo "ERROR: Failed to create workflow"
    echo "Response: $response"
    exit 1
fi

echo "$wf_id"
