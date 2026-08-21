# App x Environment stack matrix. Adding a new app or environment tier
# requires no changes to contexts.tf — only a new entry here (and, for a new
# environment, a new managed identity + federated credentials in Azure).
#
# Adding a future Client axis: extend the setproduct below to
# setproduct(local.apps, local.clients, keys(var.environments)), rename the
# key/name to "${client}-${app}-${env}", and add a "client:${client}" label.
# contexts.tf would only need to change if client-specific identity is ever
# required — that would be a third, separate context tier, not a rework of
# the two that already exist.

locals {
  apps = toset(["storage", "networking"])

  stack_matrix = {
    for pair in setproduct(local.apps, keys(var.environments)) :
    "${pair[0]}-${pair[1]}" => {
      app = pair[0]
      env = pair[1]
    }
  }
}

resource "spacelift_stack" "this" {
  for_each = local.stack_matrix

  name         = each.key # e.g. "storage-dev"
  repository   = var.spacelift_azure_repo
  branch       = var.spacelift_azure_branch
  project_root = "apps/${each.value.app}"

  labels = [
    "app:${each.value.app}",
    "env:${each.value.env}",
    "cloud:azure",
  ]

  terraform_version       = var.terraform_version
  terraform_workflow_tool = "OPEN_TOFU"

  # No ARM_*, no ENVIRONMENT here. Both are supplied automatically by the
  # cloud:azure and env:<tier> contexts via label auto-attachment — that is
  # the entire point of this repo.
}
