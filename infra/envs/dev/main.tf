resource "azurerm_resource_group" "dev" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_log_analytics_workspace" "dev" {
  name                = "law-15min-blinket-dev-gwc"
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "dev" {
  name                       = "cae-15min-blinket-dev-gwc"
  location                   = azurerm_resource_group.dev.location
  resource_group_name        = azurerm_resource_group.dev.name
  logs_destination           = "log-analytics"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.dev.id
}