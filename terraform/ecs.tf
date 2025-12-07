# ECS Cluster
resource "aws_ecs_cluster" "wbo_cluster" {
  name = "wbo-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name        = "wbo-cluster"
    Environment = var.environment
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "wbo_logs" {
  name              = "/ecs/wbo"
  retention_in_days = 7 # Free tier: keep logs for 7 days

  tags = {
    Name        = "wbo-logs"
    Environment = var.environment
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "wbo_task" {
  family                   = "wbo-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  # EFS Volume Configuration
  volume {
    name = "wbo-storage"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.wbo_storage.id
      transit_encryption = "ENABLED"
    }
  }

  container_definitions = jsonencode([
    {
      name      = "wbo"
      image     = "lovasoa/wbo:latest"
      essential = true

      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]

      # Mount EFS volume for shared board storage
      mountPoints = [
        {
          sourceVolume  = "wbo-storage"
          containerPath = "/opt/app/server-data"
          readOnly      = false
        }
      ]

      environment = [
        {
          name  = "PORT"
          value = "80"
        },
        {
          name  = "WBO_HISTORY_DIR"
          value = "/opt/app/server-data"
        },
        {
          name  = "WBO_MAX_EMIT_COUNT"
          value = "192"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.wbo_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "wbo"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:80/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name        = "wbo-task"
    Environment = var.environment
  }
}

# ECS Service
resource "aws_ecs_service" "wbo_service" {
  name            = "wbo-service"
  cluster         = aws_ecs_cluster.wbo_cluster.id
  task_definition = aws_ecs_task_definition.wbo_task.arn
  desired_count   = var.ecs_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
    security_groups  = [aws_security_group.ecs_tasks_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.wbo_tg.arn
    container_name   = "wbo"
    container_port   = 80
  }

  depends_on = [
    aws_lb_listener.wbo_http,
    aws_iam_role_policy.ecs_task_s3_policy,
    aws_efs_mount_target.wbo_mount_1,
    aws_efs_mount_target.wbo_mount_2
  ]

  tags = {
    Name        = "wbo-service"
    Environment = var.environment
  }
}

# Auto Scaling Target
resource "aws_appautoscaling_target" "wbo_autoscaling_target" {
  max_capacity       = var.ecs_max_capacity
  min_capacity       = var.ecs_min_capacity
  resource_id        = "service/${aws_ecs_cluster.wbo_cluster.name}/${aws_ecs_service.wbo_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Auto Scaling Policy - CPU Based
resource "aws_appautoscaling_policy" "wbo_cpu_scaling" {
  name               = "wbo-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.wbo_autoscaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.wbo_autoscaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.wbo_autoscaling_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Auto Scaling Policy - Memory Based
resource "aws_appautoscaling_policy" "wbo_memory_scaling" {
  name               = "wbo-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.wbo_autoscaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.wbo_autoscaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.wbo_autoscaling_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = 80.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Auto Scaling Policy - ALB Request Count
resource "aws_appautoscaling_policy" "wbo_request_count_scaling" {
  name               = "wbo-request-count-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.wbo_autoscaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.wbo_autoscaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.wbo_autoscaling_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.wbo_alb.arn_suffix}/${aws_lb_target_group.wbo_tg.arn_suffix}"
    }
    target_value       = 1000.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
