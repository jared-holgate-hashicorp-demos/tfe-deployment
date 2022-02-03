output "replicated_password" {
  value = nonsensitive(random_password.replicated.result)
}

output "tfe_password" {
  value = nonsensitive(random_password.tfe.result)
}

output "rds_username" {
  value = nonsensitive(random_password.rds_username.result)
}


output "rds_password" {
  value = nonsensitive(random_password.rds_password.result)
}