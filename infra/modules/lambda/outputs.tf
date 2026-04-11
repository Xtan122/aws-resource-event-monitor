output "lambda_function_name" {
  description = "the name of the lambda function"
  value       = aws_lambda_function.resource_state.function_name
}

output "lambda_function_arn" {
  description = "the ARN of the lambda function"
  value       = aws_lambda_function.resource_state.arn
}

output "lambda_role_arn" {
  description = "the ARN of the lambda execution role"
  value       = aws_iam_role.iam_for_lambda.arn
}