resource "aws_kms_key" "data" {
  description             = "This key is used to encrypt bucket objects"
  deletion_window_in_days = 10
}

resource "aws_iam_instance_profile" "tfe" {
  name_prefix = "${var.friendly_name_prefix}-tfe"
  role        = aws_iam_role.instance_role.name
}

resource "aws_iam_role" "instance_role" {
  name_prefix        = "${var.friendly_name_prefix}-tfe"
  assume_role_policy = data.aws_iam_policy_document.instance_role.json
}

data "aws_iam_policy_document" "instance_role" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_s3_bucket" "tfe_data_bucket" {
  bucket = "${var.friendly_name_prefix}-tfe-data"
  acl    = "private"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.data.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }

  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "tfe_data" {
  bucket = aws_s3_bucket.tfe_data_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}

data "aws_iam_policy_document" "tfe_data" {
  statement {
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
    ]
    effect = "Allow"
    principals {
      identifiers = [aws_iam_instance_profile.tfe.arn]
      type        = "AWS"
    }
    resources = [aws_s3_bucket.tfe_data_bucket.arn]
    sid       = "AllowS3ListBucketData"
  }

  statement {
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:PutObject",
    ]
    effect = "Allow"
    principals {
      identifiers = [aws_iam_instance_profile.tfe.arn]
      type        = "AWS"
    }
    resources = ["${aws_s3_bucket.tfe_data_bucket.arn}/*"]
    sid       = "AllowS3ManagementData"
  }
}

resource "aws_s3_bucket_policy" "tfe_data" {
  # Depending on aws_s3_bucket_public_access_block.tfe_data avoids an error due to conflicting, simultaneous operations
  # against the bucket.
  bucket = aws_s3_bucket_public_access_block.tfe_data.bucket
  policy = data.aws_iam_policy_document.tfe_data.json
}