variable "topic_name" {
  type = string
}

variable "email_target" {
  type     = string
  default  = null
  nullable = true
}

variable "tags" {
  type    = map(string)
  default = {}
}

