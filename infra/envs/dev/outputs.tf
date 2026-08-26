output "resource_group_name" {
  value = azurerm_resource_group.dev.name
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.dev.id
}

output "container_app_environment_default_domain" {
  value = azurerm_container_app_environment.dev.default_domain
}