resource "proxmox_vm_qemu" "k8s_nodes" {
  count       = length(var.vm_list)

  name        = var.vm_list[count.index].name
  target_node = var.vm_list[count.index].proxmox_node
  clone       = var.template_name
  memory      = tonumber(var.vm_list[count.index].memory)
  scsihw      = "virtio-scsi-pci"
  boot        = "order=scsi0"
  agent       = 1
  onboot      = true

  cpu {
    cores   = tonumber(var.vm_list[count.index].cores)
    sockets = 1
  }

  disks {
    scsi {
      scsi0 {
        disk {
          storage = "local-lvm"
          size    = var.vm_list[count.index].disk
        }
      }
    }
    ide {
      ide1 {
        cloudinit {
          storage = "local-lvm"
        }
      }
    }
  }

  network {
    id      = 0
    model   = "virtio"
    bridge  = "vmbr0"
    macaddr = var.vm_list[count.index].macaddr
  }

  ipconfig0 = var.vm_list[count.index].ipconfig

  sshkeys = var.ssh_public_key
  ciuser  = "ubuntu"
}
