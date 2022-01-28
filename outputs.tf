output "replicated_password" {
  value = nonsensitive(random_password.replicated.result)
}

output "tfe_password" {
  value = nonsensitive(random_password.tfe.result)
}