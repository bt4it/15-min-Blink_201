# The resource group is created once, out-of-band, by
# infra/bootstrap/02-create-oidc-identity.sh — NOT by Terraform.
#
# Why: the GitHub Actions identity is granted Contributor scoped to this
# one resource group (least privilege). That role assignment has to point
# at a resource group that already exists, so the RG is created during
# bootstrap, before Terraform ever runs. Terraform then manages everything
# *inside* it via this data source, but never the RG resource itself.
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

locals {
  name_prefix = "${var.project_name}-${var.environment_name}"
}
