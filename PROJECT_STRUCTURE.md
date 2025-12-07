# WBO AWS Deployment - Project Structure

```
d:\wbo-v2\
│
├── 📄 README.md                          # Main documentation with full details
├── 📄 QUICKSTART.md                      # 5-minute setup guide
├── 📄 .gitignore                         # Git ignore rules for Terraform
│
├── 📁 terraform/                         # Infrastructure as Code
│   ├── main.tf                           # VPC, subnets, networking
│   ├── security_groups.tf                # Security groups (ALB, ECS, Redis)
│   ├── alb.tf                            # Application Load Balancer
│   ├── redis.tf                          # ElastiCache Redis cluster
│   ├── redis_self_hosted.tf.optional     # Self-hosted Redis (free tier)
│   ├── s3_iam.tf                         # S3 bucket and IAM roles
│   ├── ecs.tf                            # ECS cluster, tasks, auto-scaling
│   ├── monitoring.tf                     # CloudWatch dashboard and alarms
│   ├── variables.tf                      # Terraform variables
│   ├── outputs.tf                        # Terraform outputs
│   └── terraform.tfvars.example          # Example configuration file
│
├── 📁 scripts/                           # PowerShell management scripts
│   ├── deploy.ps1                        # Automated deployment script
│   ├── scale.ps1                         # Scale ECS service up/down
│   ├── backup.ps1                        # Backup S3 data locally
│   ├── logs.ps1                          # View application logs
│   └── health-check.ps1                  # Monitor application health
│
└── 📁 docs/                              # Additional documentation
    ├── ARCHITECTURE.md                   # Architecture diagrams & details
    └── TROUBLESHOOTING.md                # Troubleshooting guide
```

## File Descriptions

### Root Files

#### README.md

Complete project documentation including:

- Architecture overview with diagrams
- Deployment instructions
- Configuration options
- Monitoring setup
- Cost optimization tips
- Security best practices
- Maintenance guides

#### QUICKSTART.md

Fast-track setup guide:

- Prerequisites checklist
- 5-minute deployment steps
- Quick management commands
- Common issues and fixes

#### .gitignore

Git ignore patterns for:

- Terraform state files
- Sensitive variable files
- Local backup directories
- IDE and OS-specific files

### Terraform Directory (`terraform/`)

#### Core Infrastructure

**main.tf**

- AWS provider configuration
- VPC with CIDR 10.0.0.0/16
- Internet Gateway
- 2 Public subnets (10.0.1.0/24, 10.0.2.0/24)
- 2 Private subnets (10.0.10.0/24, 10.0.11.0/24)
- Route tables and associations
- Multi-AZ setup for high availability

**security_groups.tf**

- ALB security group (allow 80, 443 from internet)
- ECS tasks security group (allow 80 from ALB)
- Redis security group (allow 6379 from ECS tasks)
- Least-privilege network access rules

**alb.tf**

- Application Load Balancer (internet-facing)
- Target group with health checks
- HTTP listener (port 80)
- Optional HTTPS listener (port 443)
- Sticky sessions enabled
- Connection draining configured

#### Storage & Caching

**redis.tf**

- ElastiCache Redis 7.0 replication group
- cache.t3.micro instance (free tier eligible)
- Single-node configuration
- Custom parameter group for pub/sub
- Private subnet deployment
- Outputs endpoint for WBO connection

**redis_self_hosted.tf.optional**

- Self-hosted Redis in ECS Fargate
- Completely free tier alternative
- Service discovery for internal DNS
- Persistent EBS storage option
- Redis 7 Alpine container
- Rename to `.tf` to enable

**s3_iam.tf**

- S3 bucket for board persistence
- Versioning enabled
- Lifecycle rules (30-day cleanup)
- Public access blocked
- ECS task execution IAM role
- ECS task IAM role (for S3 access)
- CloudWatch Logs permissions

#### Compute & Auto-Scaling

**ecs.tf**

- ECS Fargate cluster with Container Insights
- CloudWatch Log Group (/ecs/wbo)
- WBO task definition:
  - lovasoa/wbo:latest docker image
  - 256 CPU / 512 MB memory (free tier)
  - Environment variables (PORT, REDIS_URL, etc.)
  - Health checks (HTTP /)
- ECS Service:
  - Desired count: 2 tasks
  - Load balancer integration
  - Network configuration
- Auto-scaling target (1-10 tasks)
- Scaling policies:
  - CPU-based (70% threshold)
  - Memory-based (80% threshold)
  - Request count-based (1000 req/target)

#### Monitoring & Observability

**monitoring.tf**

- CloudWatch Dashboard with widgets:
  - ECS CPU & Memory metrics
  - ALB performance (latency, requests)
  - Target health status
  - Redis performance
  - Recent application logs
- CloudWatch Alarms:
  - High CPU (>85%)
  - High Memory (>90%)
  - Unhealthy targets (>0)
  - High Redis CPU (>75%)
  - High response time (>1s)
- Optional SNS topic for notifications

#### Configuration

**variables.tf**
Configurable parameters:

- `aws_region`: Deployment region (default: us-east-1)
- `environment`: Environment name (default: dev)
- `project_name`: Project identifier (default: wbo)
- `redis_node_type`: Redis instance type (default: cache.t3.micro)
- `ecs_task_cpu`: Task CPU units (default: 256)
- `ecs_task_memory`: Task memory in MB (default: 512)
- `ecs_desired_count`: Initial task count (default: 2)
- `ecs_min_capacity`: Min auto-scale (default: 1)
- `ecs_max_capacity`: Max auto-scale (default: 10)

**outputs.tf**
Exported values after deployment:

- `alb_url`: Application access URL
- `alb_dns_name`: Load balancer DNS
- `redis_endpoint`: Redis connection string
- `s3_bucket_name`: Persistence bucket name
- `ecs_cluster_name`: Cluster name
- `ecs_service_name`: Service name
- `cloudwatch_log_group`: Log group path
- `cloudwatch_dashboard_url`: Dashboard link

**terraform.tfvars.example**
Example configuration file with comments
Copy to `terraform.tfvars` and customize

### Scripts Directory (`scripts/`)

#### deploy.ps1

**Automated Deployment Script**

- Checks prerequisites (Terraform, AWS CLI)
- Verifies AWS credentials
- Initializes Terraform
- Creates default configuration
- Optionally runs `terraform plan`
- Interactive guided setup

Usage:

```powershell
.\scripts\deploy.ps1
```

#### scale.ps1

**ECS Service Scaling Tool**

- Scale up/down service instances
- Check current service status
- Safety confirmation for scale-to-zero
- Real-time task count display

Usage:

```powershell
# Scale up to 5 tasks
.\scripts\scale.ps1 -Action up -DesiredCount 5

# Scale down to 1 task
.\scripts\scale.ps1 -Action down -DesiredCount 1

# Check status
.\scripts\scale.ps1 -Action status
```

#### backup.ps1

**S3 Data Backup Tool**

- Backs up S3 bucket to local directory
- Creates timestamped backup folders
- Shows backup size and location
- Retrieves bucket name from Terraform

Usage:

```powershell
.\scripts\backup.ps1
# Backups saved to: .\backups\<timestamp>\
```

#### logs.ps1

**Application Log Viewer**

- Three modes:
  - `tail`: Live log streaming (Ctrl+C to stop)
  - `recent`: Last N log entries
  - `errors`: Search for ERROR patterns in last hour
- Formatted timestamp display
- Color-coded error output

Usage:

```powershell
# Live tail
.\scripts\logs.ps1 -Mode tail

# Last 100 entries
.\scripts\logs.ps1 -Mode recent -Lines 100

# Search errors
.\scripts\logs.ps1 -Mode errors
```

#### health-check.ps1

**Application Health Monitor**

- Comprehensive health status:
  - ECS service status (desired vs running tasks)
  - ALB target health (healthy/unhealthy counts)
  - Redis cluster status
  - Recent error summary (last 15 minutes)
  - HTTP connectivity test
- Color-coded status indicators
- Detailed unhealthy target information

Usage:

```powershell
.\scripts\health-check.ps1
```

### Documentation Directory (`docs/`)

#### ARCHITECTURE.md

**Detailed Architecture Documentation**

- High-level architecture diagram
- Network architecture (VPC layout)
- Security groups flow
- Auto-scaling flow diagram
- Data flow for whiteboard sync
- Monitoring & observability setup
- IAM permissions flow
- Cost breakdown (monthly estimate)
- ASCII art diagrams for all components

#### TROUBLESHOOTING.md

**Comprehensive Troubleshooting Guide**

- Common issues and solutions:
  1. Terraform apply failures
  2. ECS tasks not starting
  3. ALB health checks failing
  4. Redis connection issues
  5. S3 persistence problems
  6. High costs / unexpected charges
  7. Auto-scaling not working
  8. CloudWatch alarms not triggering
  9. Application slow / high latency
  10. Deployment stuck
- Diagnostic commands
- Log collection steps
- Debug mode instructions
- Links to AWS documentation

## Deployment Workflow

```
1. Prerequisites Check
   └─> .\scripts\deploy.ps1
       └─> Verifies Terraform, AWS CLI, credentials

2. Initialize Terraform
   └─> terraform init
       └─> Downloads AWS provider

3. Configure Variables
   └─> Copy terraform.tfvars.example to terraform.tfvars
       └─> Customize settings

4. Plan Deployment
   └─> terraform plan
       └─> Preview resource creation

5. Deploy Infrastructure
   └─> terraform apply
       └─> Creates all AWS resources (10-15 minutes)

6. Get Application URL
   └─> terraform output alb_url
       └─> Access whiteboard application

7. Monitor & Manage
   ├─> .\scripts\health-check.ps1  (health status)
   ├─> .\scripts\logs.ps1           (view logs)
   ├─> .\scripts\scale.ps1          (scale instances)
   └─> .\scripts\backup.ps1         (backup data)

8. Cleanup (when done)
   └─> terraform destroy
       └─> Deletes all resources
```

## Resource Dependencies

```
VPC & Networking
  ├─> Security Groups
  │     ├─> ALB
  │     ├─> ECS Tasks
  │     └─> Redis
  │
  ├─> Application Load Balancer
  │     └─> Target Group
  │           └─> ECS Service
  │
  ├─> ElastiCache Redis
  │     └─> Subnet Group
  │           └─> Private Subnets
  │
  ├─> S3 Bucket
  │     └─> IAM Policies
  │
  └─> ECS Cluster
        └─> ECS Service
              ├─> Task Definition (WBO)
              ├─> Auto Scaling Target
              │     └─> Scaling Policies
              └─> CloudWatch Logs
                    └─> Log Group
```

## Getting Started Path

**For Quick Start (5 minutes):**

1. Read: `QUICKSTART.md`
2. Run: `.\scripts\deploy.ps1`
3. Execute: `terraform apply`

**For Full Understanding:**

1. Read: `README.md`
2. Review: `docs\ARCHITECTURE.md`
3. Customize: `terraform\variables.tf`
4. Deploy: Step-by-step terraform commands

**For Troubleshooting:**

1. Run: `.\scripts\health-check.ps1`
2. Check: `.\scripts\logs.ps1 -Mode errors`
3. Consult: `docs\TROUBLESHOOTING.md`

## Customization Points

| What to Customize   | File            | Setting                   |
| ------------------- | --------------- | ------------------------- |
| AWS Region          | `variables.tf`  | `aws_region`              |
| Instance Count      | `variables.tf`  | `ecs_desired_count`       |
| Max Scale           | `variables.tf`  | `ecs_max_capacity`        |
| Task Resources      | `variables.tf`  | `ecs_task_cpu/memory`     |
| Redis Type          | `variables.tf`  | `redis_node_type`         |
| HTTPS Certificate   | `alb.tf`        | Uncomment HTTPS listener  |
| Alarm Email         | `monitoring.tf` | Uncomment SNS resources   |
| Health Check        | `alb.tf`        | `health_check` block      |
| Auto-scale Triggers | `ecs.tf`        | Scaling policy thresholds |

## Maintenance Schedule

**Daily:**

- Monitor CloudWatch dashboard
- Check application logs for errors

**Weekly:**

- Review CloudWatch alarms
- Check AWS billing dashboard
- Backup S3 data

**Monthly:**

- Update WBO docker image
- Review and optimize scaling policies
- Clean up old S3 versions
- Update Terraform providers

**Quarterly:**

- Review security groups
- Update AWS IAM policies
- Test disaster recovery
- Audit costs and optimize
