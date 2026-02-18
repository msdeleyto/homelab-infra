output "k8s_vm_names" {
  description = "Name list of the k8s deployed nodes"
  value = [
    for vm in proxmox_vm_qemu.k8s_nodes : vm.name
  ]
}
