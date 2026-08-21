# ---------- Cloud-level context: Azure (one per cloud provider) ----------
#
# Holds values that are constant for every Azure stack regardless of
# environment tier: the Azure AD tenant, and how the azurerm provider
# authenticates. Auto-attaches to any stack labeled cloud:azure — no
# spacelift_context_attachment resource needed.

resource "spacelift_context" "azure" {
  name        = "cloud-azure"
  description = "Azure-wide, environment-independent OIDC/provider settings. Auto-attaches to every stack labeled cloud:azure."
  labels      = ["autoattach:cloud:azure"]
}

resource "spacelift_environment_variable" "azure_tenant_id" {
  context_id = spacelift_context.azure.id
  name       = "ARM_TENANT_ID"
  # Derived, not typed in by hand — the tenant that hosts this run's Azure
  # credentials, same tenant every identity.tf identity is created in.
  value      = data.azurerm_client_config.current.tenant_id
  write_only = true
}

resource "spacelift_environment_variable" "azure_use_oidc" {
  context_id = spacelift_context.azure.id
  name       = "ARM_USE_OIDC"
  value      = "true"
  write_only = false
}

resource "spacelift_environment_variable" "azure_oidc_token_file_path" {
  context_id = spacelift_context.azure.id
  name       = "ARM_OIDC_TOKEN_FILE_PATH"
  value      = "/mnt/workspace/spacelift.oidc"
  write_only = false
}

# ---------- Env-level contexts: one per environment tier ----------
#
# Holds values scoped to one environment tier, shared across every app in
# that tier: which environment this is, which subscription it deploys into,
# and which managed identity authenticates it. Auto-attaches to any stack
# labeled env:<tier>.

resource "spacelift_context" "env" {
  for_each = var.environments

  name        = "env-${each.key}"
  description = "Environment-tier settings for ${each.key} (all apps). Auto-attaches to every stack labeled env:${each.key}."
  labels      = ["autoattach:env:${each.key}"]
}

resource "spacelift_environment_variable" "environment_name" {
  for_each = var.environments

  context_id = spacelift_context.env[each.key].id
  name       = "ENVIRONMENT"
  value      = each.key
  write_only = false
}

resource "spacelift_environment_variable" "arm_subscription_id" {
  for_each = var.environments

  context_id = spacelift_context.env[each.key].id
  name       = "ARM_SUBSCRIPTION_ID"
  value      = each.value.subscription_id
  write_only = true
}

resource "spacelift_environment_variable" "arm_client_id" {
  for_each = var.environments

  context_id = spacelift_context.env[each.key].id
  name       = "ARM_CLIENT_ID"
  # One managed identity per environment tier (dev/staging/prod), created in
  # identity.tf, RBAC-scoped to that tier's subscription only. Every stack in
  # this tier still gets its OWN federated credential (subject includes the
  # exact stack name — see identity.tf and spacelift-azure/README.md's
  # 5-credential table) registered against THIS SAME identity, so client_id
  # is shared within a tier by design, not shared across tiers.
  #
  # If your org instead uses a single flat identity across all tiers, move
  # this to a single azurerm_user_assigned_identity in identity.tf and
  # reference it from the spacelift_environment_variable block under
  # spacelift_context.azure above — no other part of this design changes.
  value      = azurerm_user_assigned_identity.env[each.key].client_id
  write_only = true
}
