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

resource "azurerm_container_app_environment" "dev" {
  name                       = "cae-15min-blinket-dev-gwc"
  location                   = azurerm_resource_group.dev.location
  resource_group_name        = azurerm_resource_group.dev.name
  logs_destination           = "log-analytics"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.dev.id

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