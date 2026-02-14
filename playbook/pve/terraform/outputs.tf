output "pve_web_ui" {
  value = [for node in var.pve_nodes : "https://${node.host_address}:8006"]
}
