# Data sources
data "aws_iot_endpoint" "current" {
  endpoint_type = "iot:Data-ATS"
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Local variables
locals {
  rule_name = "${var.project_name}_telemetry_to_firehose_${var.environment}"
}

# ============================================================================
# AWS IoT Things (one per vehicle)
# ============================================================================

resource "aws_iot_thing" "vehicle" {
  for_each = toset(var.vehicle_ids)

  name = each.value

  attributes = {
    environment  = var.environment
    project      = var.project_name
    vehicle_type = "sports_car"
  }
}

# ============================================================================
# AWS IoT Certificates (X.509)
# ============================================================================

resource "aws_iot_certificate" "vehicle" {
  for_each = var.create_certificates ? toset(var.vehicle_ids) : toset([])

  active = true
}

# Attach certificate to thing
resource "aws_iot_thing_principal_attachment" "vehicle" {
  for_each = var.create_certificates ? toset(var.vehicle_ids) : toset([])

  thing     = aws_iot_thing.vehicle[each.key].name
  principal = aws_iot_certificate.vehicle[each.key].arn
}

# ============================================================================
# AWS IoT Policy (Least Privilege)
# ============================================================================

resource "aws_iot_policy" "vehicle_telemetry" {
  name = "${var.project_name}-vehicle-telemetry-${var.environment}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iot:Connect"
        ]
        Resource = [
          "arn:aws:iot:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:client/$${iot:Connection.Thing.ThingName}"
        ]
        Condition = {
          Bool = {
            "iot:Connection.Thing.IsAttached" = "true"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "iot:Publish"
        ]
        Resource = [
          "arn:aws:iot:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:topic/car/$${iot:Connection.Thing.ThingName}/telemetry"
        ]
      },
      {
        Effect = "Deny"
        Action = [
          "iot:Subscribe",
          "iot:Receive"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach policy to certificates
resource "aws_iot_policy_attachment" "vehicle" {
  for_each = var.create_certificates ? toset(var.vehicle_ids) : toset([])

  policy = aws_iot_policy.vehicle_telemetry.name
  target = aws_iot_certificate.vehicle[each.key].arn
}

# ============================================================================
# AWS IoT Topic Rule (Route to Firehose)
# ============================================================================

resource "aws_iot_topic_rule" "telemetry_to_firehose" {
  name        = local.rule_name
  description = "Route telemetry data from vehicles to Kinesis Firehose"
  enabled     = true
  sql         = "SELECT *, topic(2) as vehicle_id, timestamp() as timestamp FROM '${var.topic_pattern}'"
  sql_version = "2016-03-23"

  firehose {
    delivery_stream_name = split("/", var.firehose_stream_arn)[1]
    role_arn             = var.iot_role_arn
    separator            = "\n"
  }

  error_action {
    cloudwatch_logs {
      log_group_name = aws_cloudwatch_log_group.iot_rule_errors.name
      role_arn       = aws_iam_role.iot_rule_logging.arn
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-telemetry-rule-${var.environment}"
  })

  depends_on = [aws_cloudwatch_log_group.iot_rule_errors]
}

# ============================================================================
# CloudWatch Logs for IoT Rule Errors
# ============================================================================

resource "aws_cloudwatch_log_group" "iot_rule_errors" {
  name              = "/aws/iot/rules/${local.rule_name}/errors"
  retention_in_days = var.environment == "prod" ? 90 : 30

  tags = merge(var.tags, {
    Name = "${var.project_name}-iot-rule-errors-${var.environment}"
  })
}

resource "aws_cloudwatch_log_group" "iot_rule_actions" {
  name              = "/aws/iot/rules/${local.rule_name}/actions"
  retention_in_days = var.environment == "prod" ? 90 : 7

  tags = merge(var.tags, {
    Name = "${var.project_name}-iot-rule-actions-${var.environment}"
  })
}

# ============================================================================
# IAM Role for IoT Rule CloudWatch Logging
# ============================================================================

resource "aws_iam_role" "iot_rule_logging" {
  name = "${var.project_name}-iot-rule-logging-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "iot.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-iot-rule-logging-${var.environment}"
  })
}

resource "aws_iam_role_policy" "iot_rule_logging" {
  name = "${var.project_name}-iot-rule-logging-policy-${var.environment}"
  role = aws_iam_role.iot_rule_logging.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = [
        aws_cloudwatch_log_group.iot_rule_errors.arn,
        "${aws_cloudwatch_log_group.iot_rule_errors.arn}:*",
        aws_cloudwatch_log_group.iot_rule_actions.arn,
        "${aws_cloudwatch_log_group.iot_rule_actions.arn}:*"
      ]
    }]
  })
}

# ============================================================================
# CloudWatch Alarms
# ============================================================================

# Alarm: Topic Rule Errors
resource "aws_cloudwatch_metric_alarm" "topic_rule_errors" {
  alarm_name          = "${var.project_name}-iot-topic-rule-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RuleMessageThrottled"
  namespace           = "AWS/IoT"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "IoT Topic Rule experiencing errors or throttling"
  treat_missing_data  = "notBreaching"

  dimensions = {
    RuleName = aws_iot_topic_rule.telemetry_to_firehose.name
  }

  tags = merge(var.tags, {
    Name     = "${var.project_name}-iot-rule-errors-alarm-${var.environment}"
    Severity = "high"
  })
}

# Alarm: No Messages Received
resource "aws_cloudwatch_log_metric_filter" "no_messages" {
  name           = "${var.project_name}-iot-no-messages-${var.environment}"
  log_group_name = aws_cloudwatch_log_group.iot_rule_actions.name
  pattern        = ""

  metric_transformation {
    name      = "IoTRuleInvocations"
    namespace = "RedlineTelemetry/IoT"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "no_messages" {
  alarm_name          = "${var.project_name}-iot-no-messages-${var.environment}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "IoTRuleInvocations"
  namespace           = "RedlineTelemetry/IoT"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "No telemetry messages received for 15 minutes"
  treat_missing_data  = "breaching"

  tags = merge(var.tags, {
    Name     = "${var.project_name}-iot-no-messages-alarm-${var.environment}"
    Severity = "medium"
  })
}
