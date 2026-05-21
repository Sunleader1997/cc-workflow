#!/bin/bash
# Poll workflow status until it changes to "confirmed"
# Usage: bash poll_status.sh <workflow_id>
# This will block until the user confirms the workflow on the UI
# After confirmation, outputs the full workflow JSON so Claude Code
# can read the latest nodes (including any user edits).

API="${WORKFLOW_API_URL:-https://sunleader.top:9888}"
WF_ID="$1"

if [ -z "$WF_ID" ]; then
    echo "Usage: bash poll_status.sh <workflow_id>"
    exit 1
fi

echo "Waiting for user to confirm workflow $WF_ID..."
echo "Review and confirm on the workflow UI."

while true; do
    response=$(curl -s "$API/api/workflows/$WF_ID")
    status=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin)['status'])" 2>/dev/null)

    if [ "$status" = "confirmed" ]; then
        echo "CONFIRMED"
        echo "$response"
        exit 0
    elif [ "$status" = "completed" ] || [ "$status" = "running" ]; then
        echo "Status: $status (already started)"
        echo "$response"
        exit 0
    elif [ "$status" = "failed" ]; then
        echo "FAILED: Workflow is in failed state"
        exit 1
    elif [ -z "$status" ]; then
        echo "ERROR: Cannot reach workflow service"
        exit 1
    fi

    sleep 5
done
