# 15-min-Blink.et — Terraform + CI/CD (Phase A implementation)

This implements **Phase A** of `CI-CD-Terraform-Plan.md` (v3): core
infra + pipeline skeleton, in your new Azure Free Trial account,
region `germanywestcentral`. Front Door (Phase C) is present in the
code but disabled by default.

## Before you do anything: your 30-day clock

You mentioned the new account uses the $200/30-day free trial credit.
Everything below is scoped to be doable well inside that window —
Phase A is "deploy infra + prove the pipeline works," not new
application development. Note today's date somewhere so you know when
day ~25 is (that's when to convert to pay-as-you-go so nothing gets
torn down mid-project).

## Execution order (do these once, in order)

### 1. Create a new GitHub repository
Per Decision D4 — a new, dedicated repo. Push this folder structure to
it as-is.

### 2. Run the bootstrap scripts (from your machine, `az login` first)
```bash
cd infra/bootstrap
chmod +x 01-create-state-backend.sh 02-create-oidc-identity.sh

./01-create-state-backend.sh
# note the three values it prints

# edit 02-create-oidc-identity.sh first: set GITHUB_ORG and GITHUB_REPO
./02-create-oidc-identity.sh
# note the four values it prints
```

**Why these are separate scripts, and why by hand:** this is the one
part of the whole setup that a CI/CD pipeline can't do for itself —
the pipeline's own identity doesn't exist yet. Everything after this
point is automated; this part necessarily isn't.

### 3. Configure the GitHub repository
Go to **Settings → Secrets and variables → Actions**.

**Repository variables** (Variables tab):
| Name | Value | Source |
|---|---|---|
| `AZURE_CLIENT_ID` | from script 02 | bootstrap output |
| `AZURE_TENANT_ID` | from script 02 | bootstrap output |
| `AZURE_SUBSCRIPTION_ID` | from script 02 | bootstrap output |
| `TARGET_RESOURCE_GROUP` | `rg-blinket-dev` | bootstrap output |
| `TF_STATE_RESOURCE_GROUP` | from script 01 | bootstrap output |
| `TF_STATE_STORAGE_ACCOUNT` | from script 01 | bootstrap output |
| `TF_STATE_CONTAINER` | `tfstate` | bootstrap output |
| `BUDGET_ALERT_EMAIL` | your email | — |
| `CONTAINER_APP_NAME` | `blinket-dev-app` | matches Terraform naming |
| `FUNCTION_APP_NAME` | `blinket-dev-func` | matches Terraform naming |

**Create a GitHub Environment** named `dev` (Settings → Environments),
and add:

**Environment secret** (Secrets tab, inside the `dev` environment):
| Name | Value |
|---|---|
| `MYSQL_ADMIN_PASSWORD` | a strong password you choose |

Optionally enable **required reviewers** on the `dev` environment —
this is Decision D5's manual approval gate. Recommended while the
pipeline is new; remove once you trust it.

### 4. Open a PR, watch the plan, merge
Push a trivial change under `infra/envs/dev/` (or just push this whole
structure as your first PR). The `plan` job runs automatically and
comments the Terraform plan on the PR. Review it, merge to `main`, and
the `apply` job provisions everything (after the approval click, if
you enabled that).

### 5. Verify (matches Phase A's verification criteria in the plan)
- `container_app_url` output resolves and serves the placeholder page.
- `az mysql flexible-server show --name blinket-dev-mysql --resource-group rg-blinket-dev` shows the server running.
- `az consumption budget show --resource-group rg-blinket-dev --budget-name blinket-dev-budget` confirms the budget + alert exist.

## What's intentionally not here yet

- **`app/` and `functions/` folders are empty placeholders.** The
  Container App runs Microsoft's demo image until you add real app
  code and push to `app/` — that's what triggers `app-build-deploy.yml`.
- **Front Door is off** (`enable_front_door = false` by default) — see
  Phase C in the plan.
- **No managed-identity-based DB/storage auth yet** — that's Phase D
  hardening. Phase A intentionally uses simpler secret-based auth to
  get something running fast; tighten later.

## Day-to-day cost control

Stop the MySQL server between work sessions:
```bash
az mysql flexible-server stop --resource-group rg-blinket-dev --name blinket-dev-mysql
az mysql flexible-server start --resource-group rg-blinket-dev --name blinket-dev-mysql
```
A stopped server bills storage only (a few cents/month at 20GB), not compute.

## A note on the resource group

Terraform deliberately does **not** create `rg-blinket-dev` itself —
it's created once by the bootstrap script, and Terraform's identity is
granted Contributor scoped to just that RG (least privilege for a
CI/CD identity). Terraform references it via a `data` source
(`infra/envs/dev/main.tf`) rather than a `resource` block. If you ever
want Terraform to own the RG too, that's a deliberate architecture
change, not a bug to fix.
