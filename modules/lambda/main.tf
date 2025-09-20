# S3 Bucket for uploads
resource "aws_s3_bucket" "uploads" {
  bucket = var.s3_bucket_name

  tags = {
    Name = "${var.project_name}-${var.environment}-uploads"
  }
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Lifecycle Configuration
resource "aws_s3_bucket_lifecycle_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  rule {
    id     = "delete_old_uploads"
    status = "Enabled"

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 1
    }
  }
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "uploads" {
  bucket = aws_s3_bucket.uploads.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Lambda function ZIP file
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"
  source {
    content = file("${path.module}/lambda_function.py")
    filename = "lambda_function.py"
  }
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-upload-handler"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-${var.environment}-lambda-logs"
  }
}

# Lambda Function
resource "aws_lambda_function" "upload_handler" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.project_name}-${var.environment}-upload-handler"
  role            = var.lambda_execution_role_arn
  handler         = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime         = "python3.9"
  timeout         = 30

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.uploads.bucket
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_logs]

  tags = {
    Name = "${var.project_name}-${var.environment}-upload-handler"
  }
}

# API Gateway HTTP API
resource "aws_apigatewayv2_api" "upload_api" {
  name          = "${var.project_name}-${var.environment}-upload-api"
  protocol_type = "HTTP"
  description   = "API for file uploads"

  cors_configuration {
    allow_credentials = false
    allow_headers     = ["content-type", "x-amz-date", "authorization", "x-api-key"]
    allow_methods     = ["POST", "OPTIONS"]
    allow_origins     = ["*"]
    max_age          = 86400
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-upload-api"
  }
}

# API Gateway Stage
resource "aws_apigatewayv2_stage" "upload_api" {
  api_id      = aws_apigatewayv2_api.upload_api.id
  name        = "demo"
  auto_deploy = true

  tags = {
    Name = "${var.project_name}-${var.environment}-upload-api-stage"
  }
}

# API Gateway Integration
resource "aws_apigatewayv2_integration" "upload_integration" {
  api_id             = aws_apigatewayv2_api.upload_api.id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.upload_handler.invoke_arn
}

# API Gateway Route
resource "aws_apigatewayv2_route" "upload_route" {
  api_id    = aws_apigatewayv2_api.upload_api.id
  route_key = "POST /upload"
  target    = "integrations/${aws_apigatewayv2_integration.upload_integration.id}"
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.upload_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.upload_api.execution_arn}/*/*"
}