output "resource_group_name" {
  description = "Name of the resource group."
  value       = azurerm_resource_group.this.name
}

output "web_app_name" {
  description = "Name of the deployed Linux Web App."
  value       = azurerm_linux_web_app.this.name
}

output "web_app_url" {
  description = "Default HTTPS endpoint of the web app."
  value       = "https://${azurerm_linux_web_app.this.default_hostname}"
}
