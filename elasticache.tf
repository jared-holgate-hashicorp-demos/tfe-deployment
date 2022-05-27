resource "random_id" "redis_password" {
  byte_length = 16
}
resource "aws_kms_key" "cache" {
  description             = "This key is used to encrypt bucket objects"
  deletion_window_in_days = 10
}

resource "aws_kms_grant" "cache" {
  grantee_principal = aws_iam_role.instance_role.arn
  key_id            = aws_kms_key.cache.key_id
  operations = [
    "Decrypt",
    "DescribeKey",
    "Encrypt",
    "GenerateDataKey",
    "GenerateDataKeyPair",
    "GenerateDataKeyPairWithoutPlaintext",
    "GenerateDataKeyPairWithoutPlaintext",
    "ReEncryptFrom",
    "ReEncryptTo",
  ]
}

resource "aws_elasticache_subnet_group" "tfe" {
  name       = "${var.friendly_name_prefix}-tfe-redis"
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_elasticache_replication_group" "redis" {
  node_type            = var.elasticache_instance_type
  num_cache_clusters   = 1
  description          = "The replication group of the Redis deployment for TFE."
  replication_group_id = "${var.friendly_name_prefix}-redis"

  apply_immediately          = true
  automatic_failover_enabled = false
  auto_minor_version_upgrade = true
  engine                     = "redis"
  engine_version             = "5.0.6"
  parameter_group_name       = "default.redis5.0"
  port                       = 6379
  security_group_ids         = [aws_security_group.redis.id]
  snapshot_retention_limit   = 0
  subnet_group_name          = aws_elasticache_subnet_group.tfe.name

  auth_token                 = random_id.redis_password.hex
  transit_encryption_enabled = true

  at_rest_encryption_enabled = true
  kms_key_id                 = aws_kms_key.cache.arn
}