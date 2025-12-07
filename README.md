# WBO Whiteboard Application - AWS Deployment

A scalable, production-ready deployment of the [Whitebophir](https://github.com/lovasoa/whitebophir) collaborative whiteboard application on AWS, optimized for the **AWS Free Tier**.

## 🏗️ Architecture Overview

```
                                    ┌─────────────────┐
                                    │   CloudWatch    │
                                    │  (Monitoring)   │
                                    └────────┬────────┘
                                             │
┌──────────┐         ┌────────────┐         │        ┌─────────────┐
│  Users   │────────▶│    ALB     │◀────────┼───────▶│  ECS Tasks  │
│          │         │ (Load      │         │        │  (Fargate)  │
└──────────┘         │ Balancer)  │         │        │ lovasoa/wbo │
                     └────────────┘         │        └──────┬──────┘
                                             │               │
                     ┌────────────┐         │               │
                     │  Route 53  │◀────────┘               │
                     │   (DNS)    │                         │
                     └────────────┘                         │
                                                             │
                     ┌────────────┐         ┌───────────────┼─────────┐
                     │     S3     │◀────────│               │         │
                     │(Persistence)│        │               ▼         ▼
                     └────────────┘         │        ┌─────────────────┐
                                            │        │ Redis ElastiCache│
                                            │        │   (Pub/Sub)      │
                                            │        └──────────────────┘
                                            │
                                            ▼
                                     ┌────────────┐
                                     │    VPC     │
                                     │  Subnets   │
                                     │ (Public +  │
                                     │  Private)  │
                                     └────────────┘
```

## 🎯 Key Features

### ✅ Scalability

- **Auto-scaling ECS Tasks**: Automatically scales from 1 to 10 instances based on:
  - CPU utilization (70% threshold)
  - Memory utilization (80% threshold)
  - Request count (1000 requests/target)
- **Application Load Balancer**: Distributes traffic across multiple containers
- **Multi-AZ Deployment**: High availability across availability zones

### ✅ Redis Pub/Sub Synchronization

- **ElastiCache for Redis**: Centralized Redis cluster for real-time synchronization
- **Multi-instance Support**: All WBO containers sync through Redis pub/sub
- **Connection URL**: Automatically configured via `REDIS_URL` environment variable
- **Optimized Parameters**: Custom parameter group for pub/sub performance

### ✅ Persistent Storage

- **S3 Bucket**: Stores whiteboard data with versioning enabled
- **IAM Policies**: Secure access for ECS tasks to S3
- **Lifecycle Rules**: Automatic cleanup of old versions (30 days)

### ✅ Monitoring & Observability

- **CloudWatch Dashboard**: Real-time metrics visualization
  - ECS CPU and Memory usage
  - ALB performance (response time, request count)
  - Target health status
  - Redis performance metrics
  - Application logs
- **CloudWatch Alarms**: Automated alerts for:
  - High CPU usage (>85%)
  - High memory usage (>90%)
  - Unhealthy targets
  - High Redis CPU (>75%)
  - High response time (>1s)
- **Container Insights**: Detailed ECS metrics
- **Centralized Logging**: All application logs in CloudWatch

### ✅ AWS Free Tier Optimized

- **Cache.t3.micro Redis**: Single node (free tier eligible)
- **ECS Fargate**: 256 CPU / 512 MB memory (minimal cost)
- **S3**: Standard storage with lifecycle policies
- **CloudWatch**: 7-day log retention
- **ALB**: Optimized for low traffic

## 📋 Prerequisites

- AWS Account with appropriate permissions
- [Terraform](https://www.terraform.io/downloads) >= 1.0
- AWS CLI configured with credentials
- Basic understanding of AWS services

## 🚀 Deployment Steps

### 1. Clone and Navigate

```powershell
cd d:\wbo-v2\terraform
```

### 2. Initialize Terraform

```powershell
terraform init
```

### 3. Review Configuration

Edit `variables.tf` to customize:

- `aws_region`: Change if not using us-east-1
- `ecs_desired_count`: Initial number of tasks (default: 2)
- `ecs_max_capacity`: Maximum scale limit (default: 10)

### 4. Plan Deployment

```powershell
terraform plan
```

### 5. Deploy Infrastructure

```powershell
terraform apply
```

Type `yes` when prompted to create resources.

### 6. Get Application URL

After deployment completes (10-15 minutes):

```powershell
terraform output alb_url
```

Access your whiteboard at: `http://<alb-dns-name>`

## 🔧 Configuration

### Environment Variables

The WBO container is configured with:

```bash
PORT=80                    # Container port
WBO_HISTORY_DIR=/opt/app/server-data  # Board data directory
REDIS_URL=redis://<endpoint>:6379     # Redis pub/sub connection
WBO_MAX_EMIT_COUNT=192     # Messages per 4 seconds
```

### Scaling Configuration

Modify in `variables.tf`:

```hcl
ecs_min_capacity = 1   # Minimum tasks (cost saving)
ecs_max_capacity = 10  # Maximum tasks (traffic handling)
ecs_desired_count = 2  # Initial task count
```

### Redis Configuration

For production with higher traffic:

```hcl
redis_node_type = "cache.t3.small"  # Upgrade from cache.t3.micro
num_cache_clusters = 2               # Add replication
automatic_failover_enabled = true    # Enable failover
```

## 📊 Monitoring

### CloudWatch Dashboard

Access the monitoring dashboard:

```powershell
terraform output cloudwatch_dashboard_url
```

### View Logs

```bash
# Via AWS CLI
aws logs tail /ecs/wbo --follow

# Via Terraform output
terraform output cloudwatch_log_group
```

### Alarms

Configure SNS notifications by uncommenting in `monitoring.tf`:

1. Uncomment SNS topic resources
2. Add email to `variables.tf`
3. Update alarm_actions in alarm definitions
4. Run `terraform apply`

## 💰 Cost Optimization Tips

### Free Tier Considerations

- **ECS Fargate**: First 50k vCPU hours and 100GB storage per month free
- **ALB**: First 750 hours per month free
- **ElastiCache**: Not included in free tier (~$13/month for t3.micro)
- **S3**: First 5GB storage, 20k GET, 2k PUT requests free
- **CloudWatch**: 5GB logs, 10 custom metrics, 10 alarms free

### Cost Reduction Strategies

1. **Scale Down During Off-Hours**

   ```hcl
   ecs_min_capacity = 0  # Scale to 0 at night (requires ALB warmup time)
   ```

2. **Use EC2 Instead of Fargate** (Free tier eligible)

   - Switch to EC2 launch type with t2.micro instances
   - More setup but qualifies for 750 hours/month free

3. **Self-Hosted Redis**

   - Run Redis in ECS alongside WBO (saves $13/month)
   - Trade-off: Less managed, requires maintenance

4. **Reduce Log Retention**
   ```hcl
   retention_in_days = 1  # Minimum retention
   ```

## 🔒 Security Best Practices

### Current Implementation

- ✅ Private subnets for Redis
- ✅ Security groups with least privilege
- ✅ S3 bucket encryption and versioning
- ✅ IAM roles with minimal permissions
- ✅ No public Redis access

### Recommended Enhancements

1. **Enable HTTPS**

   - Obtain SSL certificate via ACM
   - Uncomment HTTPS listener in `alb.tf`
   - Add certificate ARN to variables

2. **Enable Redis Encryption**

   ```hcl
   at_rest_encryption_enabled = true
   transit_encryption_enabled = true
   ```

3. **Add WAF Protection**

   - Create AWS WAF web ACL
   - Attach to ALB for DDoS protection

4. **VPC Flow Logs**
   - Enable for network traffic analysis

## 🛠️ Maintenance

### Update WBO Docker Image

The ECS service pulls `lovasoa/wbo:latest`. To update:

```powershell
# Force new deployment
aws ecs update-service --cluster wbo-cluster --service wbo-service --force-new-deployment --region us-east-1
```

### Backup S3 Data

```powershell
# Get bucket name
terraform output s3_bucket_name

# Backup locally
aws s3 sync s3://<bucket-name> ./backups/
```

### Scale Manually

```powershell
# Scale up
aws ecs update-service --cluster wbo-cluster --service wbo-service --desired-count 5 --region us-east-1

# Scale down
aws ecs update-service --cluster wbo-cluster --service wbo-service --desired-count 1 --region us-east-1
```

## 🧪 Testing Redis Sync

To verify multi-instance synchronization:

1. Open whiteboard: `http://<alb-url>/boards/test`
2. Open same URL in another browser/incognito window
3. Draw on one browser
4. Verify real-time sync appears in other browser
5. Check CloudWatch logs for Redis connection messages

## 📚 Terraform Outputs

After deployment, get all outputs:

```powershell
terraform output
```

Available outputs:

- `alb_url`: Application access URL
- `alb_dns_name`: Load balancer DNS
- `redis_endpoint`: Redis connection endpoint
- `s3_bucket_name`: Persistence bucket
- `ecs_cluster_name`: ECS cluster name
- `ecs_service_name`: ECS service name
- `cloudwatch_log_group`: Log group name
- `cloudwatch_dashboard_url`: Monitoring dashboard

## 🗑️ Cleanup

To destroy all resources:

```powershell
terraform destroy
```

Type `yes` to confirm. This will:

- Delete ECS cluster and tasks
- Remove ALB and target groups
- Delete ElastiCache Redis cluster
- Remove S3 bucket (if empty)
- Delete all CloudWatch resources
- Clean up VPC and networking

**Note**: S3 bucket must be empty before destruction. Manually delete objects first if needed.

## 🐛 Troubleshooting

### ECS Tasks Not Starting

```powershell
# Check task logs
aws logs tail /ecs/wbo --follow

# Check task status
aws ecs describe-tasks --cluster wbo-cluster --tasks <task-arn>
```

### ALB Health Checks Failing

- Verify security groups allow ALB → ECS traffic
- Check container health: `docker logs` equivalent in CloudWatch
- Ensure port 80 is exposed in container

### Redis Connection Issues

```powershell
# Get Redis endpoint
terraform output redis_endpoint

# Check security group rules
# Verify ECS tasks can reach private subnet
```

### High Costs

- Review CloudWatch billing alerts
- Check ECS task count: `aws ecs describe-services`
- Verify auto-scaling policies aren't over-scaling

## 📖 Additional Resources

- [WBO Docker Hub](https://hub.docker.com/r/lovasoa/wbo)
- [Whitebophir GitHub](https://github.com/lovasoa/whitebophir)
- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [AWS Free Tier Details](https://aws.amazon.com/free/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## 📄 License

This deployment configuration is provided as-is. The WBO application is licensed under its own terms (see Whitebophir repository).

## 🤝 Contributing

Feel free to submit issues or pull requests for improvements to this deployment configuration.

---

**Built with ❤️ for collaborative whiteboarding**
