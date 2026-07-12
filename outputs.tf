output "environment" {
  description = "Environment resolved from the workspace name."
  value       = local.environment
}

output "resource_group_name" {
  description = "Name of the resource group."
  value       = module.app.resource_group_name
}

output "web_app_name" {
  description = "Name of the deployed Linux Web App."
  value       = module.app.web_app_name
}

output "web_app_url" {
  description = "Default HTTPS endpoint of the web app."
  value       = module.app.web_app_url
}
