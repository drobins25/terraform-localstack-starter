# A dedicated bucket for uploads that trigger Lambda
resource "aws_s3_bucket" "uploads" {
  bucket = "${var.project}-${var.env}-uploads"
  force_destroy = true
}

# Optionally enable versioning
resource "aws_s3_bucket_versioning" "uploads" {
  bucket = aws_s3_bucket.uploads.id
  versioning_configuration { status = "Enabled" }
}

# Zip the listener code
data "archive_file" "s3_listener_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/s3_listener.py"
  output_path = "${path.module}/../lambda/s3_listener.zip"
}

# Reuse existing Lambda exec role
resource "aws_lambda_function" "s3_listener" {
  function_name    = "${var.project}-${var.env}-s3-listener"
  role             = aws_iam_role.lambda_exec.arn
  filename         = data.archive_file.s3_listener_zip.output_path
  handler          = "s3_listener.handler"
  runtime          = "python3.11"
  timeout          = 5
  source_code_hash = filebase64sha256("${path.module}/../lambda/s3_listener.py")
}

# Allow S3 to invoke this Lambda when a new object is created
resource "aws_lambda_permission" "s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_listener.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.uploads.arn
}

# Hook S3 -> Lambda on object created (all keys -> add filters later)
resource "aws_s3_bucket_notification" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_listener.arn
    events              = ["s3:ObjectCreated:*"]
    # optional filters example:
    # filter_prefix      = "incoming/"
    # filter_suffix      = ".json"
  }

  depends_on = [aws_lambda_permission.s3_invoke]
}
 # Handy outputs
output "s3_uploads_bucket" {
  value = aws_s3_bucket.uploads.bucket
}

output "s3_listener_name" {
  value = aws_lambda_function.s3_listener.function_name
}
