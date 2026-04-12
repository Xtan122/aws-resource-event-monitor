variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "environment" {
  description = "Environment"
  type        = string
}

variable "slack_team_id" {
  type = string
}

variable "slack_channel_id" {
  type = string
}