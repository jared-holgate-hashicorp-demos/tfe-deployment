output "replicated_password" {
  value = nonsensitive(random_password.replicated.result)
}

output "tfe_password" {
  value = nonsensitive(random_password.tfe.result)
}

output "rds_endpoint" {
  value = aws_db_instance.postgresql.endpoint
}

output "rds_db_name" {
  value = "tfedb"
}

output "rds_username" {
  value = nonsensitive(random_password.rds_username.result)
}

output "rds_password" {
  value = nonsensitive(random_password.rds_password.result)
}

output "s3_bucket_name" {
  value = aws_s3_bucket.tfe_data_bucket.bucket_domain_name
}

output "s3_bucket_region" {
  value = aws_s3_bucket.tfe_data_bucket.region
}

output "s3_bucket_key_arn" {
  value = aws_kms_key.data.arn
}
