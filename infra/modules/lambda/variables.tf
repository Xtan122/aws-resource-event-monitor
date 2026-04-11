variable "function_name" {
  description = "the name of function"
  type        = string
}

variable "lambda_zip_path" {
  description = "the path to the zip file containing the lambda function code"
  type        = string
}

variable "source_code_hash" {
  description = "the base64-encoded SHA256 hash of the zip file containing the lambda function code"
  type        = string

}

variable "handler" {
  default = "processor.lambda_handler"
  type    = string
}

variable "runtime" {
  default = "python3.12"
  type    = string

}

variable "environment_variables" {
  type    = map(string)
  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for publishing notifications"
  type        = string
}

variable "dynamodb_table_arn" {
  description = "DynamoDB table ARN for writing latest state"
  type        = string
}

variable "archive_bucket_arn" {
  description = "S3 archive bucket ARN for storing raw and normalized events"
  type        = string
}