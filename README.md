# WBO Whiteboard Application - AWS Deployment

A scalable, production-ready deployment of the [Whitebophir](https://github.com/lovasoa/whitebophir) collaborative whiteboard application on AWS, **100% within the AWS Free Tier**.

## 🏗️ Architecture Overview

```
                           ┌─────────────────────────┐
                           │     CloudWatch          │
                           │  • Dashboard            │
                           │  • Alarms               │
                           │  • Container Insights   │
                           └───────────┬─────────────┘
                                       │
                                       │ Metrics
                                       │
    ┌──────────┐          ┌───────────▼──────────┐
    │  Users   │──HTTP───▶│  Application Load    │
    │ (Public  │          │  Balancer (ALB)      │
    │ Internet)│          │  • Health Checks     │
    └──────────┘          │  • Sticky Sessions   │
                          └──────────┬───────────┘
                                     │
                                     │ Distributes Traffic
                                     │
              ┌──────────────────────┼──────────────────────┐
              │                      │                      │
              ▼                      ▼                      ▼
    ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
    │   ECS Task 1    │   │   ECS Task 2    │   │  ECS Task N     │
    │  (Fargate)      │   │  (Fargate)      │   │  (Auto-scaled)  │
    │ lovasoa/wbo     │   │ lovasoa/wbo     │   │  lovasoa/wbo    │
    └────────┬────────┘   └────────┬────────┘   └────────┬────────┘
             │                     │                      │
             │                     │                      │
             └─────────────────────┼──────────────────────┘
                                   │
                                   │ Mount EFS Volume
                                   ▼
                          ┌────────────────────┐
                          │   EFS File System  │
                          │ /opt/app/server-   │
                          │      data          │
                          │  • Shared Storage  │
                          │  • Real-time Sync  │
                          │  • Multi-Instance  │
                          └────────────────────┘

    ┌─────────────────┐              ┌────────────────────┐
    │   S3 Bucket     │              │       VPC          │
    │ wbo-boards-dev  │              │  • 2 Public        │
    │ (Board Backup)  │              │    Subnets         │
    └─────────────────┘              │  • Internet        │
                                     │    Gateway         │
                                     │  • Security Groups │
                                     └────────────────────┘
```

## 🎯 Key Features

### ✅ Scalability

- **Auto-scaling ECS Tasks**: Automatically scales from 1 to 10 instances based on:
  - CPU utilization (70% threshold)
  - Memory utilization (80% threshold)
  - Request count (1000 requests/target)
- **Application Load Balancer**: Distributes traffic across multiple containers
- **Multi-AZ Deployment**: High availability across availability zones

### ✅ EFS Shared Storage Synchronization

- **Amazon EFS**: Network file system mounted by all containers
- **Real-time Sync**: All containers read/write to same `/opt/app/server-data` directory
- **Multi-instance Support**: Perfect synchronization across 1-10 containers
- **How It Works**: WBO stores board data as files; EFS provides shared storage
- **No Application Changes**: WBO designed for file-based storage, works natively

### ✅ Persistent Storage

- **EFS File System**: Primary storage for board data (encrypted, multi-AZ)
- **S3 Bucket**: Backup and archival with versioning enabled
- **IAM Policies**: Secure access for ECS tasks to storage
- **Lifecycle Rules**: EFS transitions to IA after 30 days, S3 cleanup after 90 days

### ✅ Monitoring & Observability

- **CloudWatch Dashboard**: Real-time metrics visualization
  - ECS CPU and Memory usage
  - ALB performance (response time, request count)
  - Target health status
  - EFS performance metrics
  - Running task count
  - Application logs
- **CloudWatch Alarms**: Automated alerts for:
  - High CPU usage (>85%)
  - High memory usage (>90%)
  - Unhealthy targets
  - High response time (>1s)
- **Container Insights**: Detailed ECS metrics
- **Centralized Logging**: All application logs in CloudWatch

### ✅ 100% AWS Free Tier

- **ECS Fargate**: 256 CPU / 512 MB memory (20 GB-month free)
- **EFS**: Network file system (5 GB storage free)
- **S3**: Standard storage with lifecycle policies (5 GB free)
- **ALB**: Application Load Balancer (750 hours/month free)
- **CloudWatch**: 7-day log retention (5 GB logs, 10 alarms free)
- **VPC/Networking**: All networking components (free)
- **Total Monthly Cost**: $0.00 within free tier limits! 🎉

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
PORT=80                            # Container port
WBO_HISTORY_DIR=/opt/app/server-data  # Board data directory (mounted from EFS)
WBO_MAX_EMIT_COUNT=192             # Messages per 4 seconds
```

### Scaling Configuration

Modify in `variables.tf`:

```hcl
ecs_min_capacity = 1   # Minimum tasks (cost saving)
ecs_max_capacity = 10  # Maximum tasks (traffic handling)
ecs_desired_count = 2  # Initial task count
```

### EFS Configuration

The EFS file system provides:

- **Encryption**: Data encrypted at rest
- **Performance Mode**: Bursting (suitable for whiteboard workload)
- **Lifecycle Policy**: Automatic transition to Infrequent Access after 30 days
- **Mount Targets**: Available in both availability zones for high availability

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

## 💰 Cost Analysis

### Free Tier Coverage (12 Months)

This deployment is **100% free** within AWS Free Tier limits:

- **ECS Fargate**: 20 GB-month storage, 10 GB data transfer (Covered ✅)
- **ALB**: 750 hours per month (Covered ✅)
- **EFS**: 5 GB storage (Covered ✅)
- **S3**: 5 GB storage, 20k GET, 2k PUT requests (Covered ✅)
- **CloudWatch**: 5 GB logs, 10 custom metrics, 10 alarms (Covered ✅)
- **VPC/Networking**: All included (Covered ✅)

**Monthly Cost**: **$0.00** 🎉

### After Free Tier (Month 13+)

Estimated costs with default configuration:

- **ECS Fargate**: ~$10-15/month (2 tasks × 256 CPU × 512 MB)
- **ALB**: ~$16/month (750 hours + data processing)
- **EFS**: ~$0.30/month (assuming 1 GB usage)
- **S3**: ~$0.02/month (minimal usage)
- **CloudWatch**: ~$0.50/month (logs + metrics)

**Total**: ~$27-32/month (after free tier expires)

### Cost Reduction Strategies

1. **Scale Down During Off-Hours**

   ```hcl
   ecs_min_capacity = 0  # Scale to 0 at night
   ```

2. **Reduce Task Count**

   ```hcl
   ecs_desired_count = 1  # Run single task
   ```

3. **Reduce Log Retention**
   ```hcl
   retention_in_days = 1  # Minimum retention
   ```

## 🔒 Security Best Practices

### Current Implementation

- ✅ VPC isolation with public subnets
- ✅ Security groups with least privilege
- ✅ EFS encryption at rest enabled
- ✅ S3 bucket encryption and versioning
- ✅ IAM roles with minimal permissions
- ✅ No direct internet access to storage

### Recommended Enhancements

1. **Enable HTTPS**

   - Obtain SSL certificate via ACM (free)
   - Add HTTPS listener to ALB
   - Redirect HTTP to HTTPS

2. **Add WAF Protection**

   - Create AWS WAF web ACL
   - Attach to ALB for DDoS protection
   - Add rate limiting rules

3. **VPC Flow Logs**

   - Enable for network traffic analysis
   - Monitor for suspicious patterns

4. **Enable CloudTrail**
   - Track all API calls
   - Audit access to resources

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

## 🧪 Testing Multi-Instance Sync

To verify EFS-based synchronization across containers:

1. Open whiteboard: `http://<alb-url>/boards/test`
2. Open same URL in another browser/incognito window
3. Draw on one browser
4. **Instantly see changes** appear in the other browser
5. Check CloudWatch logs for board save/load messages
6. Verify both browsers connect to different containers (ALB distributes load)

### How EFS Sync Works

```
Browser 1 → Container 1 → Writes to /opt/app/server-data/boards/test.json (EFS)
                                                ↓
Browser 2 → Container 2 → Reads from /opt/app/server-data/boards/test.json (EFS)
```

All containers mount the **same EFS volume**, ensuring perfect synchronization!

## 📚 Terraform Outputs

After deployment, get all outputs:

```powershell
terraform output
```

Available outputs:

- `alb_url`: Application access URL
- `alb_dns_name`: Load balancer DNS
- `efs_file_system_id`: EFS file system ID
- `s3_bucket_name`: Backup bucket name
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
- Delete EFS file system and mount targets
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
