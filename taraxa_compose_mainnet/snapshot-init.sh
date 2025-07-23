#!/bin/sh
set -e

DATA_PATH="/opt/taraxa_data/data"
NETWORK="${NETWORK:-mainnet}"
NODE_TYPE="${NODE_TYPE:-light}"

echo "Snapshot init container starting..."
echo "DB path: $DATA_PATH"
echo "Network: $NETWORK"
echo "Node type: $NODE_TYPE"

# Check if db directory exists and has content
if [ -d "$DATA_PATH" ] && [ "$(ls -A $DATA_PATH 2>/dev/null)" ]; then
    echo "Database directory $DATA_PATH already exists and has content. Skipping snapshot download."
    exit 0
fi

# Install required packages
echo "Installing required packages..."
apk add --no-cache wget pigz curl jq

# Get snapshot URL - either from env var or API
if [ -n "$SNAPSHOT_URL" ]; then
    echo "Using provided snapshot URL: $SNAPSHOT_URL"
else
    echo "Fetching snapshot URL from API..."
    SNAPSHOT_URL=$(curl "https://snapshots.taraxa.io/api?network=$NETWORK" -s | jq -r ".$NODE_TYPE.url")
    
    if [ -z "$SNAPSHOT_URL" ] || [ "$SNAPSHOT_URL" = "null" ]; then
        echo "Failed to fetch snapshot URL from API. Skipping snapshot download."
        exit 0
    fi
    
    echo "Snapshot URL from API: $SNAPSHOT_URL"
fi

echo "Database directory does not exist or is empty. Downloading snapshot from $SNAPSHOT_URL"

# Create directory if it doesn't exist
mkdir -p $DATA_PATH

# Download and extract snapshot on the fly
echo "Downloading and extracting snapshot..."
cd $DATA_PATH
wget -O - "$SNAPSHOT_URL" | pigz -d | tar -xf -

echo "Snapshot extraction completed successfully"

# Verify db directory has content
if [ ! "$(ls -A $DATA_PATH 2>/dev/null)" ]; then
    echo "ERROR: Database directory $DATA_PATH is empty after extraction"
    exit 1
fi

echo "Snapshot initialization completed successfully" 