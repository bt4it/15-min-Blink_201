variable "subscription_id" {
  description = "Azure subscription ID (from bootstrap script output / GitHub repo variable AZURE_SUBSCRIPTION_ID)"
  type        = string
}

variable "tenant_id" {
  description = "Entra ID tenant ID (from bootstrap script output / GitHub repo variable AZURE_TENANT_ID)"
  type        = string
}

variable "client_id" {
  description = "App Registration client ID used for OIDC auth (from bootstrap script output / GitHub repo variable AZURE_CLIENT_ID)"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the pre-existing resource group (created by bootstrap script 02) that Terraform manages resources inside. Terraform does not create this RG itself — see README for why."
  type        = string
  default     = "rg-blinket-dev"
}

variable "location" {
  description = "Azure region. See CI-CD-Terraform-Plan.md Section 7 for why this is Germany West Central."
  type        = string
  default     = "germanywestcentral"
}

variable "project_name" {
  type    = string
  default = "blinket"
}

variable "environment_name" {
  type    = string
  default = "dev"
}

variable "mysql_admin_username" {
  type    = string
  default = "blinketadmin"
}

variable "mysql_admin_password" {
  description = "MySQL admin password. Supplied via TF_VAR_mysql_admin_password, sourced from the GitHub Environment secret MYSQL_ADMIN_PASSWORD — never committed."
  type        = string
  sensitive   = true
}

variable "enable_front_door" {
  description = "Phase C toggle. Front Door has a base fee (~35 EUR/month) regardless of traffic — leave false until Phase C."
  type        = bool
  default     = false
}

variable "enable_function_app" {
  description = "Deploys the Consumption-plan Function App for the weekly audio-selection timer trigger (F13). Cheap even when on; default true."
  type        = bool
  default     = true
}

variable "monthly_budget_amount" {
  description = "Monthly budget ceiling in your billing currency. You get an alert at 80%."
  type        = number
  default     = 30
}

variable "budget_alert_email" {
  description = "Email to receive the 80% budget alert."
  type        = string
}
