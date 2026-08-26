output "resource_group_name" {
  value = azurerm_resource_group.dev.name
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.dev.id
}

output "container_app_environment_default_domain" {
  value = azurerm_container_app_environment.dev.default_domain
}

output "placeholder_container_app_url" {
  value = "https://${azurerm_container_app.placeholder.ingress[0].fqdn}"
}

output "audio_storage_account_name" {
  value = azurerm_storage_account.audio.name
}

output "audio_container_name" {
  value = azurerm_storage_container.audio.name
}

output "mysql_fqdn" {
  value     = azurerm_mysql_flexible_server.dev.fqdn
  sensitive = false
}

output "mysql_server_name" {
  value     = azurerm_mysql_flexible_server.dev.name
  sensitive = false
}