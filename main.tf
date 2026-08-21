terraform {
  required_version = ">= 1.0"
  required_providers {
    spacelift = {
      source  = "spacelift-io/spacelift"
      version = "~> 1.0"
    }
    azurerm = {
      source  = "opentofu/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "spacelift" {
  # api_key_endpoint / api_key_id / api_key_secret read from
  # SPACELIFT_API_KEY_ENDPOINT / SPACELIFT_API_KEY_ID / SPACELIFT_API_KEY_SECRET
  # env vars. This stack is a manually-configured one-off (see README.md) — it
  # can't autoattach a context to itself before the contexts it creates exist.
}

provider "azurerm" {
  features {}
  # Real credentials required to run this repo (az login, or ARM_* env vars
  # for a bootstrap service principal) — this is what creates the very
  # identities other stacks later authenticate with via OIDC, so it can't use
  # OIDC against something that doesn't exist yet.
}
