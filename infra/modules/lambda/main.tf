resource "aws_iam_role" "iam_for_lambda" {
  name = "${var.function_name}-iam-role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "lambda_logs_policy" {
  name = "${var.function_name}-logs-policy"
  role = aws_iam_role.iam_for_lambda.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy" "lambda_sns_publish_policy" {
  name = "${var.function_name}-sns-publish-policy"
  role = aws_iam_role.iam_for_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sns:Publish"
        ]
        Effect = "Allow"
        Resource = [
          var.sns_topic_arn
        ]
      },
    ]
  })
}

resource "aws_iam_role_policy" "lambda_data_write_policy" {
  name = "${var.function_name}-data-write-policy"
  role = aws_iam_role.iam_for_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:PutItem"
        ]
        Effect = "Allow"
        Resource = [
          var.dynamodb_table_arn
        ]
      },

      {
        Action = [
          "s3:PutObject"
        ]
        Effect = "Allow"
        Resource = [
          "${var.archive_bucket_arn}/*"
        ]
      },
    ]
  })
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 14

  tags = var.tags
}

resource "aws_lambda_function" "resource_state" {
  filename         = var.lambda_zip_path
  function_name    = var.function_name
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = var.handler
  source_code_hash = var.source_code_hash
  runtime          = var.runtime
  timeout          = var.timeout
  memory_size      = var.memory_size

  environment {
    variables = var.environment_variables
  }

  tags = var.tags
}
