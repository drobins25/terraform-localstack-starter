output "bucket_name" {
  description = "Artifacts bucket name"
  value       = aws_s3_bucket.artifacts.bucket
}

output "dynamodb_table" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.items.name
}