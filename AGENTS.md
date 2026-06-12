# AGENTS.md — homelab-infra

Ansible + Terraform repo that provisions and manages a self-hosted k3s homelab cluster on Proxmox VE (PVE). No application code — only infra automation.

## Stack

- **Proxmox VE 8.4-1** bare-metal hypervisors → **k3s `v1.35.0+k3s1`** Kubernetes (3 CP + 2 workers in prod)
- **HAProxy + Keepalived** for HA VIP at `192.168.10.80` (prod only — test has no LBs or VIP)
- **Cilium `v0.19.0` CLI** as CNI (no flannel, no kube-proxy, no traefik, no servicelb)
- **Longhorn** distributed block storage (second disk per node; LB VMs have no Longhorn disk)
- **Vault** for secret management; **ArgoCD** GitOps via external `homelab-manifests` repo
- Node VMs run **Ubuntu 24.04 LTS (Noble)** cloud image

## Environment Setup

```bash
# Python version managed by asdf (.tool-versions pins 3.13.3)
asdf install python 3.13.3
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Operator prerequisites for `node/01-provision.yaml`: `~/.ssh/id_ed25519.pub` must exist (injected into VM template and cloud-init). `~/.local/bin` must be in `$PATH` (Cilium CLI installs there).

## Directory Layout

```
inventory/
  prod/   — physical PVE hosts + k3s cluster (192.168.10.x); groups: pves, lbs, cp_nodes, worker_nodes, nodes, vms
  test/   — local libvirt/KVM-based PVE VM + minimal k3s (192.168.122.x); NO lbs group, NO vms group, NO startup_order on hosts
playbook/
  pve/    — Proxmox host provisioning/config/maintenance + libvirt Terraform (test env only)
  node/   — k3s VM provisioning/config/bootstrap/maintenance + Proxmox Terraform
```

Test env: 1 CP (`c01` at .10) + 1 worker (`n01` at .20). Worker is `n01` not `w01`. `start.yaml`/`stop.yaml`/`restore.yaml` reference `groups['lbs']` and `groups['vms']` — these groups don't exist in test inventory, so those playbooks will fail against test.

## Core Commands

All playbooks take `-i inventory/$ENV/hosts.yaml` where `$ENV` is `test` or `prod`. The `env` variable is set automatically from inventory (`group_vars/all/all.yaml`), not passed on the CLI.

### PVE hosts

```bash
ansible-playbook -i inventory/$ENV/hosts.yaml playbook/pve/01-provision.yaml  # build autoinstall ISOs via podman / libvirt VMs (test only)
ansible-playbook -i inventory/$ENV/hosts.yaml playbook/pve/02-config.yaml     # configure PVE, form cluster
ansible-playbook -i inventory/$ENV/hosts.yaml playbook/pve/03-maintenance.yaml # apt dist-upgrade PVE
```

`pve/01-provision.yaml` builds a local **podman** image from `proxmox-auto-installer-docker/` (contains `xorriso` + `proxmox-auto-install-assistant`) and runs it to produce per-host autoinstall ISOs. The Terraform block only runs when `env == 'test'` (libvirt VMs).

### k3s nodes (run in order)

```bash
ansible-playbook -i inventory/$ENV/hosts.yaml playbook/node/01-provision.yaml  # cloud-init template + Terraform VMs
ansible-playbook -i inventory/$ENV/hosts.yaml playbook/node/02-config.yaml     # install k3s + Cilium CNI
ansible-playbook -i inventory/$ENV/hosts.yaml playbook/node/03-bootstrap.yaml  # deploy homelab services
ansible-playbook -i inventory/$ENV/hosts.yaml playbook/node/04-maintenance.yaml # snapshot + apt upgrade + reboot if kernel updated
```

`node/02-config.yaml` installs k3s in order: `c01` first (`--cluster-init`), then other CPs join via VIP, then workers. It also copies cluster certs to `~/.kube/$ENV/` and runs `kubectl config use-context $ENV`, switching the active context.

### On-demand operations

```bash
ansible-playbook -i inventory/$ENV/hosts.yaml playbook/node/start.yaml       # start VMs: lbs→CPs→workers (ordered)
ansible-playbook -i inventory/$ENV/hosts.yaml playbook/node/stop.yaml        # EMERGENCY: hard power-off all VMs (force: true, no drain)
ansible-playbook -i inventory/$ENV/hosts.yaml playbook/node/restore.yaml     # roll back to latest snapshots, then start all VMs simultaneously (no ordering)
ansible-playbook -i inventory/$ENV/hosts.yaml playbook/node/load-secrets.yaml # reload secrets into Vault
```

## Linting / Validation (matches CI)

```bash
source .venv/bin/activate
ansible-lint playbook/**/*.yaml

# Terraform (init required before validate):
cd playbook/pve/terraform  && terraform init && terraform validate
cd playbook/node/terraform && terraform init && terraform validate
```

CI (Terraform 1.13.3) runs `terraform validate` for `pve` only — `node` Terraform has no CI validation. CI cancels in-progress runs on the same branch when a new push arrives.

## Critical Quirks

**`hash_behaviour = merge`** (`ansible.cfg`) — Ansible dicts are merged across inventory levels, not replaced. This is non-default; group_vars stack additively.

**`gathering = explicit`** (`ansible.cfg`) — Facts are NOT auto-gathered. A playbook must set `gather_facts: true` explicitly. The one exception is the "Register worker nodes mac addresses" play in `pve/02-config.yaml` which does so to collect MACs for WoL.

**VM start order matters** — `start.yaml` enforces: LBs first (30s wait) → CPs (60s wait) → workers. `stop.yaml` is a **forced/hard power-off** (`force: true`). `restore.yaml` starts all VMs simultaneously with no ordering — contradicts the start-order requirement.

**Terraform tfvars are ephemeral** — `terraform.tfvars` files are generated from `.j2` templates at play time and are gitignored (`**/*.tfvars`). `.terraform/` dirs and `.lock.hcl` files are also gitignored — `terraform init` always re-downloads providers. Never hand-edit tfvars; edit the templates or inventory instead.

**Terraform workspace = `$env`** — `node/01-provision.yaml` runs Terraform in a workspace named after the environment (`prod` or `test`). State is kept per-workspace.

**`pve` Terraform uses libvirt, not Proxmox** — `playbook/pve/terraform/` provisions KVM VMs for the _test_ PVE environment locally (dmacvicar/libvirt 0.9.2). `playbook/node/terraform/` uses Telmate/proxmox 3.0.2-rc07 against a running PVE.

**External repo — three distinct scripts** — Three playbooks clone `https://github.com/msdeleyto/homelab-manifests.git` to `/tmp/homelab` (cleaned up in `always:` blocks), but call different scripts:
- `node/02-config.yaml` → `/tmp/homelab/network/tooling/bootstrap` (Cilium/CNI)
- `node/03-bootstrap.yaml` → `/tmp/homelab/tooling/bootstrap <path-to-secrets.yaml>` (full cluster bootstrap; secrets file must exist locally)
- `node/load-secrets.yaml` → `/tmp/homelab/vault/tooling/load-secrets {{ cluster.secrets | quote }}` (passes the secrets dict as a quoted argument, not a file path)

**`secrets.yaml` files are gitignored** — `inventory/*/group_vars/all/secrets.yaml` are excluded by `.gitignore` (`**/secrets.yaml`). They must exist locally but are never committed. Do not log or echo their contents (passwords, API tokens, Vault unseal keys, WireGuard keys).

**Nightly cluster shutdown** — `pve/02-config.yaml` installs a cron job at `01:00` that runs `/root/cluster-poweroff` (SSHes to `pve_workers` hosts and calls `poweroff`, then powers off `pve_main`). Other PVE hosts are woken via WoL on `pve_main` reboot (`@reboot` cron). k3s VMs auto-start via `start_at_node_boot = true` in Terraform. Expect the cluster to be down overnight.

**CP nodes are tainted** — `node/02-config.yaml` applies `node-role.kubernetes.io/control-plane:NoSchedule` to all `cp_nodes`. Workloads must tolerate this or they only schedule on workers.

**`pve/02-config.yaml` side effects** — Beyond cluster formation, this playbook also: disables PVE enterprise/Ceph repos and enables the no-subscription repo (required for `apt` to work on fresh installs); installs `prometheus-pve-exporter` as a systemd service (in its own venv at `/opt/prometheus-pve-exporter`) on all PVE hosts.

**Longhorn prereqs** — `node/02-config.yaml` installs `open-iscsi` and `nfs-common` on all nodes and enables `iscsid`. Second disk (`/dev/sdb`) is auto-formatted as ext4 and mounted at `/var/lib/longhorn` via cloud-init snippet (`/var/lib/vz/snippets/longhorn-format.yml`). LB VMs have no `longhorn_disk` defined and get no second disk.

**Snapshot convention** — Snapshots are named `snapshot-{{ hostname }}` (e.g. `snapshot-c01`). Retention is 1; each run deletes the previous snapshot before creating a new one. Applies to all hosts in `groups['vms']`.

## Terraform Providers

| Project | Provider | Version |
|---|---|---|
| `playbook/pve/terraform` | `dmacvicar/libvirt` | 0.9.2 |
| `playbook/node/terraform` | `Telmate/proxmox` | 3.0.2-rc07 |

`pm_tls_insecure = true` is set for the Proxmox provider (self-signed certs).
