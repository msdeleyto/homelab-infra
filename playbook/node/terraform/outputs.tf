output "node_names" {
  description = "Name list of the deployed nodes"
  value = [
    for node in proxmox_vm_qemu.nodes : node.name
  ]
}
