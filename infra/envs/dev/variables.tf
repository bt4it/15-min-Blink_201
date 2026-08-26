variable "location" {
  description = "Azure region for the development environment."
  type        = string
  default     = "germanywestcentral"
}

variable "resource_group_name" {
  description = "Name of the existing dev resource group (created and RBAC-scoped in Phase 1)."
  type        = string
  default     = "rg-15min-blinket-dev-gwc"
}

variable "mysql_admin_password" {
  description = "Administrator password for MySQL Flexible Server (dev)."
  type        = string
  sensitive   = true
}