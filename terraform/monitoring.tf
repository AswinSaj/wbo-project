# CloudWatch Dashboard for WBO Monitoring
resource "aws_cloudwatch_dashboard" "wbo_dashboard" {
  dashboard_name = "WBO-Monitoring-Dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", { stat = "Average", label = "CPU Utilization" }],
            [".", "MemoryUtilization", { stat = "Average", label = "Memory Utilization" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ECS Service CPU & Memory"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", { stat = "Average", label = "Response Time" }],
            [".", "RequestCount", { stat = "Sum", label = "Request Count" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ALB Performance Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", { stat = "Average", label = "Healthy Hosts" }],
            [".", "UnHealthyHostCount", { stat = "Average", label = "Unhealthy Hosts" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Target Health"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ElastiCache", "CPUUtilization", { stat = "Average", label = "Redis CPU" }],
            [".", "NetworkBytesIn", { stat = "Sum", label = "Network In" }],
            [".", "NetworkBytesOut", { stat = "Sum", label = "Network Out" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Redis Performance"
        }
      },
      {
        type = "log"
        properties = {
          query   = "SOURCE '${aws_cloudwatch_log_group.wbo_logs.name}' | fields @timestamp, @message | sort @timestamp desc | limit 20"
          region  = var.aws_region
          title   = "Recent Application Logs"
          stacked = false
        }
      }
    ]
  })
}

# CloudWatch Alarms
# Alarm for High CPU Usage
resource "aws_cloudwatch_metric_alarm" "ecs_high_cpu" {
  alarm_name          = "wbo-ecs-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "This metric monitors ECS CPU utilization"
  alarm_actions       = [] # Add SNS topic ARN here for notifications

  dimensions = {
    ClusterName = aws_ecs_cluster.wbo_cluster.name
    ServiceName = aws_ecs_service.wbo_service.name
  }

  tags = {
    Name        = "wbo-high-cpu-alarm"
    Environment = var.environment
  }
}

# Alarm for High Memory Usage
resource "aws_cloudwatch_metric_alarm" "ecs_high_memory" {
  alarm_name          = "wbo-ecs-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 90
  alarm_description   = "This metric monitors ECS memory utilization"
  alarm_actions       = [] # Add SNS topic ARN here for notifications

  dimensions = {
    ClusterName = aws_ecs_cluster.wbo_cluster.name
    ServiceName = aws_ecs_service.wbo_service.name
  }

  tags = {
    Name        = "wbo-high-memory-alarm"
    Environment = var.environment
  }
}

# Alarm for Unhealthy Targets
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name          = "wbo-alb-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "Alert when there are unhealthy targets"
  alarm_actions       = [] # Add SNS topic ARN here for notifications

  dimensions = {
    LoadBalancer = aws_lb.wbo_alb.arn_suffix
    TargetGroup  = aws_lb_target_group.wbo_tg.arn_suffix
  }

  tags = {
    Name        = "wbo-unhealthy-hosts-alarm"
    Environment = var.environment
  }
}

# Alarm for High ALB Response Time
resource "aws_cloudwatch_metric_alarm" "alb_high_response_time" {
  alarm_name          = "wbo-alb-high-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = 1.0
  alarm_description   = "Alert when ALB response time is high"
  alarm_actions       = [] # Add SNS topic ARN here for notifications

  dimensions = {
    LoadBalancer = aws_lb.wbo_alb.arn_suffix
  }

  tags = {
    Name        = "wbo-high-response-time-alarm"
    Environment = var.environment
  }
}

# Optional: SNS Topic for Alarm Notifications
# resource "aws_sns_topic" "wbo_alarms" {
#   name = "wbo-alarms-topic"
#
#   tags = {
#     Name        = "wbo-alarms"
#     Environment = var.environment
#   }
# }
#
# resource "aws_sns_topic_subscription" "wbo_alarms_email" {
#   topic_arn = aws_sns_topic.wbo_alarms.arn
#   protocol  = "email"
#   endpoint  = var.alarm_email
# }
