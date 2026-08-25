# Cost guardrail: alert at 80% of the monthly budget.
#
# time_period.start_date normally needs a fixed value — using timestamp()
# directly would cause a diff on every plan. Set start_date once when you
# first apply this (e.g. today's date, 1st of the month) and leave it;
# the lifecycle block below stops Terraform from trying to "fix" it back.
resource "azurerm_consumption_budget_resource_group" "main" {
  name              = "${local.name_prefix}-budget"
  resource_group_id = data.azurerm_resource_group.main.id
  amount            = var.monthly_budget_amount
  time_grain        = "Monthly"

  time_period {
    start_date = "2026-09-01T00:00:00Z" # set to the 1st of the month you first apply this
  }

  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThan"
    contact_emails = [var.budget_alert_email]
  }

  lifecycle {
    ignore_changes = [time_period[0].start_date]
  }
}
