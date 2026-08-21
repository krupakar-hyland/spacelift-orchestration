output "stack_ids" {
  description = "Map of stack name to Spacelift stack ID, for every stack created here."
  value       = { for k, s in spacelift_stack.this : k => s.id }
}

output "context_ids" {
  description = "Map of context name to Spacelift context ID."
  value = merge(
    { azure = spacelift_context.azure.id },
    { for k, c in spacelift_context.env : "env-${k}" => c.id }
  )
}

output "identity_client_ids" {
  description = "Map of environment tier to managed identity client ID — useful for spot-checking against ARM_CLIENT_ID on a stack."
  value       = { for k, i in azurerm_user_assigned_identity.env : k => i.client_id }
}

output "federated_credential_count" {
  description = "Total federated credentials created — should equal (number of stacks) x 5."
  value       = length(azurerm_federated_identity_credential.this)
}
