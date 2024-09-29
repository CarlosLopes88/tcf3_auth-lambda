# Define o provedor da AWS e a região a ser usada.
provider "aws" {
  region = "us-east-1"
}

# Variável que armazena o URI de conexão com o MongoDB.
variable "mongo_uri" {
  description = "MongoDB connection URI"
  type        = string
}

# Recurso para definir a função Lambda que vai realizar a autenticação.
resource "aws_lambda_function" "auth_lambda" {
  function_name    = "authLambda"  # Nome da função Lambda
  filename         = "${path.module}/function.zip"  # Local do arquivo ZIP com o código da função
  source_code_hash = filebase64sha256("${path.module}/function.zip")  # Hash para verificar mudanças no código
  handler          = "authLambda.handler"  # Especifica o método que será chamado quando a função for executada
  runtime          = "nodejs20.x"  # Define o runtime do Lambda, neste caso Node.js 20.x
  role             = aws_iam_role.lambda_exec.arn  # Associa a função Lambda à role IAM (permissões)

  # Configura as variáveis de ambiente, neste caso, passando o URI do MongoDB.
  environment {
    variables = {
      MONGO_URI = var.mongo_uri
    }
  }
}

# Recurso para criar uma role IAM que permite ao Lambda ser executado com as permissões especificadas.
resource "aws_iam_role" "lambda_exec" {
  name = "lambda-exec-role"  # Nome da role
  assume_role_policy = jsonencode({  # Política que permite ao Lambda assumir esta role
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",  # Permissão para assumir a role
        Effect    = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"  # Lambda é o serviço que pode assumir a role
        }
      }
    ]
  })
}

# Recurso para definir a API Gateway que será usada para a autenticação.
resource "aws_api_gateway_rest_api" "auth_api" {
  name        = "Auth API"  # Nome da API
  description = "API para autenticar cliente com CPF"  # Descrição da API
}

# Cria um recurso dentro da API, com o caminho "auth".
resource "aws_api_gateway_resource" "auth_resource" {
  rest_api_id = aws_api_gateway_rest_api.auth_api.id  # ID da API
  parent_id   = aws_api_gateway_rest_api.auth_api.root_resource_id  # ID do recurso pai (raiz)
  path_part   = "auth"  # Caminho específico para o recurso
}

# Define o método POST para o recurso "/auth" na API Gateway.
resource "aws_api_gateway_method" "auth_post" {
  rest_api_id   = aws_api_gateway_rest_api.auth_api.id  # ID da API
  resource_id   = aws_api_gateway_resource.auth_resource.id  # ID do recurso "/auth"
  http_method   = "POST"  # Define o método HTTP como POST
  authorization = "NONE"  # Sem autenticação (pode ser ajustado conforme necessário)
}

# Integração da API Gateway com a função Lambda.
resource "aws_api_gateway_integration" "auth_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.auth_api.id  # ID da API
  resource_id             = aws_api_gateway_resource.auth_resource.id  # ID do recurso "/auth"
  http_method             = aws_api_gateway_method.auth_post.http_method  # Método HTTP POST
  integration_http_method = "POST"  # Método de integração POST
  type                    = "AWS_PROXY"  # Usa proxy para integrar diretamente com o Lambda
  uri                     = aws_lambda_function.auth_lambda.invoke_arn  # ARN da função Lambda que será invocada
}

# Permissão para que a API Gateway possa invocar a função Lambda.
resource "aws_lambda_permission" "auth_api_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"  # ID da política de permissão
  action        = "lambda:InvokeFunction"  # Permite a invocação da função Lambda
  function_name = aws_lambda_function.auth_lambda.function_name  # Nome da função Lambda
  principal     = "apigateway.amazonaws.com"  # API Gateway é o serviço que pode invocar o Lambda
  source_arn    = "${aws_api_gateway_rest_api.auth_api.execution_arn}/*/POST/auth"  # Define a origem como a execução do método POST na API
}

# Anexa uma política básica de execução ao Lambda, que permite gravar logs no CloudWatch.
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec.name  # Nome da role associada ao Lambda
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"  # Política que permite a execução básica do Lambda
}

# (Opcional) Anexa uma política que concede ao Lambda permissão total para acessar o DocumentDB.
resource "aws_iam_role_policy_attachment" "lambda_access_docdb" {
  role       = aws_iam_role.lambda_exec.name  # Nome da role associada ao Lambda
  policy_arn = "arn:aws:iam::aws:policy/AmazonDocDBFullAccess"  # Política que concede acesso completo ao DocumentDB
}

# Exibe como saída o ARN da role do Lambda.
output "lambda_exec_role_arn" {
  description = "ARN da role Lambda"  # Descrição da saída
  value       = aws_iam_role.lambda_exec.arn  # Valor de saída, o ARN da role
}