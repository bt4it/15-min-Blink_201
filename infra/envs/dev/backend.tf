terraform {
  backend "azurerm" {
    resource_group_name  = "rg-15min-blinket-tfstate-gwc"
    storage_account_name = "st15minblinkettfstate"
    container_name       = "tfstate"
    key                  = "dev/terraform.tfstate"

    use_oidc = true
    use_azuread_auth = true
  }
}