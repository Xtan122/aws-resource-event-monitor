output "archive_bucket_name" {
  description = "the name of the s3 bucket"
  value       = aws_s3_bucket.events_archive.bucket
}

output "dynamodb_table_name" {
  description = "the name of the dynamodb table"
  value       = module.dynamodb.table_name

}

output "dynamodb_table_arn" {
  description = "the ARN of the dynamodb table"
  value       = module.dynamodb.table_arn
}

output "name_prefix" {
  description = "the prefix of the resource names"
  value       = local.name_prefix
}

output "sns_topic_arn" {
  value = module.notifications.topic_arn
}