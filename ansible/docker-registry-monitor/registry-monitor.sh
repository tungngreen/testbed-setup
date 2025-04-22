#!/bin/bash

# === Configuration ===
REGISTRY_URL=$1     # Your private registry
IMAGE_LIST_FILE=$2  # Images to check
DOCKER_SCRIPT_PATH=$3      # Your custom docker wrapper
SLACK_WEBHOOK_URL=$4  # Slack webhook URL for notifications

HOSTNAME=$(hostname)

# === Functions ===

# Function: Log an error and exit
error_exit() {
    echo "❌ Error: $1" >&2
    exit 1
}

# Function: Get the timestamp of an image from the registry
get_registry_timestamp() {
    local image="$1"
    local repo="${image%%:*}"   # repository name (before ':')
    local tag="${image##*:}"    # tag (after ':')

    # Directly query the registry manifest (no auth)
    local manifest=$(curl -s -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
        "http://${REGISTRY_URL}/v2/${repo}/manifests/${tag}")

    if [[ -z "$manifest" || "$manifest" == "null" ]]; then
        error_exit "Failed to fetch manifest for $repo:$tag" >&2
    fi

    # Get the config digest
    local config_digest=$(echo "$manifest" | jq -r '.config.digest')

    if [[ -z "$config_digest" || "$config_digest" == "null" ]]; then
        error_exit "Failed to extract config digest from manifest of $repo:$tag" >&2
    fi

    # Fetch config blob
    local config_blob=$(curl -s "http://${REGISTRY_URL}/v2/${repo}/blobs/${config_digest}")

    if [[ -z "$config_blob" || "$config_blob" == "null" ]]; then
        error_exit "Failed to fetch config blob for $repo:$tag" >&2
    fi

    # Extract creation time
    echo "$config_blob" | jq -r '.created'
}


# Function: Get the timestamp from local stored logs
get_local_timestamp() {
    local image="$1"
    local log_file="/var/log/registry_images/${image//\//_}.log"  # Replace '/' with '_'

    if [[ -f "$log_file" ]]; then
        cat "$log_file"
    else
        echo "none"
    fi
}

# Function: Update the local log timestamp
update_local_timestamp() {
    local image="$1"
    local timestamp="$2"
    local log_file="/var/log/registry_images/${image//\//_}.log"

    mkdir -p /var/log/registry_images
    echo "$timestamp" > "$log_file"
}

notify_slack() {
    local message="$1"
    curl -s -X POST -H 'Content-type: application/json' --data "{\"text\":\"$message\"}" "${SLACK_WEBHOOK_URL}" > /dev/null
}

# === Main ===

# Check if required tools exist
for tool in curl jq; do
    if ! command -v "$tool" &>/dev/null; then
        error_exit "Required tool '$tool' is not installed." >&2
    fi
done

# Check if image list file exists
if [[ ! -f "$IMAGE_LIST_FILE" ]]; then
    error_exit "Image list file not found at $IMAGE_LIST_FILE" >&2
fi

# Read images into an array
mapfile -t IMAGES < "$IMAGE_LIST_FILE"

# Loop over images
for IMAGE in "${IMAGES[@]}"; do
    echo "🔍 Checking image: $IMAGE"

    REGISTRY_TIMESTAMP=$(get_registry_timestamp "$IMAGE")
    if [[ -z "$REGISTRY_TIMESTAMP" ]]; then
        echo "⚠️  Could not find registry timestamp for $IMAGE, skipping."
        continue
    fi

    LOCAL_TIMESTAMP=$(get_local_timestamp "$IMAGE")

    if [[ "$LOCAL_TIMESTAMP" == "$REGISTRY_TIMESTAMP" ]]; then
        echo "✅ Up-to-date: $IMAGE"
    else
        echo "⬇️  Newer version found for $IMAGE, pulling..."
        # "$DOCKER_SCRIPT_PATH" pull "$IMAGE"

        # # Update local log timestamp after pulling
        update_local_timestamp "$IMAGE" "$REGISTRY_TIMESTAMP"

        # # Notify via Slack
        notify_slack "[$HOSTNAME] New image pulled: $IMAGE\nRegistry timestamp: $REGISTRY_TIMESTAMP\nLocal timestamp: $LOCAL_TIMESTAMP"
        
    fi
done

echo "✨ Finished checking all images."

exit 0