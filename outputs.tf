output "public_ip_fqdn" {
  description = "The FQDN of the public IP address."
  value       = azurerm_public_ip.lp_ip.fqdn
}

output "public_ip_loadbalancer" {
  value = azurerm_public_ip.lp_ip.id
  description = "The private IP address of the newly created Azure VM"
}