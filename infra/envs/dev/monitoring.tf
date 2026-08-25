# Observability (F6/F7) — 7 day retention keeps this nearly free.
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${local.name_prefix}-log"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 7
}
