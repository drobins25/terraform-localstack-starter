# Zips lambda/handler.py into lambda/handler.zip
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/handler.py"
  output_path = "${path.module}/../lambda/handler.zip"
}

# Minimal execution role; LocalStack is lenient, but keep this for AWS parity
resource "aws_iam_role" "lambda_exec" {
  name = "${var.project}-${var.env}-lambda-exec"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action   = "sts:AssumeRole"
    }]
  })
}

resource "aws_lambda_function" "echo" {
  function_name = "${var.project}-${var.env}-echo"
  role          = aws_iam_role.lambda_exec.arn
  filename      = data.archive_file.lambda_zip.output_path
  handler       = "handler.handler"
  runtime       = "python3.11"
  timeout       = 5
  environment { variables = { STAGE = var.env } }
  source_code_hash = filebase64sha256("${path.module}/../lambda/handler.py")
}

# Wire SQS → Lambda
resource "aws_lambda_event_source_mapping" "jobs_to_lambda" {
  event_source_arn = aws_sqs_queue.jobs.arn
  function_name    = aws_lambda_function.echo.arn
  batch_size       = 1
  enabled          = true
}

output "lambda_name" {
  value = aws_lambda_function.echo.function_name
}
