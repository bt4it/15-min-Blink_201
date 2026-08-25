# 15-min-Blink.et — Terraform + CI/CD Implementation Plan (v3)

Status: **PLAN ONLY — no infrastructure code generated yet.**
This document is the single source of truth for the implementation
approach. All open decisions (D1–D6) are now resolved; the next step
is generating actual Terraform/workflow files, as a separate,
explicit step per your instruction.

**Change since v2:** region decision (D6) resolved to
`germanywestcentral` (Frankfurt) after evaluating it against South
Africa North — see Section 7 for the full reasoning, including the
counterintuitive finding that Frankfurt is likely as good or better
than Johannesburg for latency to Ethiopian users, not just easier for
the Bremen team.

**Change since v1:** the original Azure for Students sandbox turned
out to have no role available to create App Registrations or role
assignments (a common restriction on institution-managed tenants).
Decision: sign up for a **new Azure Free Trial using a personal
email and your own credit card**, which creates a brand-new Entra ID
tenant where you are Global Administrator by default — removing the
permission blocker entirely. This plan now assumes that account as
the target environment. The old student sandbox is no longer part of
this plan; nothing needs to be migrated out of it since nothing was
deployed there.

**Practical consequence of this account:** $200 credit usable within
the first 30 days, after which you either move to pay-as-you-go
(needed to keep resources running) or resources stop working. Given
our Phase A/B monthly cost estimate (~15–30 €/month), converting to
pay-as-you-go after the 30 days is the expected path, not a fallback —
budget for a small real charge starting month 2.

---

## 1. Goals this plan must satisfy

1. Real, running small-scale Azure deployment of the SOLL architecture
   (Container Apps + MySQL Flexible Server + Blob Storage, Functions
   timer trigger, optional Front Door) — not a simulation.
2. Infrastructure defined in **Terraform**, not Bicep (you have prior
   Terraform experience — building on that instead of introducing a
   second IaC language).
3. **CI/CD from the very first deployment**, not bolted on later —
   GitHub Actions, using your existing GitHub account/repo.
4. No long-lived credentials stored anywhere (no client secrets in
   GitHub, no storage keys hardcoded) — OIDC/federated identity end to
   end.
5. Cost discipline appropriate for a free trial / student credit
   subscription — nothing that bills a base fee gets turned on before
   it's actually needed.
6. Everything is **phased and verifiable** — each phase has a stated
   "how do I know this worked" check before moving to the next.

---

## 2. Repository & project layout

One repo, two independently-triggered pipelines. This keeps
infrastructure changes and application code changes from blocking
each other, and matches how you'll actually work day to day (you'll
touch app code far more often than infra code).

```
15min-blinket/
├── infra/
│   ├── bootstrap/          # one-time: creates the Terraform state backend itself
│   │   └── *.tf
│   ├── envs/
│   │   └── dev/            # the only environment for now; "prod" folder added later, same modules
│   │       ├── backend.tf
│   │       ├── providers.tf
│   │       ├── variables.tf
│   │       ├── main.tf         # or split: storage.tf, database.tf, compute.tf, functions.tf, frontdoor.tf, monitoring.tf, budget.tf
│   │       └── outputs.tf
│   └── modules/             # only introduced if/when we actually reuse something across envs
├── app/                     # your application code + Dockerfile
├── functions/               # the weekly audio-selection timer function
├── .github/
│   └── workflows/
│       ├── infra-plan-apply.yml   # triggered by changes under infra/**
│       └── app-build-deploy.yml   # triggered by changes under app/** and functions/**
└── docs/
    └── (this plan, decision log, architecture notes)
```

**Why this split:** it mirrors the two things that actually change at
different speeds and need different review rigor — infrastructure
changes are rarer and higher-blast-radius, so they get a plan/apply
gate; app changes should ship fast once tests pass.

---

## 3. Authentication design (OIDC, no stored secrets)

1. One **Entra ID App Registration** (D1, resolved: App Registration
   over a user-assigned managed identity — simplest setup for a
   single-environment project) represents "GitHub Actions for this
   project."
2. Two **federated credentials** on it:
   - `subject: repo:<you>/<repo>:ref:refs/heads/main` → used by the
     `apply` job.
   - `subject: repo:<you>/<repo>:pull_request` → used by the `plan`
     job on PRs, scoped to read-only via role assignment.
3. Role assignment: **Contributor** on the single resource group for
   now (not the whole subscription) — smallest blast radius that
   still lets Terraform manage everything it needs.
4. GitHub side stores only **non-secret identifiers** as repository
   variables (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`,
   `AZURE_SUBSCRIPTION_ID`) — none of these are secrets, they're
   public-ish identifiers; the trust relationship is what matters, not
   secrecy of the client ID.
5. The **one real secret** in this project — the MySQL admin password
   — lives in a GitHub **Environment secret** (scoped to the `dev`
   environment, not a plain repo secret), so it's not exposed to PR
   workflows from forks.

**Verification for this section:** after setup, `az login` should
never appear in any workflow — only `azure/login@v2` with
`client-id`/`tenant-id`/`subscription-id` and no `client-secret` input
at all. If a workflow needs `client-secret`, something in this design
was skipped.

---

## 4. Terraform state strategy

- **Bootstrap problem:** Terraform can't create the storage account it
  then uses as its own backend. `infra/bootstrap/` is a tiny,
  separate Terraform config (or a couple of `az` commands — see
  Decision D2) that creates: one resource group for state, one
  storage account, one blob container. This runs **once**, manually,
  before anything else, and essentially never changes again.
- **Main state:** `infra/envs/dev` uses the `azurerm` backend pointing
  at that bootstrap storage account, authenticated via OIDC
  (`use_oidc = true` in the backend block), not an access key.
- **State isolation:** one state file for the `dev` environment. If we
  later add `prod`, it gets its own state file (`key =
  "prod/terraform.tfstate"`) in the same backend storage account —
  never shared state across environments.

**Verification:** `terraform init` in `infra/envs/dev` should succeed
using only OIDC env vars (`ARM_USE_OIDC=true`, `ARM_CLIENT_ID`,
`ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID`) — no `ARM_CLIENT_SECRET`, no
storage account key anywhere in the config.

---

## 5. CI/CD pipeline design

### 5.1 `infra-plan-apply.yml`
- **Trigger:** pull request touching `infra/**` → run `terraform fmt
  -check`, `terraform validate`, `terraform plan`, post the plan as a
  PR comment.
- **Trigger:** push to `main` touching `infra/**` → run `terraform
  apply` against the `dev` GitHub Environment (which holds the MySQL
  password secret and can optionally require manual approval before
  apply — recommended while you're still learning the pipeline's
  behavior, can be removed once you trust it).

### 5.2 `app-build-deploy.yml`
- **Trigger:** push to `main` touching `app/**` → build the Docker
  image, push it to **GitHub Container Registry (GHCR)** rather than
  Azure Container Registry (Decision D3 explains why), then run `az
  containerapp update --image <new tag>` to roll out the new revision.
- Same pattern, separate job, for `functions/**` → package and deploy
  via `func azure functionapp publish` or the Azure Functions GitHub
  Action.

### 5.3 What CI/CD does *not* do yet (deliberately deferred)
- No automated integration tests against a live Azure environment yet
  — add once the app has actual tests to run.
- No blue/green or canary rollout — Container Apps revisions support
  traffic splitting, but that's Phase C/D complexity, not needed at
  pilot scale.
- No multi-environment promotion pipeline (dev → staging → prod) — one
  environment until there's a reason for more.

**Verification:** a trivial infra change (e.g. a tag update) run
through a PR should show a clean `plan` in the PR comment; merging
should apply automatically (or after one manual approval click) with
no manual `terraform apply` ever run from a laptop.

---

## 6. Phased delivery (same phases as before, CI/CD baked in from Phase A)

### Phase 0 — New Azure account setup (do this first, before any Terraform)
- Sign up for Azure Free Trial at azure.microsoft.com/free using a
  **personal, non-university email** and your own credit card.
- Confirm in the Portal (top-right account switcher → your new tenant)
  that you are listed as **Global Administrator** / the subscription's
  **Owner** — this is the fact the rest of the plan depends on.
- Set the subscription's spending limit / budget expectations in your
  head: $200 credit, 30-day clock starts now.
- Note the exact sign-up date somewhere you'll see it (e.g. this
  document) so Phase timing accounts for the 30-day credit window and
  the pay-as-you-go conversion.
- **Verification:** in the new tenant, Entra ID → App registrations →
  "New registration" is clickable and doesn't show a permissions
  error. This single check confirms the original blocker is gone
  before we invest any time in Terraform/CI-CD setup.

### Phase A — Core infra + pipeline skeleton
- Bootstrap state backend (manual, one-time).
- `infra/envs/dev`: Log Analytics, Container Apps Environment +
  Container App (placeholder image), Storage Account + `audio`
  container, MySQL Flexible Server (Burstable B1ms), budget + 80%
  alert. No Front Door yet.
- Both GitHub Actions workflows exist and are exercised at least once
  (infra apply, app deploy of a placeholder container).
- **Verification:** the Container App's public FQDN serves the
  placeholder response; `az mysql flexible-server show` confirms the
  DB is running; a budget alert email arrives when you simulate
  crossing 80% (or you confirm the alert rule exists via `az
  consumption budget show`).

### Phase B — Real app + weekly automation
- Replace the placeholder image with your actual containerized app.
- Migrate your 20 existing audios and IST database into the new Blob
  container / MySQL database.
- Deploy the Functions timer trigger for weekly audio selection.
- **Verification:** hitting the app's public URL returns a real
  "audio of the day" from your migrated catalog; the function's
  execution history in the Portal (or `func azure functionapp
  logstream`) shows a successful weekly run.

### Phase C — Edge/CDN layer
- Turn on Front Door Standard in front of the Container App.
- **Verification:** requests to the Front Door endpoint are served
  with cache headers indicating an edge hit on repeat requests.

### Phase D — Hardening
- Move the MySQL admin credential and storage access to managed
  identity where possible (reduces even the one remaining secret).
- Entra ID RBAC for any human admin access.
- Signed URLs / SAS for audio delivery instead of a static storage
  key.
- Application Insights on the Container App and Function App.

---

## 7. Decisions — status

**Resolved — D4, repo:** new dedicated repository (not reusing an
existing one).

**Resolved — D2, D3, D5 (accepted defaults from prior discussion):**
- D2 bootstrap method: plain `az` CLI commands, run once by hand.
- D3 container registry: GitHub Container Registry (GHCR) — free,
  already integrated with GitHub Actions.
- D5 approval gate: yes, `terraform apply` on `main` requires one
  manual approval click via GitHub Environment protection while the
  pipeline is new; can be removed once trusted.

**Resolved — D6, region: `germanywestcentral` (Frankfurt).**

This was the closest call of the six, so here's the actual reasoning
rather than just the answer:

- **Ease of management (Bremen team):** obvious win for Frankfurt —
  same business hours, same legal/data-protection framework (GDPR),
  best-documented and most mature Azure region for support and
  troubleshooting.
- **Latency to Ethiopian end users — this is the counterintuitive
  part:** South Africa North *looks* closer to Addis Ababa on a map,
  but Ethiopia's actual international internet traffic doesn't route
  south through the African continent. East African subsea cable
  capacity (e.g. the Mombasa–Marseille route) is built to carry
  traffic north to Marseille, France, and the AAE-1 cable that serves
  the wider region runs from South East Asia through Djibouti and
  Egypt up to Marseille — Marseille being one of the dominant
  Mediterranean cable landing hubs for Africa. In practice, traffic
  from Addis Ababa to almost anywhere already transits through Europe
  before continuing elsewhere. That means Frankfurt is likely as good
  as or better than Johannesburg for real Ethiopian users, not a
  compromise.
- **Service maturity:** Germany West Central has full support for
  every service in this architecture (Container Apps, MySQL Flexible
  Server, Front Door, Functions Consumption). South Africa North is
  solid for the core services but has had gaps in newer offerings
  (e.g. Azure Functions Flex Consumption isn't available there yet;
  classic Consumption is fine, but it's one more thing to check every
  time we add a service).
- **Simplicity:** one region is enough for a 20-audio pilot. If real
  usage data later shows Ethiopian users would meaningfully benefit
  from an African point of presence, the correct move is adding South
  Africa North as a **second Front Door origin** in Phase C — a small
  incremental change, not a re-architecture. No need to decide that
  now.

One flag for Phase 0: free-trial-type subscriptions sometimes have a
restricted region list until you submit a one-time "region access
request." Worth confirming `germanywestcentral` is selectable for
each resource type (Container Apps, MySQL Flexible Server) during
Phase 0, alongside the App Registration check.

---

## 8. Risks & mitigations

| Risk | Mitigation |
|---|---|
| New tenant still has some unexpected restriction | Phase 0's verification step catches this immediately, before any Terraform/CI-CD time is invested — resolved risk from v1, kept as a gate rather than an assumption. |
| $200 credit runs out before Phase A+B are usably complete | Phase 0 starts the clock deliberately; Phases A/B are scoped to be achievable well inside 30 days given they're mostly "deploy + migrate 20 audios," not new development. |
| Forgetting to convert to pay-as-you-go and losing the resources when the trial ends | Set a personal reminder for day ~25 of the trial; document the conversion step in this plan once we reach it. |
| Terraform state loss (laptop-only state, someone deletes the storage account) | State lives in Azure Blob with soft-delete/versioning enabled on the bootstrap storage account. |
| Front Door left on accidentally, burning credit | Off by default (`enableFrontDoor`-equivalent variable), only enabled deliberately in Phase C. |
| Budget exceeded before alert reacts | 80% alert plus a manual weekly check of Azure Cost Management during the pilot phase — alerts are not instantaneous. |
| New personal tenant has no institutional affiliation for the IHK submission | Cosmetic only — the architecture and code are what's graded, not which tenant hosts the sandbox. Worth a one-line note in your documentation explaining the account switch, for transparency. |

---

## 9. What happens after this plan is agreed

All decisions (D1–D6) are now resolved. The next step is generating
the actual Terraform (`infra/bootstrap`, `infra/envs/dev`, targeting
`germanywestcentral`) and the two GitHub Actions workflow files — as a
separate, explicit step, per your instruction. Say the word and we'll
move to that.
