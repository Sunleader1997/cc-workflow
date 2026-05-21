#!/bin/bash
# Create a workflow via the API
# Usage: bash create_workflow.sh "<title>" "<description>" '<nodes_json>' '<edges_json>'
# Output: workflow ID

API="http://localhost:9800"
TITLE="$1"
DESCRIPTION="$2"
NODES="$3"
EDGES="$4"

if [ -z "$TITLE" ] || [ -z "$NODES" ]; then
    echo "Usage: bash create_workflow.sh \"<title>\" \"<description>\" '<nodes_json>' '<edges_json>'"
    exit 1
fi

response=$(curl -s -X POST "$API/api/workflows" \
    -H 'Content-Type: application/json' \
    -d "{
        \"title\": \"$TITLE\",
        \"description\": \"$DESCRIPTION\",
        \"nodes\": $NODES,
        \"edges\": $EDGES
    }")

wf_id=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null)

if [ -z "$wf_id" ]; then
    echo "ERROR: Failed to create workflow"
    echo "$response"
    exit 1
fi

echo "$wf_id"
