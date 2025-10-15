# Zip the listener code
data "archive_file" "ddb_listener_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/ddb_listener.py"
  output_path = "${path.module}/../lambda/ddb_listener.zip"
}

# Reuse the same exec role created for the echo function
# Potentially use a different role for this function?
resource "aws_lambda_function" "ddb_listener" {
  function_name = "${var.project}-${var.env}-ddb-listener"
  role          = aws_iam_role.lambda_exec.arn
  filename      = data.archive_file.ddb_listener_zip.output_path
  handler       = "ddb_listener.handler"
  runtime       = "python3.11"
  timeout       = 5
  source_code_hash = filebase64sha256("${path.module}/../lambda/ddb_listener.py")
}

# Wire table's stream to the listener
resource "aws_lambda_event_source_mapping" "ddb_to_listener" {
  event_source_arn  = aws_dynamodb_table.items.stream_arn
  function_name     = aws_lambda_function.ddb_listener.arn
  starting_position = "LATEST"
  batch_size        = 1
  enabled           = true
}

# Handy output
output "ddb_listener_name" {
  value = aws_lambda_function.ddb_listener.function_name
}
