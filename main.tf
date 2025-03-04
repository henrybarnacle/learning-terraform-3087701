data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["bitnami-tomcat-*-x86_64-hvm-ebs-nami"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["979382823631"] # Bitnami
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda Function
resource "aws_lambda_function" "xx-lambda" {
  function_name = "xx-lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  package_type  = "Zip"
  s3_bucket     = "my-lambda-bucket88"
  s3_key        = "lambda_function_payload.zip"
  runtime       = "nodejs18.x"

  environment {
    variables = {
      STAGE = "test"
    }
  }

}

# API Gateway
resource "aws_api_gateway_rest_api" "rates-api" {
  name        = "rates-api"
  description = "API for my Lambda function"
}

# Proxy resource
resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.rates-api.id
  parent_id   = aws_api_gateway_rest_api.rates-api.root_resource_id
  path_part   = "getRates"
}

# POST method
resource "aws_api_gateway_method" "proxy_method" {
  rest_api_id   = aws_api_gateway_rest_api.rates-api.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "POST"
  authorization = "NONE"
}

# Lambda integration
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.rates-api.id
  resource_id             = aws_api_gateway_resource.proxy.id
  http_method             = aws_api_gateway_method.proxy_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.xx-lambda.invoke_arn
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.xx-lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.rates-api.execution_arn}/*/*"
}

# Deploy API Gateway
resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [aws_api_gateway_integration.lambda_integration]
  
  rest_api_id = aws_api_gateway_rest_api.rates-api.id
}

output "api_invoke_url" {
  value = "${aws_api_gateway_rest_api.rates-api.execution_arn}/test"
}
