# 🚀 Quick Start Guide - WBO on AWS

## Prerequisites Checklist

- [ ] AWS Account (Free Tier eligible)
- [ ] [Terraform](https://www.terraform.io/downloads) installed
- [ ] [AWS CLI](https://aws.amazon.com/cli/) installed and configured
- [ ] Git installed (optional)

## 5-Minute Setup

### Step 1: Configure AWS Credentials

```powershell
# Run AWS configure
aws configure

# Enter your credentials:
# AWS Access Key ID: YOUR_ACCESS_KEY
# AWS Secret Access Key: YOUR_SECRET_KEY
# Default region: us-east-1
# Default output format: json
```

### Step 2: Navigate to Project

```powershell
cd d:\wbo-v2
```

### Step 3: Run Deployment Script

```powershell
.\scripts\deploy.ps1
```

This script will:

- ✅ Check prerequisites
- ✅ Initialize Terraform
- ✅ Create default configuration
- ✅ Show deployment plan

### Step 4: Deploy Infrastructure

```powershell
cd terraform
terraform apply
```

Type `yes` when prompted.

**⏱️ Deployment Time: 10-15 minutes**

### Step 5: Get Your Whiteboard URL

```powershell
terraform output alb_url
```

Visit the URL in your browser: `http://<alb-dns-name>`

## 🎉 You're Done!

Your collaborative whiteboard is now live!

### Test Multi-User Sync

1. Open your whiteboard URL
2. Add `/boards/test` to the URL: `http://<alb-dns-name>/boards/test`
3. Open the same URL in another browser/incognito window
4. Draw in one window → See it appear in real-time in the other! ✨

## 📊 Access Monitoring

```powershell
# View CloudWatch dashboard
terraform output cloudwatch_dashboard_url

# Check application health
.\scripts\health-check.ps1

# View live logs
.\scripts\logs.ps1 -Mode tail
```

## 💰 Cost Estimate

**With ElastiCache Redis:** ~$12.41/month
**Free Tier Only:** ~$0/month (see alternative setup below)

## 🆓 100% Free Tier Setup (Alternative)

To eliminate all costs, replace ElastiCache with self-hosted Redis:

```powershell
# In terraform directory
cd d:\wbo-v2\terraform

# Disable ElastiCache Redis
mv redis.tf redis.tf.disabled

# Enable self-hosted Redis
mv redis_self_hosted.tf.optional redis_self_hosted.tf
```

Then update `ecs.tf` to change the REDIS_URL:

```hcl
{
  name  = "REDIS_URL"
  value = "redis://redis.wbo.local:6379"  # Changed from ElastiCache endpoint
}
```

Apply changes:

```powershell
terraform apply
```

## 🔧 Common Management Tasks

### Scale Up/Down

```powershell
# Scale to 5 instances
.\scripts\scale.ps1 -Action up -DesiredCount 5

# Scale to 1 instance (cost saving)
.\scripts\scale.ps1 -Action down -DesiredCount 1

# Check current status
.\scripts\scale.ps1 -Action status
```

### Backup Board Data

```powershell
.\scripts\backup.ps1
```

Backups saved to: `.\backups\<timestamp>\`

### View Application Logs

```powershell
# Live tail
.\scripts\logs.ps1 -Mode tail

# Recent entries
.\scripts\logs.ps1 -Mode recent -Lines 100

# Search for errors
.\scripts\logs.ps1 -Mode errors
```

### Update WBO Version

```powershell
# Force new deployment (pulls latest docker image)
aws ecs update-service `
  --cluster wbo-cluster `
  --service wbo-service `
  --force-new-deployment `
  --region us-east-1
```

## 🗑️ Cleanup (Delete Everything)

```powershell
cd d:\wbo-v2\terraform
terraform destroy
```

Type `yes` to confirm. This will:

- Delete all AWS resources
- Stop all charges
- Preserve local backups (if created)

**⚠️ Warning:** This cannot be undone! Backup your data first.

## 🔒 Security Enhancements

### Enable HTTPS (Recommended for Production)

1. **Get SSL Certificate from AWS ACM**

   ```powershell
   aws acm request-certificate `
     --domain-name yourdomain.com `
     --validation-method DNS `
     --region us-east-1
   ```

2. **Uncomment HTTPS Listener in `alb.tf`**

   ```hcl
   resource "aws_lb_listener" "wbo_https" {
     # ... uncomment this block
   }
   ```

3. **Add Certificate ARN to `terraform.tfvars`**

   ```hcl
   ssl_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/your-cert-id"
   ```

4. **Apply Changes**
   ```powershell
   terraform apply
   ```

### Enable Alarm Notifications

1. **Uncomment SNS Configuration in `monitoring.tf`**

2. **Add Your Email to `terraform.tfvars`**

   ```hcl
   alarm_email = "your-email@example.com"
   ```

3. **Apply and Confirm Subscription**
   ```powershell
   terraform apply
   # Check your email and confirm SNS subscription
   ```

## 📚 Additional Resources

- **Architecture Details**: `docs\ARCHITECTURE.md`
- **Troubleshooting Guide**: `docs\TROUBLESHOOTING.md`
- **Full README**: `README.md`

## 🆘 Getting Help

### Something Not Working?

1. **Run Health Check**

   ```powershell
   .\scripts\health-check.ps1
   ```

2. **Check Logs for Errors**

   ```powershell
   .\scripts\logs.ps1 -Mode errors
   ```

3. **Consult Troubleshooting Guide**
   ```powershell
   notepad docs\TROUBLESHOOTING.md
   ```

### Common Issues

| Issue                  | Quick Fix                                                      |
| ---------------------- | -------------------------------------------------------------- |
| ECS tasks not starting | Check logs: `.\scripts\logs.ps1 -Mode tail`                    |
| Health checks failing  | Verify security groups allow ALB → ECS traffic                 |
| Redis not connecting   | Check security group allows ECS → Redis on 6379                |
| High costs             | Scale down: `.\scripts\scale.ps1 -Action down -DesiredCount 1` |

## 🎓 What You've Deployed

- ✅ **VPC** with public and private subnets across 2 AZs
- ✅ **Application Load Balancer** for traffic distribution
- ✅ **ECS Fargate** cluster with auto-scaling (1-10 instances)
- ✅ **Redis ElastiCache** for real-time pub/sub synchronization
- ✅ **S3 Bucket** for board data persistence (with lifecycle rules)
- ✅ **CloudWatch** dashboard, logs, and alarms for monitoring
- ✅ **IAM Roles** with least-privilege access
- ✅ **Security Groups** with proper network isolation

## 📈 Next Steps

1. **Set Up Custom Domain** (Route 53)
2. **Enable HTTPS** with ACM certificate
3. **Configure Alarm Notifications** via SNS
4. **Add Authentication** using JWT tokens
5. **Implement Backups** to S3 or scheduled snapshots
6. **Optimize Costs** by scheduling scale-down during off-hours

## 🌟 Features Enabled

- ✨ Real-time collaboration via Redis pub/sub
- 🔄 Auto-scaling based on CPU, memory, and request count
- 📊 Comprehensive monitoring and alerting
- 💾 Persistent board storage
- 🛡️ Secure network architecture
- 💰 AWS Free Tier optimized

---

**Built with ❤️ for collaborative whiteboarding**

For detailed documentation, see `README.md`
