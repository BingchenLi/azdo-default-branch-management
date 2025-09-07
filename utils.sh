#!/bin/bash

# Configuration
ORG_NAME=$(echo $SYSTEM_TEAMFOUNDATIONCOLLECTIONURI | awk -F/ '{print $4}')
PROJECT_NAME="$SYSTEM_TEAMPROJECT"
BASE_URL="https://dev.azure.com/$ORG_NAME"
API_VERSION="api-version=7.1"
SECURITY_NAMESPACE_ID="2e9eb7ed-3c0a-47d4-87c1-0ffdd275fd87"

declare -A permission_bits=(
          ["FORCE_PUSH"]=8
          ["EDIT_POLICIES"]=2048
          ["BYPASS_POLICIES_PULL_REQUESTS"]=32768
          ["BYPASS_POLICIES_PUSHING"]=128
        )

declare -A permission_status=(
          ["FORCE_PUSH"]="Failed"
          ["EDIT_POLICIES"]="Failed"
          ["BYPASS_POLICIES_PULL_REQUESTS"]="Failed"
          ["BYPASS_POLICIES_PUSHING"]="Failed"
        )

convert_to_hex() {
    local name="$1"
    local hex=""
    for ((i=0; i<${#name}; i++)); do
        hex+=$(printf "%02x00" "'${name:$i:1}")
    done
    echo "$hex"
}

# Function to make API requests
make_request() {
    local pat="$1"
    local url="$2"
    local method=${3:-GET}
    local data=${4:-}


    if [ -n "$data" ]; then
        curl --request "$method" --header "Content-Type: application/json" --data "$data" -u ":$pat" "$url"
    else
        curl --request "$method" --header "Content-Type: application/json" -u ":$pat" "$url"
    fi
}

# Get the expected deny bit value for the permission
get_deny_value() {
    local deny_value=0
    for key in "${!permission_bits[@]}"; do
        deny_value=$((deny_value + permission_bits[$key]))
    done
    echo "$deny_value"
}

export -f convert_to_hex
export -f make_request
export -f get_deny_value

