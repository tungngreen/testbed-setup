#!/bin/bash

### This script modifies the /etc/hosts file to add or update entries for a given hostname and IP address.

# Check if required arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <ip_address> <hostname>"
    exit 1
fi

IP_ADDRESS="$1"
HOSTNAME="$2"
HOSTS_FILE="/etc/hosts"
TEMP_FILE="/tmp/hosts.tmp.$$" # Use $$ for a unique temporary file name

echo "Processing $HOSTS_FILE for hostname: $HOSTNAME with IP: $IP_ADDRESS"

# --- Safety First: Backup the original hosts file ---
# You might want to add a timestamp to the backup for multiple backups
sudo cp "$HOSTS_FILE" "$HOSTS_FILE.bak_$(date +%Y%m%d_%H%M%S)"
echo "Backed up $HOSTS_FILE to $HOSTS_FILE.bak_..."

# --- Remove existing entries for the hostname ---
# This command uses sed to delete lines containing the exact hostname
# Using '^\s*' to match optional leading whitespace and '\s*$' for trailing whitespace
# Using '-i.bak' in GNU sed modifies the file in place and creates a backup.
# For portability (BSD sed on macOS), it's safer to use redirection with a temp file.

# Check if it's GNU sed (common on Linux) or BSD sed (common on macOS)
if sed --version 2>&1 | grep -q "GNU"; then
  # GNU sed (Linux) - in-place editing is easier
  echo "Using GNU sed for removal..."
  sudo sed -i".tmp_remove_$$" "/^\s*\(.*\s\+\)*${HOSTNAME}\s*$/d" "$HOSTS_FILE"
  # Clean up the intermediate backup created by sed -i
  sudo rm "$HOSTS_FILE".tmp_remove_$$ 2>/dev/null # Use 2>/dev/null to ignore errors if file doesn't exist
else
  # BSD sed (macOS) - requires a temporary file
  echo "Using BSD sed for removal..."
  # Create a temporary file with lines not containing the hostname
  sudo sed "/^\s*\(.*\s\+\)*${HOSTNAME}\s*$/d" "$HOSTS_FILE" > "$TEMP_FILE"
  # Replace the original file with the temporary one
  sudo mv "$TEMP_FILE" "$HOSTS_FILE"
  # Clean up temporary file if mv failed (unlikely but safe)
  if [ -f "$TEMP_FILE" ]; then rm "$TEMP_FILE"; fi
fi

# --- Determine the entry or entries to add ---
ENTRY_TO_ADD=""

# Check if the provided hostname contains "-1"
if echo "$HOSTNAME" | grep -q -- "-1"; then
    echo "Hostname '$HOSTNAME' contains '-1'. Adding structured entry."
    # Extract the part before the first "-"
    # Use 'sed' for extraction
    PART_BEFORE_HYPHEN=$(echo "$HOSTNAME" | sed 's/-.*//')
    ENTRY_TO_ADD="\n# ${PART_BEFORE_HYPHEN}\n${IP_ADDRESS} ${HOSTNAME}"
else
    echo "Hostname '$HOSTNAME' does not contain '-1'. Adding standard entry."
    ENTRY_TO_ADD="${IP_ADDRESS} ${HOSTNAME}"
fi


# --- Add the new entry or entries ---
# Use echo -e to interpret newline characters and tee -a to append with sudo
echo -e "$ENTRY_TO_ADD" | sudo tee -a "$HOSTS_FILE" > /dev/null

echo "Finished processing."
echo "Showing entry for ${HOSTNAME} in $HOSTS_FILE:"
# Use grep to show the added line(s)
grep -B 2 -A 1 "$HOSTNAME" "$HOSTS_FILE" || echo "Entry for ${HOSTNAME} not found after update."

# Final cleanup of temporary file if any remained
if [ -f "$TEMP_FILE" ]; then rm "$TEMP_FILE"; fi