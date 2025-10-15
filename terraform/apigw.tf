# REST API container
resource "aws_api_gateway_rest_api" "api" {
  name = "${var.project}-${var.env}-api"
}

# /echo path
resource "aws_api_gateway_resource" "echo" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "echo"
}

# GET /echo
resource "aws_api_gateway_method" "get_echo" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.echo.id
  http_method   = "GET"
  authorization = "NONE"
}

# Integrate GET /echo → Lambda (proxy)
resource "aws_api_gateway_integration" "get_echo" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.echo.id
  http_method             = aws_api_gateway_method.get_echo.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  # Standard APIGW→Lambda URI format (works in LocalStack too)
  uri = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/${aws_lambda_function.echo.arn}/invocations"
}

# Allow API Gateway to invoke the Lambda
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.echo.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

# Deploy + Stage
# force redeploy when routes/integrations change
resource "aws_api_gateway_deployment" "api" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  triggers = {
    redeploy = sha1(jsonencode({
      m = aws_api_gateway_method.get_echo.id
      i = aws_api_gateway_integration.get_echo.id
      r = aws_api_gateway_resource.echo.id
      items_m = aws_api_gateway_method.get_item.id
      items_i = aws_api_gateway_integration.get_item.id
      items_r = aws_api_gateway_resource.items_id.id
      list_m   = aws_api_gateway_method.list_items.id
      list_i   = aws_api_gateway_integration.list_items.id
      post_m   = aws_api_gateway_method.post_item.id
      post_i   = aws_api_gateway_integration.post_item.id
      put_m    = aws_api_gateway_method.put_item.id
      put_i    = aws_api_gateway_integration.put_item.id
      del_m    = aws_api_gateway_method.delete_item.id
      del_i    = aws_api_gateway_integration.delete_item.id
    }))
  }
  depends_on = [
    aws_api_gateway_integration.get_echo,
    aws_api_gateway_integration.get_item,
    aws_api_gateway_integration.list_items,
    aws_api_gateway_integration.post_item,
    aws_api_gateway_integration.put_item,
    aws_api_gateway_integration.delete_item
  ]
  # 👇 ensure new deployment is created before the old is destroyed
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "dev" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  deployment_id = aws_api_gateway_deployment.api.id
  stage_name    = "dev"
}

# LocalStack invoke URL pattern for REST APIs
output "apigw_invoke_url" {
  value = "http://localhost:4566/restapis/${aws_api_gateway_rest_api.api.id}/dev/_user_request_/echo"
}
