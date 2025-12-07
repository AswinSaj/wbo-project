# WBO AWS Deployment - Troubleshooting Guide

## Common Issues and Solutions

### 1. Terraform Apply Fails

#### Issue: "Error creating VPC"

**Cause**: Insufficient IAM permissions or region limit reached

**Solution**:

```powershell
# Check your AWS credentials
aws sts get-caller-identity

# Verify IAM permissions include:
# - ec2:*
# - ecs:*
# - elasticache:*
# - s3:*
# - iam:*
# - logs:*
# - elasticloadbalancing:*
```

#### Issue: "Error creating ElastiCache cluster"

**Cause**: Region doesn't support cache.t3.micro or service limit reached

**Solution**:

```hcl
# In variables.tf, change to supported instance type
redis_node_type = "cache.t2.micro"  # Alternative for some regions

# Or request limit increase in AWS Console
```

### 2. ECS Tasks Not Starting

#### Issue: Tasks immediately stop after starting

**Check Container Logs**:

```powershell
# Get cluster name
terraform output ecs_cluster_name

# List tasks
aws ecs list-tasks --cluster wbo-cluster --region us-east-1

# Get task details
aws ecs describe-tasks --cluster wbo-cluster --tasks <task-arn> --region us-east-1

# View logs
.\scripts\logs.ps1 -Mode tail
```

**Common Causes**:

1. **Port Conflict**

   - Verify container port 80 is correctly mapped
   - Check security group allows ALB → ECS on port 80

2. **Redis Connection Failed**

   ```powershell
   # Verify Redis endpoint
   terraform output redis_endpoint

   # Check if Redis is available
   aws elasticache describe-cache-clusters --region us-east-1
   ```

3. **Insufficient Resources**
   ```hcl
   # In variables.tf, increase resources
   ecs_task_cpu    = "512"
   ecs_task_memory = "1024"
   ```

### 3. ALB Health Checks Failing

#### Issue: All targets showing as "unhealthy"

**Check Health Check Settings**:

```powershell
# Get target group ARN
aws elbv2 describe-target-groups --region us-east-1

# Check health status
aws elbv2 describe-target-health --target-group-arn <tg-arn> --region us-east-1
```

**Common Causes**:

1. **Security Group Misconfiguration**

   ```bash
   # Verify ECS tasks security group allows:
   # Ingress: ALB security group → Port 80

   # Check in AWS Console:
   # EC2 → Security Groups → wbo-ecs-tasks-sg
   ```

2. **Container Not Responding**

   ```powershell
   # Check if WBO is running on port 80
   .\scripts\logs.ps1 -Mode recent

   # Look for "Server running on port 80" message
   ```

3. **Wrong Health Check Path**
   ```hcl
   # In alb.tf, verify health check
   health_check {
     path = "/"  # WBO root responds with 200
     # ...
   }
   ```

### 4. Redis Connection Issues

#### Issue: WBO instances not syncing

**Verify Redis Connectivity**:

```powershell
# Check Redis status
aws elasticache describe-replication-groups --replication-group-id wbo-redis --region us-east-1

# Check Redis endpoint
terraform output redis_endpoint

# Verify security group allows ECS → Redis on 6379
```

**Test Redis from ECS Task**:

```powershell
# Connect to running ECS task (requires SSM session manager)
aws ecs execute-command --cluster wbo-cluster --task <task-id> --interactive --command "/bin/sh"

# Inside container:
# apt-get update && apt-get install -y redis-tools
# redis-cli -h <redis-endpoint> PING
# Expected: PONG
```

**Common Causes**:

1. **Redis Not in Same VPC**

   - Verify Redis is in private subnets of same VPC
   - Check subnet group configuration

2. **Wrong REDIS_URL Format**

   ```bash
   # Correct format:
   REDIS_URL=redis://wbo-redis.xxxxx.0001.use1.cache.amazonaws.com:6379

   # Check in CloudWatch logs for connection errors
   ```

### 5. S3 Persistence Not Working

#### Issue: Boards not persisting across restarts

**Check S3 Bucket**:

```powershell
# Get bucket name
terraform output s3_bucket_name

# List bucket contents
aws s3 ls s3://<bucket-name>/ --recursive

# Check IAM permissions
aws iam get-role-policy --role-name wbo-ecs-task-role --policy-name wbo-ecs-task-s3-policy
```

**Note**: WBO stores data in `WBO_HISTORY_DIR` inside container, not directly to S3.
For S3 persistence, you need to:

1. Mount EFS volume to ECS tasks
2. OR implement S3 sync in container
3. OR use Lambda to periodically sync to S3

**Alternative Solution** (Add EFS):

```hcl
# Add to ecs.tf
resource "aws_efs_file_system" "wbo_storage" {
  creation_token = "wbo-efs"
  encrypted      = true

  tags = {
    Name = "wbo-board-storage"
  }
}

# Mount in task definition
volume {
  name = "wbo-storage"
  efs_volume_configuration {
    file_system_id = aws_efs_file_system.wbo_storage.id
  }
}
```

### 6. High Costs / Unexpected Charges

#### Issue: AWS bill higher than expected

**Check Resources**:

```powershell
# List running ECS tasks
aws ecs list-tasks --cluster wbo-cluster --region us-east-1

# Check Redis instance type
aws elasticache describe-cache-clusters --region us-east-1

# Check ALB metrics (data processed)
aws cloudwatch get-metric-statistics `
  --namespace AWS/ApplicationELB `
  --metric-name ProcessedBytes `
  --start-time (Get-Date).AddDays(-7).ToString("yyyy-MM-ddTHH:mm:ss") `
  --end-time (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss") `
  --period 86400 `
  --statistics Sum
```

**Cost Reduction**:

1. **Scale down during off-hours**

   ```powershell
   .\scripts\scale.ps1 -Action down -DesiredCount 0
   ```

2. **Use smaller instance types**

   ```hcl
   ecs_task_cpu    = "256"  # Minimum
   ecs_task_memory = "512"  # Minimum
   ```

3. **Replace ElastiCache with self-hosted Redis**
   - Deploy Redis container in ECS
   - Save ~$12/month

### 7. Auto-Scaling Not Working

#### Issue: Service doesn't scale up under load

**Check Auto-Scaling Policies**:

```powershell
# List scaling policies
aws application-autoscaling describe-scaling-policies `
  --service-namespace ecs `
  --resource-id service/wbo-cluster/wbo-service

# Check recent scaling activities
aws application-autoscaling describe-scaling-activities `
  --service-namespace ecs `
  --resource-id service/wbo-cluster/wbo-service
```

**Common Causes**:

1. **Not Reaching Threshold**

   - CPU < 70% or Memory < 80%
   - Reduce thresholds in `ecs.tf`

2. **Cooldown Period**

   - Wait 60 seconds after scale-out
   - Wait 300 seconds after scale-in

3. **At Max Capacity**
   ```hcl
   # Increase max capacity
   ecs_max_capacity = 20
   ```

### 8. CloudWatch Alarms Not Triggering

#### Issue: No alarm notifications received

**Verify Alarm Status**:

```powershell
# List alarms
aws cloudwatch describe-alarms --region us-east-1

# Check alarm history
aws cloudwatch describe-alarm-history --alarm-name wbo-ecs-high-cpu --max-records 10
```

**Enable SNS Notifications**:

```hcl
# Uncomment in monitoring.tf
resource "aws_sns_topic" "wbo_alarms" {
  name = "wbo-alarms-topic"
}

resource "aws_sns_topic_subscription" "wbo_alarms_email" {
  topic_arn = aws_sns_topic.wbo_alarms.arn
  protocol  = "email"
  endpoint  = "your-email@example.com"
}

# Update alarm actions
alarm_actions = [aws_sns_topic.wbo_alarms.arn]
```

### 9. Application Slow / High Latency

#### Issue: Response times > 1 second

**Check Metrics**:

```powershell
# Run health check
.\scripts\health-check.ps1

# Check ALB response time
aws cloudwatch get-metric-statistics `
  --namespace AWS/ApplicationELB `
  --metric-name TargetResponseTime `
  --dimensions Name=LoadBalancer,Value=<alb-arn-suffix> `
  --start-time (Get-Date).AddHours(-1).ToString("yyyy-MM-ddTHH:mm:ss") `
  --end-time (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss") `
  --period 300 `
  --statistics Average
```

**Solutions**:

1. **Increase Task Resources**

   ```hcl
   ecs_task_cpu    = "512"
   ecs_task_memory = "1024"
   ```

2. **Scale Out More Tasks**

   ```powershell
   .\scripts\scale.ps1 -Action up -DesiredCount 5
   ```

3. **Upgrade Redis**

   ```hcl
   redis_node_type = "cache.t3.small"
   ```

4. **Enable Redis Replication**
   ```hcl
   num_cache_clusters         = 2
   automatic_failover_enabled = true
   ```

### 10. Deployment Stuck

#### Issue: `terraform apply` running for > 20 minutes

**Check Progress**:

```powershell
# In another terminal, check AWS resources
aws ecs describe-services --cluster wbo-cluster --services wbo-service --region us-east-1

# Check ElastiCache creation
aws elasticache describe-replication-groups --region us-east-1
```

**Common Causes**:

1. **ElastiCache Taking Long**

   - Can take 10-15 minutes to create
   - Wait for "available" status

2. **ECS Service Creation Waiting**
   - Waiting for target health checks
   - Check ALB target health

**Cancel and Retry**:

```powershell
# Press Ctrl+C to cancel
# Clean up partial resources
terraform destroy

# Try again
terraform apply
```

## Getting Help

### Collect Diagnostic Information

```powershell
# Run health check
.\scripts\health-check.ps1

# Export logs
.\scripts\logs.ps1 -Mode recent > wbo-logs.txt

# Get Terraform state
terraform show > terraform-state.txt

# List all AWS resources
aws resourcegroupstaggingapi get-resources --region us-east-1 > aws-resources.json
```

### Useful AWS CLI Commands

```powershell
# Check service status
aws ecs describe-services --cluster wbo-cluster --services wbo-service --region us-east-1 | ConvertFrom-Json | Select-Object -ExpandProperty services

# List running tasks
aws ecs list-tasks --cluster wbo-cluster --desired-status RUNNING --region us-east-1

# Get task details
aws ecs describe-tasks --cluster wbo-cluster --tasks <task-arn> --region us-east-1

# Check Redis
aws elasticache describe-replication-groups --replication-group-id wbo-redis --region us-east-1

# Check ALB targets
aws elbv2 describe-target-health --target-group-arn <tg-arn> --region us-east-1

# View recent logs
aws logs tail /ecs/wbo --since 10m --follow
```

### Enable Debug Logging

Add to ECS task definition environment:

```hcl
environment = [
  # ... existing vars
  {
    name  = "DEBUG"
    value = "*"
  }
]
```

## Still Having Issues?

1. Check [WBO GitHub Issues](https://github.com/lovasoa/whitebophir/issues)
2. Review [AWS ECS Troubleshooting](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/troubleshooting.html)
3. Check [ElastiCache Troubleshooting](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/Troubleshooting.html)
