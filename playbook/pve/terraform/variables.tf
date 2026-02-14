variable "pve_iso_path" {
  description = "Path to Proxmox VE ISOs to use for installation"
  type        = string
}

variable "network_ip" {
  description = "IP address for pve nodes network"
  type        = string
}

variable "pve_nodes" {
  description = "Proxmox VE node configuration"
  type = list(object({
    hostname     = string
    memory       = string # MB
    vcpu         = string
    disk         = string # GB
    mac          = string
    host_address = string
  }))
}
