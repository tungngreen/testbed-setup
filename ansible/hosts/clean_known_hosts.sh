#!/bin/bash

# =============================================================================
# SCRIPT: clean_known_hosts.sh
# DESCRIPTION: Reads /etc/hosts to find all user-defined entries and removes 
#              those corresponding host keys from the current user's ~/.ssh/known_hosts file.
# USAGE: Run this script on the machine where the 'Host key verification failed' error occurs.
# =============================================================================

KNOWN_HOSTS_FILE="$HOME/.ssh/known_hosts"

if [ ! -f "$KNOWN_HOSTS_FILE" ]; then
    echo "Known hosts file not found at $KNOWN_HOSTS_FILE."
    echo "Creating it now."
    mkdir -p "$(dirname "$KNOWN_HOSTS_FILE")"
    touch "$KNOWN_HOSTS_FILE"
    chmod 600 "$KNOWN_HOSTS_FILE"
fi

echo "--- Starting Host Key Cleanup ---"

# Extract hostnames and IPs from /etc/hosts, ignoring loopback and comments.
# This filters out IPv4 entries that don't look like standard IPs and cleans the output.
HOSTS_LIST=$(
    grep -v '^#' /etc/hosts | 
    grep -E '([0-9]{1,3}\.){3}[0-9]{1,3}' | 
    awk '{ for (i=2; i<=NF; i++) { print $i } }' | 
    sort -u | 
    grep -v 'localhost' |
    grep -v 'ip6-localnet'
)

if [ -z "$HOSTS_LIST" ]; then
    echo "No non-loopback entries found in /etc/hosts to clean."
    exit 0
fi

CLEANUP_COUNT=0
for HOST_OR_IP in $HOSTS_LIST; do
    echo "Attempting to remove key for: $HOST_OR_IP"
    
    # Run the key removal command.
    # We redirect stderr to /dev/null to hide the 'not found' message, 
    # but still show the standard output if a key IS removed.
    ssh-keygen -f "$KNOWN_HOSTS_FILE" -R "$HOST_OR_IP" 2> /dev/null
    
    # Check the return code. If ssh-keygen -R finds and removes a key, it exits with 0. 
    # If it fails to find the file or key, it exits with a non-zero code.
    if [ $? -eq 0 ]; then
        echo "--> SUCCESS: Key removed for $HOST_OR_IP."
        CLEANUP_COUNT=$((CLEANUP_COUNT + 1))
    fi
done

echo "--- Cleanup Complete ---"
echo "Total keys removed: $CLEANUP_COUNT"