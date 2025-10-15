# Package the items API lambda
data "archive_file" "items_api_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/items_api.py"
  output_path = "${path.module}/../lambda/items_api.zip"
}

# Expanded IAM policy so the Lambda can write/scan/delete/update
resource "aws_iam_role_policy" "lambda_ddb_access" {
  name = "${var.project}-${var.env}-lambda-ddb-read"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = [
        "dynamodb:GetItem",
        "dynamodb:Query",
        "dynamodb:PutItem",
        "dynamodb:Scan",
        "dynamodb:DeleteItem",
        "dynamodb:UpdateItem"
      ],
      Resource = [
        aws_dynamodb_table.items.arn,
        "${aws_dynamodb_table.items.arn}/index/*"
      ]
    }]
  })
}


# Lambda that serves GET /items/{id}
resource "aws_lambda_function" "items_api" {
  function_name    = "${var.project}-${var.env}-items-api"
  role             = aws_iam_role.lambda_exec.arn
  filename         = data.archive_file.items_api_zip.output_path
  handler          = "items_api.handler"
  runtime          = "python3.11"
  timeout          = 5
  environment {
    variables = {
      STAGE      = var.env
      TABLE_NAME = aws_dynamodb_table.items.name
      AWS_REGION = "us-east-1"
    }
  }
  source_code_hash = filebase64sha256("${path.module}/../lambda/items_api.py")

  depends_on = [aws_iam_role_policy.lambda_ddb_access]
}

# --- API Gateway: /items/{id} -> items_api (proxy) ---
resource "aws_api_gateway_resource" "items" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "items"
}

resource "aws_api_gateway_resource" "items_id" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.items.id
  path_part   = "{id}"
}

resource "aws_api_gateway_method" "get_item" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.items_id.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_item" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.items_id.id
  http_method             = aws_api_gateway_method.get_item.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/${aws_lambda_function.items_api.arn}/invocations"
}

# GET /items (list) and POST /items (create)
resource "aws_api_gateway_method" "list_items" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.items.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "list_items" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.items.id
  http_method             = aws_api_gateway_method.list_items.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/${aws_lambda_function.items_api.arn}/invocations"
}

resource "aws_api_gateway_method" "post_item" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.items.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "post_item" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.items.id
  http_method             = aws_api_gateway_method.post_item.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/${aws_lambda_function.items_api.arn}/invocations"
}

# PUT /items/{id}
resource "aws_api_gateway_method" "put_item" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.items_id.id
  http_method   = "PUT"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "put_item" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.items_id.id
  http_method             = aws_api_gateway_method.put_item.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/${aws_lambda_function.items_api.arn}/invocations"
}

# DELETE /items/{id}
resource "aws_api_gateway_method" "delete_item" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.items_id.id
  http_method   = "DELETE"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "delete_item" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.items_id.id
  http_method             = aws_api_gateway_method.delete_item.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/${aws_lambda_function.items_api.arn}/invocations"
}

resource "aws_lambda_permission" "apigw_items" {
  statement_id  = "AllowAPIGatewayInvokeItems"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.items_api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

# Reuse existing stage (dev).
# (apigw.tf -> aws_api_gateway_stage.dev)

output "items_api_url" {
  value = "http://localhost:4566/restapis/${aws_api_gateway_rest_api.api.id}/dev/_user_request_/items/{id}"
}
