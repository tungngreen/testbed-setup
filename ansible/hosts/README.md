# Host id and access
Works fine in a lab environment but may not be necessary or even efficient for a product one.

```
│   ├── add_host_to_hosts_file.sh               # modifies the /etc/hosts based on the entries in `inventory/host`
│   ├── edit_host_name.yml
│   ├── populate_known_hosts.sh                 # Populate the known_hosts file with identities to avoid issue at first contact
│   ├── populate_jetson_ssh_keys.yml
│   └── populate_server_ssh_keys.yml            # Populate the master key into minion devices and servers.
```