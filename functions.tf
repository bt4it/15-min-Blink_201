# Automation (F13): weekly timer trigger that picks the next 7 days of
# audio. Consumption plan — covered by the monthly free grant at this
# scale. Toggle off with enable_function_app if you'd rather trigger the
# weekly pick manually while the app itself is still being built.
resource "azurerm_service_plan" "functions" {
  count               = var.enable_function_app ? 1 : 0
  name                = "${local.name_prefix}-func-plan"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "Y1"
}

resource "azurerm_linux_function_app" "main" {
  count                      = var.enable_function_app ? 1 : 0
  name                       = "${local.name_prefix}-func"
  resource_group_name        = data.azurerm_resource_group.main.name
  location                   = data.azurerm_resource_group.main.location
  service_plan_id            = azurerm_service_plan.functions[0].id
  storage_account_name       = azurerm_storage_account.main.name
  storage_account_access_key = azurerm_storage_account.main.primary_access_key

  site_config {
    application_stack {
      node_version = "20"
    }
  }

  app_settings = {
    MYSQL_HOST     = azurerm_mysql_flexible_server.main.fqdn
    MYSQL_USER     = var.mysql_admin_username
    MYSQL_PASSWORD = var.mysql_admin_password
    MYSQL_DB       = azurerm_mysql_flexible_database.main.name
  }

  lifecycle {
    ignore_changes = [app_settings["WEBSITE_RUN_FROM_PACKAGE"]]
  }
}
