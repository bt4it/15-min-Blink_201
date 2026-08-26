resource "azurerm_container_app_environment" "dev" {
  name                       = "cae-15min-blinket-dev-gwc"
  location                   = azurerm_resource_group.dev.location
  resource_group_name        = azurerm_resource_group.dev.name
  logs_destination           = "log-analytics"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.dev.id

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }

  tags = {
    project     = "15min-blinket"
    environment = "dev"
    managed-by  = "terraform"
  }
}

resource "azurerm_resource_group" "dev" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    project     = "15min-blinket"
    environment = "dev"
    managed-by  = "terraform"
  }
}

resource "azurerm_log_analytics_workspace" "dev" {
  name                = "law-15min-blinket-dev-gwc"
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = {
    project     = "15min-blinket"
    environment = "dev"
    managed-by  = "terraform"
  }
}

resource "azurerm_container_app" "placeholder" {
  name                         = "ca-15min-blinket-dev-gwc"
  container_app_environment_id = azurerm_container_app_environment.dev.id
  resource_group_name          = azurerm_resource_group.dev.name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

  template {
    container {
      name   = "placeholder"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }

  ingress {
    external_enabled = true
    target_port      = 80

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  tags = {
    project     = "15min-blinket"
    environment = "dev"
    managed-by  = "terraform"
  }
}

resource "azurerm_storage_account" "audio" {
  name                = "st15minblinketdev"
  resource_group_name = azurerm_resource_group.dev.name
  location            = azurerm_resource_group.dev.location

  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version           = "TLS1_2"

  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false

  tags = {
    project     = "15min-blinket"
    environment = "dev"
    managed-by  = "terraform"
  }
}

resource "azurerm_storage_container" "audio" {
  name                  = "audio"
  storage_account_id    = azurerm_storage_account.audio.id
  container_access_type = "private"
}

resource "azurerm_mysql_flexible_server" "dev" {
  name                = "mysql-15min-blinket-dev"
  resource_group_name = azurerm_resource_group.dev.name
  location            = azurerm_resource_group.dev.location

  version              = "8.0.21" # or "8.0" if your provider prefers that form
  sku_name             = "B_Standard_B1ms"
  storage_mb           = 32768
  storage_iops         = 360
  auto_grow_enabled    = true

  administrator_login    = "mysqladmin"
  administrator_password = var.mysql_admin_password != null ? var.mysql_admin_password : ""

  backup_retention_days = 7

  tags = {
    project      = "15min-blinket"
    environment  = "dev"
    managed-by   = "terraform"
  }
}