variable "environments" {
  description = "Per-environment-tier subscription config. One managed identity (created in identity.tf) and one subscription per tier (dev/staging/prod), shared across all apps within that tier. Azure AD tenant is derived automatically, not set here — see data.azurerm_client_config.current in identity.tf."
  type = map(object({
    subscription_id = string
  }))
}

variable "identity_location" {
  description = "Azure region for the resource group hosting the per-tier managed identities."
  type        = string
  default     = "eastus"
}

variable "spacelift_space_id" {
  description = "Spacelift space ID the stacks live in — appears in every OIDC federated-credential subject."
  type        = string
}

variable "spacelift_hostname" {
  description = "Spacelift account hostname. OIDC issuer = https://<this>, audience = <this>."
  type        = string
  default     = "moviepotter.app.spacelift.io"
}

variable "spacelift_azure_repo" {
  description = "Repository name (as configured in Spacelift's default VCS integration) hosting the app code. Namespace/owner (e.g. krupakar-hyland) is resolved from that integration, not set here — spacelift_stack has no namespace argument outside a github_enterprise block, which doesn't apply to a plain github.com repo."
  type        = string
  default     = "spacelift-azure"
}

variable "spacelift_azure_branch" {
  description = "Branch to track for every stack created here. Must be a branch that actually has the apps/ layout (see docs/MULTI_APP_STRUCTURE.md in spacelift-azure) — main does not yet, only feature/multi-app-structure does."
  type        = string
  default     = "feature/multi-app-structure"
}

variable "terraform_version" {
  description = "OpenTofu version to use (requires terraform_workflow_tool = OPEN_TOFU)."
  type        = string
  default     = "1.9.0"
}
