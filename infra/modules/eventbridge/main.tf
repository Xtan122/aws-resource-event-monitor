resource "aws_cloudwatch_event_bus" "event_bus" {
  name = var.event_bus_name
  log_config {
    include_detail = "FULL"
    level          = "TRACE"
  }

  tags = var.tags
}

resource "aws_iam_role" "default_bus_forwarder_role" {
  name = "${var.event_bus_name}-default-forwarder-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "default_bus_forwarder_policy" {
  name = "${var.event_bus_name}-default-forwarder-policy"
  role = aws_iam_role.default_bus_forwarder_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["events:PutEvents"]
        Resource = aws_cloudwatch_event_bus.event_bus.arn
      }
    ]
  })
}

# AWS service events (CloudTrail/Config) are emitted to the default bus.
# Forward them to the custom bus so existing processing rules can match.
resource "aws_cloudwatch_event_rule" "default_bus_forward_cloudtrail" {
  name           = "default-forward-cloudtrail"
  description    = "forward cloudtrail api events from default bus to custom bus"
  event_bus_name = "default"

  event_pattern = jsonencode({
    detail-type = ["AWS API Call via CloudTrail"]
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "forward_cloudtrail_to_custom_bus" {
  rule           = aws_cloudwatch_event_rule.default_bus_forward_cloudtrail.name
  event_bus_name = "default"
  target_id      = "forward-cloudtrail-to-custom-bus"
  arn            = aws_cloudwatch_event_bus.event_bus.arn
  role_arn       = aws_iam_role.default_bus_forwarder_role.arn
}

resource "aws_cloudwatch_event_rule" "default_bus_forward_config" {
  name           = "default-forward-config"
  description    = "forward config change events from default bus to custom bus"
  event_bus_name = "default"

  event_pattern = jsonencode({
    source      = ["aws.config"]
    detail-type = ["Configuration Item Change"]
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "forward_config_to_custom_bus" {
  rule           = aws_cloudwatch_event_rule.default_bus_forward_config.name
  event_bus_name = "default"
  target_id      = "forward-config-to-custom-bus"
  arn            = aws_cloudwatch_event_bus.event_bus.arn
  role_arn       = aws_iam_role.default_bus_forwarder_role.arn
}

resource "aws_cloudwatch_event_rule" "cloudtrail_critical_events" {
  name           = "cloudtrail-critical-events"
  description    = "get from cloudtrail when critical events happen"
  event_bus_name = aws_cloudwatch_event_bus.event_bus.name
  event_pattern = jsonencode({
    source      = ["aws.ec2", "aws.s3", "aws.rds", "aws.lambda", "aws.iam", "aws.vpc", "aws.ecs", "custom.cloudtrail"]
    detail-type = ["AWS API Call via CloudTrail"]

    detail = {
      eventSource = [
        "ec2.amazonaws.com",
        "s3.amazonaws.com",
        "rds.amazonaws.com",
        "lambda.amazonaws.com",
        "iam.amazonaws.com",
        "vpc.amazonaws.com",
        "ecs.amazonaws.com"
      ]
    }
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

    detail = {
      configurationItemStatus = [
        "ResourceDiscovered",
        "ResourceDeleted",
        "ResourceUpdated"
      ]
    }
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

