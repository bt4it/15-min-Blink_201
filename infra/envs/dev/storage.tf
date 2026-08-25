# Audio catalog storage (F8/F15). LRS is enough at pilot scale; consider
# ZRS if you want to match the Projektarbeit's Design Case 1:1 later.
resource "azurerm_storage_account" "main" {
  name                            = replace("${local.name_prefix}stor", "-", "")
  resource_group_name             = data.azurerm_resource_group.main.name
  location                        = data.azurerm_resource_group.main.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
}

resource "azurerm_storage_container" "audio" {
  name                  = "audio"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private" # access only via key/SAS — matches Kap. 11 security concept
}
