#!/bin/bash
# populate_known_hosts.sh

# Check if inventory path is provided as an argument
if [ "$1" == "" ]; then
  echo "Error: No inventory file specified!"
  echo "Usage: $0 <path_to_inventory_file>"
  exit 1
fi

INVENTORY_PATH="$1"

# Check if inventory file exists
if [ ! -f "$INVENTORY_PATH" ]; then
  echo "Error: Inventory file '$INVENTORY_PATH' not found!"
  echo "Usage: $0 <path_to_inventory_file>"
  exit 1
fi

echo "Using inventory file: $INVENTORY_PATH"

# Getting hosts from inventory
grep "ansible_host" "$INVENTORY_PATH" | awk -F "ansible_host=" '{print $2}' | awk '{print $1}' | while read host; do
  # Clean up the host (remove any trailing spaces or other characters)
  host=$(echo "$host" | tr -d ' ' | tr -d '\r')
  
  if ! ssh-keygen -F "$host" > /dev/null 2>&1; then
    echo "Adding $host to known_hosts"
    ssh-keyscan -H "$host" >> ~/.ssh/known_hosts 2>/dev/null
  else
    echo "Host $host already in known_hosts, skipping"
  fi
done

echo "Known hosts population complete"
