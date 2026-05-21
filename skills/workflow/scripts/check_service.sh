#!/bin/bash
# Check if the workflow service is running
# Usage: bash check_service.sh

API="http://localhost:9800"

response=$(curl -s -o /dev/null -w "%{http_code}" "$API/api/health" 2>/dev/null)

if [ "$response" = "200" ]; then
    echo "OK: Workflow service is running at $API"
    exit 0
else
    echo "ERROR: Workflow service is not responding at $API (HTTP $response)"
    echo "Start it with: ./start.sh"
    exit 1
fi
