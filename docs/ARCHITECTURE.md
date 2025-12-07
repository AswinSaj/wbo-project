# WBO AWS Deployment - Architecture Diagram

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                   Internet                                   │
└────────────────────────────────┬────────────────────────────────────────────┘
                                 │
                                 │ HTTPS/HTTP
                                 ▼
                     ┌───────────────────────┐
                     │  Application Load     │
                     │     Balancer (ALB)    │
                     │   - Port 80/443       │
                     │   - Health Checks     │
                     │   - Sticky Sessions   │
                     └──────────┬────────────┘
                                │
                                │ Distributes traffic
                                │
        ┌───────────────────────┼───────────────────────┐
        │                       │                       │
        ▼                       ▼                       ▼
┌───────────────┐      ┌───────────────┐      ┌───────────────┐
│  ECS Task 1   │      │  ECS Task 2   │      │  ECS Task N   │
│ ─────────────│      │ ─────────────│      │ ─────────────│
│ lovasoa/wbo   │      │ lovasoa/wbo   │      │ lovasoa/wbo   │
│ Port: 80      │      │ Port: 80      │      │ Port: 80      │
│ CPU: 256      │      │ CPU: 256      │      │ CPU: 256      │
│ Memory: 512MB │      │ Memory: 512MB │      │ Memory: 512MB │
└───────┬───────┘      └───────┬───────┘      └───────┬───────┘
        │                      │                      │
        │                      │                      │
        └──────────────────────┼──────────────────────┘
                               │
                               │ Redis Pub/Sub
                               │ (Real-time sync)
                               ▼
                    ┌──────────────────────┐
                    │   ElastiCache Redis  │
                    │   ─────────────────  │
                    │   - cache.t3.micro   │
                    │   - Port 6379        │
                    │   - Private Subnet   │
                    │   - Pub/Sub enabled  │
                    └──────────────────────┘

        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
        │ Read/Write           │ Logs & Metrics       │
        ▼                      ▼                      ▼
┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│      S3      │      │  CloudWatch  │      │ CloudWatch   │
│ ────────────│      │    Logs      │      │   Metrics    │
│ Board Data   │      │ ────────────│      │ ────────────│
│ Persistence  │      │ Application  │      │ CPU/Memory   │
│ Versioning   │      │ Error logs   │      │ Request Rate │
│ Lifecycle    │      │ Access logs  │      │ Health       │
└──────────────┘      └──────────────┘      └──────────────┘
```

## Network Architecture (VPC)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           VPC (10.0.0.0/16)                             │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                    Availability Zone 1                             │ │
│  │                                                                     │ │
│  │  ┌──────────────────────┐         ┌──────────────────────┐       │ │
│  │  │  Public Subnet 1     │         │  Private Subnet 1    │       │ │
│  │  │  10.0.1.0/24         │         │  10.0.10.0/24        │       │ │
│  │  │                      │         │                      │       │ │
│  │  │  ┌────────────────┐  │         │  ┌────────────────┐  │       │ │
│  │  │  │   ALB (Part)   │  │         │  │ Redis Node 1   │  │       │ │
│  │  │  └────────────────┘  │         │  └────────────────┘  │       │ │
│  │  │  ┌────────────────┐  │         │                      │       │ │
│  │  │  │  ECS Task 1    │  │         │                      │       │ │
│  │  │  └────────────────┘  │         │                      │       │ │
│  │  └──────────────────────┘         └──────────────────────┘       │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                    Availability Zone 2                             │ │
│  │                                                                     │ │
│  │  ┌──────────────────────┐         ┌──────────────────────┐       │ │
│  │  │  Public Subnet 2     │         │  Private Subnet 2    │       │ │
│  │  │  10.0.2.0/24         │         │  10.0.11.0/24        │       │ │
│  │  │                      │         │                      │       │ │
│  │  │  ┌────────────────┐  │         │  ┌────────────────┐  │       │ │
│  │  │  │   ALB (Part)   │  │         │  │ Redis Node 2   │  │       │ │
│  │  │  └────────────────┘  │         │  │  (Replica)     │  │       │ │
│  │  │  ┌────────────────┐  │         │  └────────────────┘  │       │ │
│  │  │  │  ECS Task 2    │  │         │                      │       │ │
│  │  │  └────────────────┘  │         │                      │       │ │
│  │  └──────────────────────┘         └──────────────────────┘       │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  ┌────────────────┐                                                     │
│  │ Internet GW    │ ◄────── Route to Internet (0.0.0.0/0)              │
│  └────────────────┘                                                     │
└─────────────────────────────────────────────────────────────────────────┘
```

## Security Groups Flow

```
┌──────────────────────────────────────────────────────────────────┐
│                         Internet                                  │
└────────────────────────────┬─────────────────────────────────────┘
                             │
                             │ Ports 80, 443
                             ▼
                  ┌──────────────────────┐
                  │   ALB Security Group │
                  │   ─────────────────  │
                  │   Ingress:           │
                  │   - 0.0.0.0/0:80     │
                  │   - 0.0.0.0/0:443    │
                  │   Egress: All        │
                  └──────────┬───────────┘
                             │
                             │ Port 80
                             ▼
                  ┌──────────────────────┐
                  │  ECS Tasks SG        │
                  │  ─────────────────   │
                  │  Ingress:            │
                  │  - ALB SG:80         │
                  │  Egress: All         │
                  └──────────┬───────────┘
                             │
                             │ Port 6379
                             ▼
                  ┌──────────────────────┐
                  │   Redis SG           │
                  │   ─────────────────  │
                  │   Ingress:           │
                  │   - ECS Tasks SG:6379│
                  │   Egress: All        │
                  └──────────────────────┘
```

## Auto-Scaling Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                      CloudWatch Metrics                          │
│  - CPU Utilization > 70%                                         │
│  - Memory Utilization > 80%                                      │
│  - Request Count Per Target > 1000                               │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            │ Triggers
                            ▼
                 ┌──────────────────────┐
                 │  Auto Scaling Policy │
                 │  ───────────────────│
                 │  - Scale Out: +1 task│
                 │  - Scale In: -1 task │
                 │  - Cooldown: 60s out │
                 │  - Cooldown: 300s in │
                 └──────────┬───────────┘
                            │
                            │ Adjusts
                            ▼
                 ┌──────────────────────┐
                 │   ECS Service        │
                 │   ───────────────── │
                 │   Min: 1 task        │
                 │   Desired: 2 tasks   │
                 │   Max: 10 tasks      │
                 └──────────────────────┘
```

## Data Flow (Whiteboard Sync)

```
┌──────────┐                ┌──────────┐
│ User A   │                │ User B   │
└────┬─────┘                └────┬─────┘
     │                           │
     │ Draw on board             │ Views board
     │                           │
     ▼                           ▼
┌──────────────┐         ┌──────────────┐
│ ECS Task 1   │         │ ECS Task 2   │
│ (via ALB)    │         │ (via ALB)    │
└──────┬───────┘         └──────┬───────┘
       │                        │
       │ Publish                │ Subscribe
       │ drawing event          │ to channel
       │                        │
       └────────▶┌──────────────┐◄────────┘
                 │    Redis     │
                 │   Pub/Sub    │
                 │              │
                 └──────────────┘
                        │
                        │ Real-time sync
                        │
       ┌────────────────┴────────────────┐
       │                                 │
       ▼                                 ▼
┌──────────────┐                 ┌──────────────┐
│ ECS Task 1   │                 │ ECS Task 2   │
│ Broadcasts   │                 │ Receives     │
│ to User A    │                 │ & sends to   │
│              │                 │ User B       │
└──────┬───────┘                 └──────┬───────┘
       │                                │
       │ Persist to S3                  │ Persist to S3
       │                                │
       └────────▶┌──────────────┐◄──────┘
                 │      S3      │
                 │  Board Data  │
                 └──────────────┘
```

## Monitoring & Observability

```
┌────────────────────────────────────────────────────────────────┐
│                     CloudWatch Dashboard                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │
│  │  ECS Metrics │  │  ALB Metrics │  │ Redis Metrics│        │
│  │  - CPU/Memory│  │  - Requests  │  │  - CPU       │        │
│  │  - Task Count│  │  - Latency   │  │  - Connections│       │
│  └──────────────┘  └──────────────┘  └──────────────┘        │
│  ┌──────────────────────────────────────────────────┐         │
│  │           Application Logs (Recent)              │         │
│  │  - Error logs                                    │         │
│  │  - Access logs                                   │         │
│  │  - Debug logs                                    │         │
│  └──────────────────────────────────────────────────┘         │
└────────────────────────────────────────────────────────────────┘
                             │
                             │ Triggers
                             ▼
                  ┌──────────────────────┐
                  │  CloudWatch Alarms   │
                  │  ───────────────────│
                  │  - High CPU (>85%)   │
                  │  - High Memory (>90%)│
                  │  - Unhealthy Targets │
                  │  - High Latency      │
                  └──────────┬───────────┘
                             │
                             │ Notifies (optional)
                             ▼
                  ┌──────────────────────┐
                  │    SNS Topic         │
                  │    ────────────────  │
                  │    Email/SMS         │
                  └──────────────────────┘
```

## IAM Permissions Flow

```
┌──────────────────────────────────────────────────────────────┐
│                        ECS Task                               │
└───────────────────────┬──────────────────────────────────────┘
                        │
                        │ Assumes Role
                        ▼
            ┌───────────────────────┐
            │  ECS Task Role        │
            │  ────────────────────│
            │  Permissions:         │
            │  - S3 Read/Write      │
            │  - CloudWatch Logs    │
            └───────┬───────────────┘
                    │
        ┌───────────┴───────────┐
        │                       │
        ▼                       ▼
┌──────────────┐       ┌──────────────┐
│      S3      │       │  CloudWatch  │
│  Operations  │       │    Logs      │
└──────────────┘       └──────────────┘

┌──────────────────────────────────────────────────────────────┐
│                   ECS Task Execution                          │
└───────────────────────┬──────────────────────────────────────┘
                        │
                        │ Assumes Role
                        ▼
            ┌───────────────────────┐
            │ ECS Task Exec Role    │
            │ ────────────────────  │
            │ Permissions:          │
            │ - ECR Pull Images     │
            │ - CloudWatch Logs     │
            └───────────────────────┘
```

## Cost Breakdown (Free Tier)

```
┌─────────────────────────────────────────────────────────────┐
│                   Monthly Cost Estimate                      │
│                    (US East 1)                               │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ECS Fargate (2 tasks, 24/7)                                │
│  - 256 CPU / 512 MB Memory                                  │
│  - ~360 vCPU hours/month                                    │
│  - Free tier: 50k vCPU hours free                           │
│  Cost: $0 (within free tier)                                │
│                                                              │
│  ALB (Application Load Balancer)                            │
│  - 750 hours/month                                          │
│  - Free tier: 750 hours free                                │
│  Cost: $0 (within free tier)                                │
│                                                              │
│  ElastiCache Redis (cache.t3.micro)                         │
│  - NOT in free tier                                         │
│  - $0.017/hour × 730 hours                                  │
│  Cost: ~$12.41/month                                        │
│                                                              │
│  S3 Storage                                                  │
│  - Assuming <5GB storage                                    │
│  - Free tier: 5GB free                                      │
│  Cost: $0 (within free tier)                                │
│                                                              │
│  CloudWatch Logs                                             │
│  - Assuming <5GB ingestion                                  │
│  - Free tier: 5GB free                                      │
│  Cost: $0 (within free tier)                                │
│                                                              │
│  Data Transfer                                               │
│  - First 100GB free                                         │
│  Cost: $0 (within free tier)                                │
│                                                              │
├─────────────────────────────────────────────────────────────┤
│  TOTAL ESTIMATED COST: ~$12.41/month                        │
└─────────────────────────────────────────────────────────────┘

Note: Replace Redis ElastiCache with self-hosted Redis in ECS
      to reduce cost to ~$0/month (fully free tier)
```
