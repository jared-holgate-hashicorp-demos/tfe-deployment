resource "random_password" "rds_username" {
  length      = 20
  min_lower   = 1
  min_upper   = 1
  numeric     = false
  lower       = true
  upper       = true
  special     = false
}

resource "random_password" "rds_password" {
  length      = 20
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
  numeric     = true
  lower       = true
  upper       = true
  special     = false
}

resource "aws_db_subnet_group" "rds" {
  name       = "${var.friendly_name_prefix}-tfedb-sg"
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_db_instance" "postgresql" {
  allocated_storage           = 20
  engine                      = "postgres"
  instance_class              = var.rds_instance_type
  password                    = random_password.rds_password.result
  username                    = random_password.rds_username.result
  allow_major_version_upgrade = false
  apply_immediately           = true
  auto_minor_version_upgrade  = true
  backup_retention_period     = 0
  backup_window               = null
  db_subnet_group_name        = aws_db_subnet_group.rds.name
  delete_automated_backups    = true
  deletion_protection         = false
  engine_version              = "12.11"
  identifier_prefix           = "${var.friendly_name_prefix}-tfedb"
  max_allocated_storage       = 0
  multi_az                    = true
  db_name                     = "tfedb"
  port                        = 5432
  publicly_accessible         = false
  skip_final_snapshot         = true
  storage_encrypted           = true
  storage_type                = "gp2"
  vpc_security_group_ids      = [aws_security_group.rds.id]

  tags = {
    Name = "${var.friendly_name_prefix}-tfedb"
  }
}
