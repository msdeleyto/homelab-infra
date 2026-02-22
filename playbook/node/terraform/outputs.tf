output "vm_names" {
  description = "Name list of the deployed vms"
  value = [
    for vm in proxmox_vm_qemu.vms : vm.name
  ]
}
