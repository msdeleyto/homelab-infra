output "node_names" {
  description = "Name list of the deployed nodes"
  value = [
    for node in proxmox_vm_qemu.nodes : node.name
  ]
}

output "cluster_lb_names" {
  description = "Name list of the deployed cluster load balancers"
  value = [
    for cluster_lb in proxmox_vm_qemu.cluster_lbs : cluster_lb.name
  ]
}
