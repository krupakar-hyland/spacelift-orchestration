# Creates the Azure side of the OIDC trust this whole repo depends on: one
# managed identity per environment tier, a Contributor role assignment so
# that identity can create resource groups (apps/storage and apps/networking
# each create their own dynamically — see spacelift-azure), and one federated
# credential per (stack x run_type x scope) so Spacelift's OIDC token can
# actually exchange for an Azure access token when a stack runs.
#
# Bootstrap note: this repo's own Terraform run needs real Azure credentials
# (az login, or ARM_* env vars) to create these identities in the first
# place — it can't use OIDC against an identity it hasn't created yet.

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "identities" {
  name     = "rg-spacelift-identities"
  location = var.identity_location
}

# ---------- One managed identity per environment tier ----------

resource "azurerm_user_assigned_identity" "env" {
  for_each = var.environments

  name                = "spacelift-${each.key}"
  resource_group_name = azurerm_resource_group.identities.name
  location            = azurerm_resource_group.identities.location
}

# Contributor at subscription scope, not a resource group scope — the apps
# this identity deploys (apps/storage, apps/networking) each create their own
# resource group, so scoping any narrower would fail on first apply.
resource "azurerm_role_assignment" "env" {
  for_each = var.environments

  scope                = "/subscriptions/${each.value.subscription_id}"
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.env[each.key].principal_id
}

# ---------- Federated credentials: one per (stack x run_type x scope) ----------
#
# Azure requires an exact subject match for custom OIDC issuers — no
# wildcards — so every stack needs its own 5 credentials (matching
# spacelift-azure/README.md's federated-credential table), registered
# against its tier's shared identity. Reuses local.stack_matrix from
# stacks.tf so this can never drift from the actual set of stacks created.

locals {
  run_type_scopes = {
    tracked_write = { run_type = "TRACKED", scope = "write" }
    tracked_read  = { run_type = "TRACKED", scope = "read" }
    proposed_read = { run_type = "PROPOSED", scope = "read" }
    task_write    = { run_type = "TASK", scope = "write" }
    destroy_write = { run_type = "DESTROY", scope = "write" }
  }

  stack_names_by_env = {
    for env in keys(var.environments) : env => [
      for k, v in local.stack_matrix : k if v.env == env
    ]
  }

  federated_credentials = merge([
    for env, stack_names in local.stack_names_by_env : merge([
      for stack_name in stack_names : {
        for key, rt in local.run_type_scopes :
        "${stack_name}--${key}" => {
          env     = env
          subject = "space:${var.spacelift_space_id}:stack:${stack_name}:run_type:${rt.run_type}:scope:${rt.scope}"
        }
      }
    ]...)
  ]...)
}

resource "azurerm_federated_identity_credential" "this" {
  for_each = local.federated_credentials

  name                = replace(each.key, "/[^a-zA-Z0-9_-]/", "-")
  resource_group_name = azurerm_resource_group.identities.name
  parent_id           = azurerm_user_assigned_identity.env[each.value.env].id
  audience            = [var.spacelift_hostname]
  issuer              = "https://${var.spacelift_hostname}"
  subject             = each.value.subject
}
