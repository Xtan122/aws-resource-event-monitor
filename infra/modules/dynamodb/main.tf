resource "aws_dynamodb_table" "resource_state" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"
  range_key    = "sk"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  attribute {
    name = "service"
    type = "S"
  }
  attribute {
    name = "event_time"
    type = "S"
  }

  global_secondary_index {
    name            = "gsi_service_event_time"
    projection_type = "ALL"

    key_schema {
      attribute_name = "service"
      key_type       = "HASH"
    }

    key_schema {
      attribute_name = "event_time"
      key_type       = "RANGE"
    }
  }

  tags = var.tags
}