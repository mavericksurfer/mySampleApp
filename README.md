# Azure app across dev / prod — HCP Terraform (CLI-driven, OIDC) + GitHub Actions

A small, cheap, **convention-driven** learning sample: one Terraform config that
manages a Linux Web App (+ App Service Plan) in **two isolated environments**,
each in its **own Azure subscription**, using **HCP Terraform CLI-driven
workspaces** with **OIDC dynamic credentials** (no stored secrets), driven from
**GitHub Actions**.

## Design principles applied

- **Convention over configuration.** Resource names, tags, and `always_on` are
  *derived* in `modules/app` from three true inputs (workload, environment,
  region). The YAML files carry only what genuinely differs.
- **Discover, don't pass.** Subscription/tenant come from HCP's injected `ARM_*`
  env vars and `azurerm_client_config` / `azurerm_subscription` data sources —
  never typed as inputs.
- **Config as data.** One `apps/<name>.yaml` file describes the whole app:
  shared `defaults` overlaid with per-environment overrides, decoded with
  `yamldecode` and validated through an `optional()` object type. The
  environment itself is derived from the workspace name, so **deploys pass no
  CLI variables at all**.

## How the pieces fit

```
GitHub Actions runner        HCP Terraform (remote exec)          Azure
--------------------         ---------------------------          -----
terraform plan/apply ──►     workspace app-dev  ─┐                Dev subscription
 (holds TF_API_TOKEN)                            ├─ OIDC federation ─► rg-demoapp-dev-aue  (B1)
                             workspace app-prod ─┘                Prod subscription
                                                                  └─► rg-demoapp-prod-aue (B2)
```

No secret is stored in GitHub or HCP:
- **GitHub → HCP**: `TF_API_TOKEN`.
- **HCP → Azure**: OIDC. HCP mints a short-lived token each run; Azure trusts it
  via a **federated credential** on an App Registration.

## What it deploys

| Env  | Subscription | SKU | Instances | Always On | RG name            |
|------|--------------|-----|-----------|-----------|--------------------|
| dev  | Dev          | B1  | 1         | no        | rg-demoapp-dev-aue |
| prod | Prod         | B2  | 1         | yes       | rg-demoapp-prod-aue|

## One-time setup

### 1. Create the two workspaces in HCP Terraform
Create `app-dev` and `app-prod`, each tagged `app` and `azure` (matches the
`tags` filter in `backend.tf`). Set **Execution Mode = Remote** and
**Workflow = CLI-driven**.

### 2. Create an Azure App Registration per subscription + federated credentials
For each environment, create an App Registration (no client secret) and grant
its service principal **Contributor** on the target subscription:

```bash
# Example for dev; repeat with the Prod subscription for prod.
az ad app create --display-name "hcp-tfc-app-dev"
APP_ID=$(az ad app list --display-name "hcp-tfc-app-dev" --query "[0].appId" -o tsv)
az ad sp create --id "$APP_ID"
az role assignment create --assignee "$APP_ID" --role Contributor \
  --scope "/subscriptions/<DEV_SUBSCRIPTION_ID>"
```

Add **federated credentials** so Azure trusts HCP. HCP's OIDC subject looks
like `organization:<org>:project:<project>:workspace:<workspace>:run_phase:<phase>`.
Add one credential per run phase you use (`plan` and `apply`):

```bash
az ad app federated-credential create --id "$APP_ID" --parameters '{
  "name": "hcp-app-dev-apply",
  "issuer": "https://app.terraform.io",
  "subject": "organization:my-hcp-org:project:Default Project:workspace:app-dev:run_phase:apply",
  "audiences": ["api://AzureADTokenExchange"]
}'
# repeat with run_phase:plan, and again for app-prod against the Prod sub.
```

### 3. Set the dynamic-credential variables on each workspace (Environment vars)
No secrets — just identifiers that tell HCP to federate:

| Variable                   | Value                                  |
|----------------------------|----------------------------------------|
| `TFC_AZURE_PROVIDER_AUTH`  | `true`                                 |
| `TFC_AZURE_RUN_CLIENT_ID`  | App Registration (client) id for that env |
| `ARM_SUBSCRIPTION_ID`      | **Dev** sub id (app-dev) / **Prod** sub id (app-prod) |
| `ARM_TENANT_ID`            | your Azure AD tenant id                |

The differing `ARM_SUBSCRIPTION_ID` is what lands each environment in its own
subscription.

### 4. Add the HCP token to GitHub
Add a repo secret `TF_API_TOKEN` (Settings → Secrets and variables → Actions).

### 5. (Recommended) Create GitHub Environments
Create `dev` and `prod` under Settings → Environments; add **required
reviewers** to `prod` so `apply-prod` pauses for approval.

### 6. Update the placeholders
- `backend.tf`: `organization = "my-hcp-org"`
- `.github/workflows/terraform.yml`: `TF_CLOUD_ORGANIZATION: my-hcp-org`
- federated-credential `subject`s: your org/project names

## Run it locally (CLI-driven, same as CI)

```bash
cd terraform-azure-app
export TF_WORKSPACE=app-dev     # or app-prod — this alone selects the environment
terraform login                 # stores your HCP token
terraform init
terraform plan                  # no -var-file needed
terraform apply
```

## Day-to-day flow

1. Open a PR → **plan** runs a speculative plan for both envs.
2. Merge to `main` → **apply-dev → apply-prod** run in order; `apply-prod`
   waits for approval if you configured the environment gate.

## Adding another environment (the "vending" idea)

Adding `staging` is a data change, not a module change:
1. Create workspace `app-staging` (+ federated creds + `ARM_SUBSCRIPTION_ID`).
2. Add a `staging:` block under `environments:` in `apps/demoapp.yaml`.
3. Add `staging` to the workflow matrix.

The module needs no edit — it accepts any well-formed environment name, and the
root precondition fails clearly if a workspace points at an environment that
isn't defined in the app file.

## Cost note

Running cost is essentially the two App Service Plans (B1 + B2). To pause spend:

```bash
TF_WORKSPACE=app-dev  terraform destroy
TF_WORKSPACE=app-prod terraform destroy
```

## Layout

```
terraform-azure-app/
├── backend.tf              # HCP cloud block (tags-based, CLI-driven)
├── providers.tf            # azurerm provider, use_oidc = true
├── main.tf                 # derive env, load app YAML, resolve slice, call module
├── outputs.tf
├── apps/
│   └── demoapp.yaml        # whole app: defaults + per-environment overrides
├── modules/app/            # conventions + resources live here
│   ├── main.tf             # naming, tags, discovery, RG/Plan/Web App
│   ├── variables.tf        # typed config object, optional() defaults, validation
│   ├── versions.tf         # module provider requirements
│   └── outputs.tf
└── .github/workflows/terraform.yml
```
