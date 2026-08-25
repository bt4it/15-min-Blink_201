# Compute (F1/F2). Starts with a placeholder image; the app-build-deploy
# GitHub Actions workflow replaces it via `az containerapp update` once
# your real app is containerized — Terraform does not manage the image tag
# day to day, only the app's shape (scaling, env var wiring, ingress).
resource "azurerm_container_app_environment" "main" {
  name                       = "${local.name_prefix}-env"
  resource_group_name        = data.azurerm_resource_group.main.name
  location                   = data.azurerm_resource_group.main.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
}

resource "azurerm_container_app" "main" {
  name                         = "${local.name_prefix}-app"
  resource_group_name          = data.azurerm_resource_group.main.name
  container_app_environment_id = azurerm_container_app_environment.main.id
  revision_mode                = "Single"

  secret {
    name  = "mysql-password"
    value = var.mysql_admin_password
  }

  secret {
    name  = "storage-key"
    value = azurerm_storage_account.main.primary_access_key
  }

  ingress {
    external_enabled = true
    target_port      = 3000
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  template {
    min_replicas = 1 # matches Kap. 9.2 sizing: 1 warm instance
    max_replicas = 3

    container {
      name   = "app"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest" # replaced by CI/CD once real app exists
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "MYSQL_HOST"
        value = azurerm_mysql_flexible_server.main.fqdn
      }
      env {
        name  = "MYSQL_USER"
        value = var.mysql_admin_username
      }
      env {
        name        = "MYSQL_PASSWORD"
        secret_name = "mysql-password"
      }
      env {
        name  = "MYSQL_DB"
        value = azurerm_mysql_flexible_database.main.name
      }
      env {
        name  = "STORAGE_ACCOUNT_NAME"
        value = azurerm_storage_account.main.name
      }
      env {
        name        = "STORAGE_ACCOUNT_KEY"
        secret_name = "storage-key"
      }
    }
  }

  # Terraform should not fight the CI/CD pipeline over the image tag —
  # app-build-deploy.yml updates it via `az containerapp update`.
  lifecycle {
    ignore_changes = [template[0].container[0].image]
  }
}
