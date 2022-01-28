output "replicated_password" {
    value = nonsensitive(random_password.replicated.result)
}