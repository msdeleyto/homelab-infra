## Infra

This repository defines the homelab infrastructure and automates its provisioning.

### Servers

```shell
# Create the needed images to auto-install proxmox on bare-metal. For the test environment use terraform to provision virtual machine(s) locally
ansible-playbook -i inventory/$ENV/hosts.yaml playbook/pve/01-provision.yaml

# Install the requirements and configure the bare-metal servers to virtualize the cluster
ansible-playbook -i inventory/$ENV/hosts.yaml playbook/pve/02-config.yaml

# Maintain PVE hosts (apt dist-upgrade)
ansible-playbook -i inventory/$ENV/hosts.yaml playbook/pve/03-maintenance.yaml
```

### Cluster nodes

```shell
# Use cloud-init and terraform to provision the node virtual machines
ansible-playbook -i inventory/$ENV/hosts.yaml playbook/node/01-provision.yaml

# Install the requirements and configure the nodes to run k3s. Take a snapshot of the nodes
ansible-playbook -i inventory/$ENV/hosts.yaml playbook/node/02-config.yaml

# Deploy the cluster's core services
ansible-playbook -i inventory/$ENV/hosts.yaml playbook/node/03-bootstrap.yaml

# Snapshot VMs and apt dist-upgrade nodes
ansible-playbook -i inventory/$ENV/hosts.yaml playbook/node/04-maintenance.yaml

# On-demand secrets loading on the cluster secret management tool
ansible-playbook -i inventory/$ENV/hosts.yaml playbook/node/load-secrets.yaml

# Restore the nodes to a stable snapshot before deploying the cluster core services
ansible-playbook -i inventory/$ENV/hosts.yaml playbook/node/restore.yaml

# Start VMs in order: load balancers → control planes → workers
ansible-playbook -i inventory/$ENV/hosts.yaml playbook/node/start.yaml

# Emergency hard power-off all VMs (no drain)
ansible-playbook -i inventory/$ENV/hosts.yaml playbook/node/stop.yaml
```

`ENV` could be `test` or `prod`.

## Requirements

```bash
# Python version managed by asdf (.tool-versions pins 3.13.3)
asdf install python 3.13.3
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Linting

```bash
source .venv/bin/activate
ansible-lint playbook/**/*.yaml

# Terraform (init required before validate):
cd playbook/pve/terraform  && terraform init && terraform validate
cd playbook/node/terraform && terraform init && terraform validate
```
