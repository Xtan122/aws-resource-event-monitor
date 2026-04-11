resource "aws_sns_topic" "sns_topic" {
  name = var.topic_name

  tags = var.tags
}

resource "aws_sns_topic_subscription" "sns_topic_subcription" {
  count     = var.email_target == null ? 0 : 1
  topic_arn = aws_sns_topic.sns_topic.arn
  protocol  = "email"
  endpoint  = var.email_target
}