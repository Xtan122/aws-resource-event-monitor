variable "event_bus_name" {
  description = "the name of eventbus"
  type        = string
}

variable "lambda_target_arn" {
  type = string
}

variable "lambda_function_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}