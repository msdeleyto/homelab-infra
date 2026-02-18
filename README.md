## Infra

This repository defines the homelab infrastructure and automates its provisioning.

### Servers

```shell
# Create the needed images to auto-install proxmox on bare-metal. For the test environment use terraform to provsion virtual machine(s) locally
ansible-playbook -i inventory/$ENV/hosts.yaml playbooks/pve/image.yaml

# Install the requirements and configure the bare-metal servers to virtualize the cluster
ansible-playbook -i inventory/$ENV/hosts.yaml playbooks/pve/config.yaml
```

### Cluster nodes

```shell
# Use cloud-init and terraform to provision the node virtual machines
ansible-playbook -i inventory/$ENV/hosts.yaml playbooks/cluster/provision.yaml

# Install the requirements and configure the nodes to run k3s. Take a snapshot of the nodes
ansible-playbook -i inventory/$ENV/hosts.yaml playbooks/cluster/config.yaml

# Deploy the cluster's core services
ansible-playbook -i inventory/$ENV/hosts.yaml playbooks/cluster/bootstrap.yaml

# On-demand secrets loading on the cluster secret management tool
ansible-playbook -i inventory/$ENV/hosts.yaml playbooks/cluster/load-secrets.yaml

# Restore the nodes to a stable snapshot before deploying the cluster core services
ansible-playbook -i inventory/$ENV/hosts.yaml playbooks/cluster/restore.yaml
```

`ENV` could be `test` or `prod`.

# Requirements

```
ansible
ansible-lint
passlib
```
