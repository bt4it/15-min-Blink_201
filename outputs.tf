output "container_app_url" {
  value = "https://${azurerm_container_app.main.ingress[0].fqdn}"
}

output "mysql_host" {
  value = azurerm_mysql_flexible_server.main.fqdn
}

output "storage_account_name" {
  value = azurerm_storage_account.main.name
}

output "function_app_name" {
  value = var.enable_function_app ? azurerm_linux_function_app.main[0].name : null
}

output "front_door_endpoint_hostname" {
  value = var.enable_front_door ? azurerm_cdn_frontdoor_endpoint.main[0].host_name : null
}
