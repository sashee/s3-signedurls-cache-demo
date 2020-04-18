provider "aws" {
}

# S3 bucket

resource "aws_s3_bucket" "bucket" {
  force_destroy = "true"
}

resource "aws_s3_bucket_object" "cat" {
  bucket = aws_s3_bucket.bucket.bucket
  key    = "cat.jpg"
  source = "cat.jpg"
}

# Lambda function

resource "random_id" "id" {
  byte_length = 8
}

# run npm ci
data "external" "frontend_build" {
  program = ["bash", "-c", <<EOT
(npm ci) >&2 && echo "{\"dest\": \"\"}"
EOT
  ]
  working_dir = "${path.module}/src"
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "/tmp/${random_id.id.hex}-lambda.zip"
  source_dir  = "${data.external.frontend_build.working_dir}/${data.external.frontend_build.result.dest}"
}

resource "aws_lambda_function" "signer_lambda" {
  function_name = "signer-${random_id.id.hex}-function"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  handler = "index.handler"
  runtime = "nodejs12.x"
  role    = aws_iam_role.lambda_exec.arn
  environment {
    variables = {
      BUCKET = aws_s3_bucket.bucket.bucket
    }
  }
}

data "aws_iam_policy_document" "lambda_exec_role_policy" {
  statement {
    actions = [
      "s3:GetObject",
    ]
    resources = [
      "${aws_s3_bucket.bucket.arn}/*",
    ]
  }
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:*:*:*"
    ]
  }
}

resource "aws_cloudwatch_log_group" "loggroup" {
  name              = "/aws/lambda/${aws_lambda_function.signer_lambda.function_name}"
  retention_in_days = 14
}

resource "aws_iam_role_policy" "lambda_exec_role" {
  role   = aws_iam_role.lambda_exec.id
  policy = data.aws_iam_policy_document.lambda_exec_role_policy.json
}

resource "aws_iam_role" "lambda_exec" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
	{
	  "Action": "sts:AssumeRole",
	  "Principal": {
		"Service": "lambda.amazonaws.com"
	  },
	  "Effect": "Allow"
	}
  ]
}
EOF
}

# API Gateway

resource "aws_api_gateway_rest_api" "rest_api" {
  name = "signer-${random_id.id.hex}-rest-api"
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_rest_api.rest_api.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_method.proxy.resource_id
  http_method = aws_api_gateway_method.proxy.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.signer_lambda.invoke_arn
}

resource "aws_api_gateway_method" "proxy_root" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_rest_api.rest_api.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_root" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_method.proxy_root.resource_id
  http_method = aws_api_gateway_method.proxy_root.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.signer_lambda.invoke_arn
}

resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [
    aws_api_gateway_integration.lambda,
    aws_api_gateway_integration.lambda_root,
  ]

  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  stage_name  = "sign"
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.signer_lambda.arn
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_deployment.deployment.execution_arn}/*/*"
}

output "url" {
  value = "${aws_api_gateway_deployment.deployment.invoke_url}/"
}
