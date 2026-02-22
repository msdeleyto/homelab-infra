resource "proxmox_vm_qemu" "vms" {
  count       = length(var.vm_list)

  name               = var.vm_list[count.index].name
  target_node        = var.vm_list[count.index].proxmox_node
  clone              = var.template_name
  memory             = tonumber(var.vm_list[count.index].memory)
  scsihw             = "virtio-scsi-pci"
  boot               = "order=scsi0"
  agent              = 1
  start_at_node_boot = true

  cpu {
    cores   = tonumber(var.vm_list[count.index].cores)
    sockets = 1
  }

  cicustom = "user=local:snippets/longhorn-format.yml"

  disks {
    scsi {
      scsi0 {
        disk {
          storage  = "local-lvm"
          size     = var.vm_list[count.index].os_disk
          discard  = true
          iothread = true
        }
      }
      dynamic "scsi1" {
        for_each = lookup(var.vm_list[count.index], "longhorn_disk", null) != null ? [1] : []

        content {
          disk {
            storage  = "local-lvm"
            size     = var.vm_list[count.index].longhorn_disk
            discard  = true
            iothread = true
          }
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

  startup_shutdown {
    order         = var.vm_list[count.index].startup_order
    startup_delay = var.vm_list[count.index].startup_delay
  }

  ipconfig0 = var.vm_list[count.index].ipconfig

  sshkeys = var.ssh_public_key
  ciuser  = "ubuntu"
}
