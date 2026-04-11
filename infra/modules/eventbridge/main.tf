resource "aws_cloudwatch_event_bus" "event_bus" {
  name = var.event_bus_name
  log_config {
    include_detail = "FULL"
    level          = "TRACE"
  }

  tags = var.tags
}

resource "aws_cloudwatch_event_rule" "cloudtrail_critical_events" {
  name           = "cloudtrail-critical-events"
  description    = "get from cloudtrail when critical events happen"
  event_bus_name = aws_cloudwatch_event_bus.event_bus.name
  event_pattern = jsonencode({
    source      = ["aws.cloudtrail", "custom.cloudtrail"]
    detail-type = ["AWS API Call via CloudTrail"]
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_rule" "config_changes" {
  name           = "config-changes"
  description    = "get from config when configuration changes happen"
  event_bus_name = aws_cloudwatch_event_bus.event_bus.name
  event_pattern = jsonencode({
    source      = ["aws.config"]
    detail-type = ["Configuration Item Change"]
  })

  tags = var.tags
}

# Add Lambda function as the target of the above rules
resource "aws_cloudwatch_event_target" "lambda_target_cloudtrail" {
  arn            = var.lambda_target_arn
  rule           = aws_cloudwatch_event_rule.cloudtrail_critical_events.name
  target_id      = "lambda-cloudtrail-target"
  event_bus_name = aws_cloudwatch_event_bus.event_bus.name
}

resource "aws_cloudwatch_event_target" "lambda_target_config" {
  arn            = var.lambda_target_arn
  rule           = aws_cloudwatch_event_rule.config_changes.name
  target_id      = "lambda-config-target"
  event_bus_name = aws_cloudwatch_event_bus.event_bus.name

}

# Permission for EventBridge to invoke Lambda function when CloudTrail critical events happen
resource "aws_lambda_permission" "allow_eventbridge_to_invoke_lambda_cloudtrail" {
  statement_id  = "AllowExecutionFromEventBridgeCloudTrail"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "events.amazonaws.com"

  source_arn = aws_cloudwatch_event_rule.cloudtrail_critical_events.arn
}

resource "aws_lambda_permission" "allow_eventbridge_to_invoke_lambda_config" {
  statement_id  = "AllowExecutionFromEventBridgeConfig"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "events.amazonaws.com"

  source_arn = aws_cloudwatch_event_rule.config_changes.arn
}

