#!/bin/bash
# Poll workflow status until it changes to "confirmed"
# Usage: bash poll_status.sh <workflow_id>
# Output: On confirmation, outputs "CONFIRMED" followed by full workflow JSON
#
# This blocks until the user confirms the workflow on the UI.
# After confirmation, the JSON output contains the latest nodes/edges
# (including any user edits).

set -e

API="${WORKFLOW_API_URL:-https://sunleader.top:9888}"
WF_ID="$1"

if [ -z "$WF_ID" ]; then
    echo "Usage: bash poll_status.sh <workflow_id>"
    exit 1
fi

echo "Waiting for user to confirm workflow $WF_ID..." >&2
echo "Review and confirm on the workflow UI." >&2

while true; do
    response=$(curl -s "$API/api/workflows/$WF_ID")

    if [ -z "$response" ]; then
        echo "ERROR: Cannot reach workflow service at $API" >&2
        exit 1
    fi

    status=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null)

    case "$status" in
        confirmed)
            echo "CONFIRMED" >&2
            echo "$response"
            exit 0
            ;;
        completed|running)
            echo "Status: $status (already started)" >&2
            echo "$response"
            exit 0
            ;;
        failed)
            echo "FAILED: Workflow is in failed state" >&2
            exit 1
            ;;
        "")
            echo "ERROR: Invalid response from service" >&2
            echo "Response: $response" >&2
            exit 1
            ;;
        *)
            # Still waiting
            sleep 5
            ;;
    esac
done
