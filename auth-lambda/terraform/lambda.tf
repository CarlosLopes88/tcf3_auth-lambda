provider "aws" {
  region = "us-east-1"
}

# Variável para o MongoDB URI
variable "mongo_uri" {
  description = "MongoDB connection URI"
  type        = string
}

resource "aws_lambda_function" "auth_lambda" {
  function_name    = "authLambda"
  filename         = "${path.module}/function.zip"  # Certifique-se de usar o caminho correto
  source_code_hash = filebase64sha256("${path.module}/function.zip")  # Usando o caminho do zip
  handler          = "authLambda.handler"
  runtime          = "nodejs20.x"
  role             = aws_iam_role.lambda_exec.arn

  environment {
    variables = {
      MONGO_URI = var.mongo_uri
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name = "lambda-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_api_gateway_rest_api" "auth_api" {
  name        = "Auth API"
  description = "API para autenticar cliente com CPF"
}

resource "aws_api_gateway_resource" "auth_resource" {
  rest_api_id = aws_api_gateway_rest_api.auth_api.id
  parent_id   = aws_api_gateway_rest_api.auth_api.root_resource_id
  path_part   = "auth"
}

resource "aws_api_gateway_method" "auth_post" {
  rest_api_id   = aws_api_gateway_rest_api.auth_api.id
  resource_id   = aws_api_gateway_resource.auth_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "auth_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.auth_api.id
  resource_id             = aws_api_gateway_resource.auth_resource.id
  http_method             = aws_api_gateway_method.auth_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.auth_lambda.invoke_arn
}

resource "aws_lambda_permission" "auth_api_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auth_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.auth_api.execution_arn}/*/POST/auth"
}

# Anexar a política básica de execução da Lambda (CloudWatch logs)
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# (Opcional) Política para acesso a outros serviços AWS (ex: acessar DocumentDB ou S3)
resource "aws_iam_role_policy_attachment" "lambda_access_docdb" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDocDBFullAccess"  # Substitua com a política necessária
}

output "lambda_exec_role_arn" {
  description = "ARN da role Lambda"
  value       = aws_iam_role.lambda_exec.arn
}