# Testbed Automation Setup
Some helpful scripts (e.g., Ansible, bash) for my personal setup for a fleet of servers and Jetson devices.
* Installing and configuring Docker, NVIDIA CUDA, cuDNN, and related tools
* Watching a private Docker registry and auto-pulling updated images
* Deploying some of my own scripts (like a preivate Docker CLI emulator)
* Managing host-specific configs and secrets safely with Ansible Vault

```
./ansible:
├── cmake/                # Playbooks for configuring CMake on Jetsons and servers
├── docker/               # Playbooks and scripts for Docker setup and private registry CLI
├── docker-registry-monitor/ # Scripts and setup for monitoring Docker public and private registries
├── fish/                 # Playbooks for configuring fish shell
├── .git/                 # Git repository inside ansible folder (likely for submodule tracking)
├── grpc/                 # Playbooks for setting up gRPC services
├── hosts/                # Scripts and playbooks for managing /etc/hosts and SSH keys
├── inventory/            # Ansible inventory and group_vars for desktops, Jetsons, and servers
├── nvidia/               # Playbooks and installer files for CUDA, cuDNN, and NVIDIA container toolkit
└── settings/             # System settings playbooks, e.g., auto-mount configuration
├── jetson-install.sh             # Jetson setup script
├── jetson-install.yml            # Jetson Ansible playbook
├── server-install.sh             # Server setup script
└── server-install.yml            # Server Ansible playbook
```
