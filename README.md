# spacelift-orchestration

Creates and configures every Spacelift stack for [`spacelift-azure`](../spacelift-azure) via the Spacelift Terraform provider, **and** the Azure-side identity each stack authenticates with — no manual stack creation, no manually-entered ARM_* variables, no manually-created managed identity/role assignment/federated credentials.

## What this replaces

Before this repo existed, `spacelift-azure`'s 6 stacks (2 apps × 3 environments) each needed 5 ARM_* variables plus `ENVIRONMENT` set **manually** in the Spacelift UI — 36 settings total, duplicated across every stack, drift-prone. On top of that, each environment tier needed its own manually-created Azure managed identity, a Contributor role assignment, and 5 federated credentials per stack (subject format `space:<space-id>:stack:<name>:run_type:...:scope:...`) — easy to forget when a new app gets added, since Azure requires an exact subject match with no wildcards.

This repo creates all of that in code:
1. `identity.tf` — one Azure managed identity per environment tier, a Contributor role assignment (subscription-scoped, since apps create their own resource groups), and one federated credential per (stack × run_type × scope), kept in sync automatically via the same stack matrix `stacks.tf` builds.
2. `contexts.tf` — two Spacelift Contexts (cloud-level, env-level) that push the resulting `ARM_CLIENT_ID`/`ARM_TENANT_ID`/`ARM_SUBSCRIPTION_ID`/etc. onto every stack automatically via label-based auto-attachment.
3. `stacks.tf` — one `spacelift_stack` per (app × environment), with the labels the two contexts key off — no per-stack ARM_* variables anywhere.

## How it works

1. `identity.tf` creates `azurerm_user_assigned_identity.env[tier]` per environment tier, assigns it Contributor at subscription scope, and creates `azurerm_federated_identity_credential` resources — one per stack per run-type/scope combination, computed from `local.stack_matrix` (defined in `stacks.tf`) so it can never drift from the actual set of stacks.
2. `contexts.tf` creates one **cloud-level context** (`cloud-azure`, holding `ARM_TENANT_ID` — derived from `data.azurerm_client_config.current`, not typed in by hand — plus `ARM_USE_OIDC`/`ARM_OIDC_TOKEN_FILE_PATH`) and one **env-level context per tier** (`env-dev`/`env-staging`/`env-prod`, each holding `ENVIRONMENT`/`ARM_SUBSCRIPTION_ID`/`ARM_CLIENT_ID` — the last one read straight from that tier's `azurerm_user_assigned_identity` output).
3. Each context carries an `autoattach:<label>` label. Spacelift auto-attaches a context to any stack whose own labels contain the matching value — no `spacelift_context_attachment` resource needed.
4. `stacks.tf` creates one `spacelift_stack` per (app × environment) combination, each with `project_root = "apps/<app>"` pointing into `spacelift-azure`, and three plain labels: `app:<name>`, `env:<tier>`, `cloud:azure`. The `env:` and `cloud:` labels are what the two auto-attach contexts key off — every stack ends up with both attached automatically.

Net effect: adding a new app or environment tier to `spacelift-azure` requires editing this repo only — no manual stack configuration, and no manual Azure identity/role/federated-credential work either.

## Why two levels, not one

- `ARM_TENANT_ID` doesn't vary by environment — only by cloud provider — so it lives at the cloud level.
- `ENVIRONMENT`, `ARM_SUBSCRIPTION_ID`, and `ARM_CLIENT_ID` vary by environment tier but are shared across every app within that tier, so they live at the env level.
- No variable name collides between the two contexts, so attachment order/priority never matters here.

See `contexts.tf` for the full reasoning behind where `ARM_CLIENT_ID` specifically lives (one managed identity per environment tier, not one flat org-wide identity) — that comment also explains the one-line change needed if your org's identity model differs.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# fill in real subscription_id per tier, spacelift_space_id, spacelift_hostname

az login   # or set ARM_* env vars for a bootstrap service principal —
           # this run needs real Azure credentials, since it's what CREATES
           # the identities other stacks later authenticate with via OIDC

terraform init
terraform plan
terraform apply
```

Requires `SPACELIFT_API_KEY_ENDPOINT`, `SPACELIFT_API_KEY_ID`, `SPACELIFT_API_KEY_SECRET` environment variables (a Spacelift API key with permission to create stacks/contexts) **and** an authenticated `az` session or `ARM_*` credentials with permission to create managed identities and role assignments in the target subscription(s).

## Adding a new app

Add the app's folder under `spacelift-azure/apps/<name>/` (see [`MULTI_APP_STRUCTURE.md`](../spacelift-azure/docs/MULTI_APP_STRUCTURE.md)), then add `"<name>"` to `local.apps` in `stacks.tf`. Three new stacks (one per environment) and their 15 new federated credentials (3 stacks × 5 each) get created automatically on the next apply — no changes to `contexts.tf` or `identity.tf`.

## Adding a new environment tier

Add an entry to `var.environments` in `terraform.tfvars` (a subscription_id — the same value as existing tiers is fine, or a genuinely different subscription). A new managed identity, its role assignment, its federated credentials, a new `env-<tier>` context, and one new stack per existing app all get created automatically on the next apply.

## Running this repo through Spacelift itself

If you point a Spacelift stack at this repo's own root, that stack is necessarily a manually-configured one-off — it can't autoattach a context to itself before the contexts it creates exist. Not automated here; configure its ARM_*/Spacelift API credentials directly on that one stack.

## Future: a Client axis

Not built yet, but the shape supports it: extend `local.stack_matrix`'s `setproduct` to include a client list, rename stacks to `"${client}-${app}-${env}"`, and add a `client:${client}` label. `contexts.tf` wouldn't need to change unless client-specific identity is required — that would be a third, separate context tier, not a rework of the two that exist today.
