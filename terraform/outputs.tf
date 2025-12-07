output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.wbo_alb.dns_name
}

output "alb_url" {
  description = "URL to access the WBO application"
  value       = "http://${aws_lb.wbo_alb.dns_name}"
}

output "s3_bucket_name" {
  description = "S3 bucket for board persistence"
  value       = aws_s3_bucket.wbo_storage.id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.wbo_cluster.name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.wbo_service.name
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group for application logs"
  value       = aws_cloudwatch_log_group.wbo_logs.name
}

output "cloudwatch_dashboard_url" {
  description = "URL to CloudWatch dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.wbo_dashboard.dashboard_name}"
}
