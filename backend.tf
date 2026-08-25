# Backend config is intentionally left mostly empty here.
# Values (resource_group_name, storage_account_name, container_name, key)
# are supplied at `terraform init` time via -backend-config flags, so this
# same file works for both local dev and CI without hardcoding the state
# account name in version control.
#
# Example local init:
#   terraform init \
#     -backend-config="resource_group_name=rg-blinket-tfstate" \
#     -backend-config="storage_account_name=blinkettfstate01" \
#     -backend-config="container_name=tfstate" \
#     -backend-config="key=dev.terraform.tfstate"

terraform {
  backend "azurerm" {
    use_oidc = true
  }
}
