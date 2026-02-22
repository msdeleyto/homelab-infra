variable "pm_api_url" {
  description = "Proxmox API URL"
  type = string
}

variable "pm_api_user" {
  description = "Proxmox API user"
  type = string
}

variable "pm_password" {
  description = "Proxmox API password"
  type      = string
  sensitive = true
}

variable "ssh_public_key" {
  description = "SSH public key to communicate with the nodes"
  type = string
}

variable "template_name" {
  description = "Name of the template to use for the VMs"
  type = string
}

variable "ciuser" {
  description = "Cloud-init username"
  type = string
}

variable "vm_list" {
  description = "List of VMs to create"
  type = list(object({
    name          = string
    proxmox_node  = string
    memory        = string
    cores         = string
    os_disk       = string
    longhorn_disk = optional(string, null)
    macaddr       = string
    ipconfig      = string
    startup_order = number
    startup_delay = number
  }))
}
