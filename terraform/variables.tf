variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1" # Free tier eligible
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "wbo"
}

# Redis Configuration
variable "redis_node_type" {
  description = "ElastiCache node type (use cache.t3.micro for free tier)"
  type        = string
  default     = "cache.t3.micro" # Free tier eligible
}

# ECS Configuration
variable "ecs_task_cpu" {
  description = "CPU units for ECS task (256 = 0.25 vCPU)"
  type        = string
  default     = "256" # Minimum for Fargate
}

variable "ecs_task_memory" {
  description = "Memory for ECS task in MB"
  type        = string
  default     = "512" # Minimum for Fargate
}

variable "ecs_desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2 # Start with 2 for high availability
}

variable "ecs_min_capacity" {
  description = "Minimum number of ECS tasks"
  type        = number
  default     = 1 # Can scale down to 1 to save costs
}

variable "ecs_max_capacity" {
  description = "Maximum number of ECS tasks"
  type        = number
  default     = 10 # Scale up based on demand
}

# Optional: SSL Certificate ARN
# variable "ssl_certificate_arn" {
#   description = "ARN of SSL certificate for HTTPS"
#   type        = string
#   default     = ""
# }

# Optional: Alarm Email
# variable "alarm_email" {
#   description = "Email address for CloudWatch alarms"
#   type        = string
#   default     = ""
# }
