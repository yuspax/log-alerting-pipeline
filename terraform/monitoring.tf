resource "aws_cloudwatch_log_group" "app" {
  name              = "/ec2/${var.project_name}/application"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-${var.environment}-log-group"
  }
}

resource "aws_cloudwatch_log_metric_filter" "errors" {
  name           = "${var.project_name}-${var.environment}-error-filter"
  log_group_name = aws_cloudwatch_log_group.app.name
  pattern        = "?ERROR ?CRITICAL"

  metric_transformation {
    name      = "ErrorCount"
    namespace = "${var.project_name}/errors"
    value     = "1"
    unit      = "Count"
  }
}

resource "aws_cloudwatch_metric_alarm" "errors" {
  alarm_name          = "${var.project_name}-${var.environment}-error-alarm"
  alarm_description   = "Triggers when ERROR or CRITICAL appears in application logs"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ErrorCount"
  namespace           = "${var.project_name}/errors"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = {
    Name = "${var.project_name}-${var.environment}-error-alarm"
  }
}