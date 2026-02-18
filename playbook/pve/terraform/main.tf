locals {
  network_dhcp_hosts = [
    for node in var.pve_nodes : {
      mac  = node.mac
      name = node.hostname
      ip   = "${node.host_address}"
    }
  ]
}

resource "libvirt_network" "network" {
  name = "lab-network"

  autostart = true
  domain = {
    name = "lab.lan"
    local_only = "no"
  }
  forward = {
    mode = "nat"
  }
  ips = [{
    address = "${var.network_ip}"
    netmask = "255.255.255.0"
    dhcp = {
      hosts = local.network_dhcp_hosts
    }
  }]
}

# Download Proxmox ISO
resource "libvirt_volume" "pve_iso" {
  count = length(var.pve_nodes)

  name = "proxmox-ve-${var.pve_nodes[count.index].hostname}.iso"
  pool = "default"

  create = {
    content = {
      url = "${var.pve_iso_path}/pve_${var.pve_nodes[count.index].hostname}_auto.iso"
    }
  }
}

# Create main disk for Proxmox
resource "libvirt_volume" "pve_disk" {
  count = length(var.pve_nodes)

  name     = "${var.pve_nodes[count.index].hostname}-disk.qcow2"
  pool     = "default"
  capacity = tonumber(var.pve_nodes[count.index].disk) * 1024 * 1024 * 1024
  target = {
    format = {
      type = "qcow2"
    }
  }
}

# Proxmox VM Domain
resource "libvirt_domain" "pve_nodes" {
  count = length(var.pve_nodes)

  name        = var.pve_nodes[count.index].hostname
  memory      = tonumber(var.pve_nodes[count.index].memory)
  memory_unit = "MiB"
  vcpu        = tonumber(var.pve_nodes[count.index].vcpu)
  type        = "kvm"
  running     = true

  # Enable nested virtualization
  cpu = {
    mode = "host-passthrough"
  }

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"
    boot_devices = [
      { dev = "cdrom" },
      { dev = "hd" }
    ]
  }

  devices = {
    disks = [
      # Proxmox installer ISO
      {
        device = "cdrom"
        source = {
          volume = {
            pool   = libvirt_volume.pve_iso[count.index].pool
            volume = libvirt_volume.pve_iso[count.index].name
          }
        }
        target = {
          bus = "sata"
          dev = "sda"
        }
      },
      # Main disk
      {
        source = {
          volume = {
            pool   = libvirt_volume.pve_disk[count.index].pool
            volume = libvirt_volume.pve_disk[count.index].name
          }
        }
        target = {
          bus = "virtio"
          dev = "vda"
        }
        driver = {
          type = "qcow2"
        }
      }
    ]

    interfaces = [
      {
        type = "network"
        model = {
          type = "virtio"
        }
        source = {
          network = {
            network = libvirt_network.network.name
          }
        }
        mac = {
          address = var.pve_nodes[count.index].mac
        }
      }
    ]

    graphics = [
      {
        vnc = {
          auto_port = true
          listen    = "127.0.0.1"
        }
      }
    ]
  }
}

resource "null_resource" "manage_boot" {
  count = length(var.pve_nodes)

  depends_on = [libvirt_domain.pve_nodes]

  # Eject CD after some time
  provisioner "local-exec" {
    command = <<-EOT
      # Wait for auto-install to complete (Proxmox auto-install is usually fast)
      # Adjust this time based on your installation speed
      sleep 240  # 4 minutes
      
      # Eject the CD-ROM so it boots from disk on next reboot
      virsh change-media ${var.pve_nodes[count.index].hostname} sda --eject --config || true
    EOT
  }

  triggers = {
    domain_id = libvirt_domain.pve_nodes[count.index].id
  }
}
