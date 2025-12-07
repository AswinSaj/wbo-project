# Monitor WBO Application Health Script

param(
    [Parameter(Mandatory=$false)]
    [string]$Region = "us-east-1"
)

$ClusterName = "wbo-cluster"
$ServiceName = "wbo-service"

Write-Host "WBO Application Health Monitor" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan
Write-Host ""

# Function to display colored status
function Show-Status {
    param($label, $value, $isGood)
    $color = if ($isGood) { "Green" } else { "Red" }
    Write-Host "${label}: " -NoNewline -ForegroundColor White
    Write-Host $value -ForegroundColor $color
}

# Get Terraform outputs
Set-Location -Path "..\terraform"
$albUrl = terraform output -raw alb_url 2>$null
$logGroup = terraform output -raw cloudwatch_log_group 2>$null

Write-Host "=== ECS Service Status ===" -ForegroundColor Yellow
$service = aws ecs describe-services --cluster $ClusterName --services $ServiceName --region $Region | ConvertFrom-Json

if ($service.services.Count -gt 0) {
    $svc = $service.services[0]
    Show-Status "Service Status" $svc.status ($svc.status -eq "ACTIVE")
    Show-Status "Desired Tasks" $svc.desiredCount ($svc.desiredCount -gt 0)
    Show-Status "Running Tasks" $svc.runningCount ($svc.runningCount -eq $svc.desiredCount)
    Show-Status "Pending Tasks" $svc.pendingCount ($svc.pendingCount -eq 0)
} else {
    Write-Host "Service not found!" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== ALB Target Health ===" -ForegroundColor Yellow

# Get target group ARN
$targetGroups = aws elbv2 describe-target-groups --region $Region | ConvertFrom-Json
$wboTargetGroup = $targetGroups.TargetGroups | Where-Object { $_.TargetGroupName -like "wbo-tg*" } | Select-Object -First 1

if ($wboTargetGroup) {
    $targetHealth = aws elbv2 describe-target-health --target-group-arn $wboTargetGroup.TargetGroupArn --region $Region | ConvertFrom-Json
    
    $healthyCount = ($targetHealth.TargetHealthDescriptions | Where-Object { $_.TargetHealth.State -eq "healthy" }).Count
    $unhealthyCount = ($targetHealth.TargetHealthDescriptions | Where-Object { $_.TargetHealth.State -ne "healthy" }).Count
    
    Show-Status "Healthy Targets" $healthyCount ($healthyCount -gt 0)
    Show-Status "Unhealthy Targets" $unhealthyCount ($unhealthyCount -eq 0)
    
    if ($unhealthyCount -gt 0) {
        Write-Host ""
        Write-Host "Unhealthy Target Details:" -ForegroundColor Red
        $targetHealth.TargetHealthDescriptions | Where-Object { $_.TargetHealth.State -ne "healthy" } | ForEach-Object {
            Write-Host "  Target: $($_.Target.Id)" -ForegroundColor White
            Write-Host "  State: $($_.TargetHealth.State)" -ForegroundColor Red
            Write-Host "  Reason: $($_.TargetHealth.Reason)" -ForegroundColor Yellow
            Write-Host ""
        }
    }
}

Write-Host ""
Write-Host "=== Redis Status ===" -ForegroundColor Yellow

$redisClusters = aws elasticache describe-cache-clusters --region $Region | ConvertFrom-Json
$wboRedis = $redisClusters.CacheClusters | Where-Object { $_.CacheClusterId -like "wbo-redis*" } | Select-Object -First 1

if ($wboRedis) {
    Show-Status "Redis Status" $wboRedis.CacheClusterStatus ($wboRedis.CacheClusterStatus -eq "available")
    Show-Status "Node Type" $wboRedis.CacheNodeType $true
    Write-Host "Endpoint: $($wboRedis.CacheNodes[0].Endpoint.Address):$($wboRedis.CacheNodes[0].Endpoint.Port)" -ForegroundColor White
}

Write-Host ""
Write-Host "=== Recent Errors ===" -ForegroundColor Yellow

$recentErrors = aws logs filter-log-events `
    --log-group-name $logGroup `
    --start-time ([DateTimeOffset]::UtcNow.AddMinutes(-15).ToUnixTimeMilliseconds()) `
    --filter-pattern "ERROR" `
    --region $Region 2>$null | ConvertFrom-Json

if ($recentErrors.events.Count -gt 0) {
    Write-Host "Found $($recentErrors.events.Count) errors in last 15 minutes:" -ForegroundColor Red
    $recentErrors.events | Select-Object -First 5 | ForEach-Object {
        $timestamp = [DateTimeOffset]::FromUnixTimeMilliseconds($_.timestamp).LocalDateTime
        Write-Host "  [$timestamp] $($_.message)" -ForegroundColor Red
    }
} else {
    Write-Host "No errors found in last 15 minutes ✓" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Access Information ===" -ForegroundColor Yellow
Write-Host "Application URL: $albUrl" -ForegroundColor Cyan
Write-Host ""

# Test HTTP connectivity
Write-Host "Testing HTTP connectivity..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri $albUrl -Method Head -TimeoutSec 10 -UseBasicParsing
    if ($response.StatusCode -eq 200) {
        Write-Host "✓ Application is responding (HTTP $($response.StatusCode))" -ForegroundColor Green
    }
} catch {
    Write-Host "✗ Application is not responding: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Health check complete!" -ForegroundColor Cyan
Write-Host ""
