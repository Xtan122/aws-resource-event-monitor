locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

data "archive_file" "processor_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../src/handlers/processor.py"
  output_path = "${path.module}/../build/processor_lambda.zip"
}

resource "aws_s3_bucket" "events_archive" {
  bucket = "${local.name_prefix}-events-archive"
}

resource "aws_s3_bucket_versioning" "events_archive" {
  bucket = aws_s3_bucket.events_archive.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "events_archive" {
  bucket = aws_s3_bucket.events_archive.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "events_archive" {
  bucket = aws_s3_bucket.events_archive.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

module "dynamodb" {
  source = "./modules/dynamodb"

  table_name = "${local.name_prefix}-dynamodb-table"
  tags       = local.common_tags
}

module "lambda" {
  source             = "./modules/lambda"
  function_name      = "${local.name_prefix}-processor"
  lambda_zip_path    = data.archive_file.processor_lambda_zip.output_path
  source_code_hash   = data.archive_file.processor_lambda_zip.output_base64sha256
  sns_topic_arn      = module.notifications.topic_arn
  dynamodb_table_arn = module.dynamodb.table_arn
  archive_bucket_arn = aws_s3_bucket.events_archive.arn

  environment_variables = {
    APP_ENV        = var.environment
    ENV            = var.environment
    SNS_TOPIC_ARN  = module.notifications.topic_arn
    DYNAMODB_TABLE = module.dynamodb.table_name
    ARCHIVE_BUCKET = aws_s3_bucket.events_archive.bucket
  }

  tags = local.common_tags
}

module "eventbridge" {
  source = "./modules/eventbridge"

  event_bus_name       = "${local.name_prefix}-event-bus"
  lambda_target_arn    = module.lambda.lambda_function_arn
  lambda_function_name = module.lambda.lambda_function_name

  tags = local.common_tags
}

module "notifications" {
  source       = "./modules/notifications"
  topic_name   = "${local.name_prefix}-alerts"
  email_target = null # for development

  tags = local.common_tags
}