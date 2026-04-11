output "table_name" {
  description = "the name of the dynamodb table"
  value       = aws_dynamodb_table.resource_state.name
}

output "table_arn" {
  description = "the ARN of the dynamodb table"
  value       = aws_dynamodb_table.resource_state.arn
}