# Unique suffix to avoid S3 bucket collisions
resource "random_id" "suffix" {
  byte_length = 2  # 4 hex chars
}

# --- S3 Bucket with secure defaults ---
resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.project}-${var.env}-artifacts-${random_id.suffix.hex}"
  tags   = local.common_tags
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- DynamoDB Table ---
resource "aws_dynamodb_table" "items" {
  name         = "${var.project}-${var.env}-items"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  # Enabling stream for Lambda to react to
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "id"
    type = "S"
  }

  tags = local.common_tags
}