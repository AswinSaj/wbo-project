# Scale WBO Service Script

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("up", "down", "status")]
    [string]$Action,
    
    [Parameter(Mandatory=$false)]
    [int]$DesiredCount = 2,
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "us-east-1"
)

$ClusterName = "wbo-cluster"
$ServiceName = "wbo-service"

Write-Host "WBO Service Scaling Tool" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan
Write-Host ""

switch ($Action) {
    "status" {
        Write-Host "Fetching current service status..." -ForegroundColor Yellow
        $service = aws ecs describe-services --cluster $ClusterName --services $ServiceName --region $Region | ConvertFrom-Json
        
        if ($service.services.Count -gt 0) {
            $svc = $service.services[0]
            Write-Host "Cluster: $ClusterName" -ForegroundColor White
            Write-Host "Service: $ServiceName" -ForegroundColor White
            Write-Host "Status: $($svc.status)" -ForegroundColor Green
            Write-Host "Desired Count: $($svc.desiredCount)" -ForegroundColor White
            Write-Host "Running Count: $($svc.runningCount)" -ForegroundColor White
            Write-Host "Pending Count: $($svc.pendingCount)" -ForegroundColor White
        } else {
            Write-Host "Service not found!" -ForegroundColor Red
        }
    }
    
    "up" {
        Write-Host "Scaling UP service to $DesiredCount tasks..." -ForegroundColor Yellow
        aws ecs update-service --cluster $ClusterName --service $ServiceName --desired-count $DesiredCount --region $Region
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Service scaled to $DesiredCount tasks" -ForegroundColor Green
        } else {
            Write-Host "✗ Failed to scale service" -ForegroundColor Red
        }
    }
    
    "down" {
        Write-Host "Scaling DOWN service to $DesiredCount tasks..." -ForegroundColor Yellow
        
        if ($DesiredCount -eq 0) {
            Write-Host "WARNING: Scaling to 0 will stop all tasks!" -ForegroundColor Red
            $confirm = Read-Host "Are you sure? (yes/no)"
            if ($confirm -ne "yes") {
                Write-Host "Operation cancelled" -ForegroundColor Yellow
                exit 0
            }
        }
        
        aws ecs update-service --cluster $ClusterName --service $ServiceName --desired-count $DesiredCount --region $Region
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Service scaled to $DesiredCount tasks" -ForegroundColor Green
        } else {
            Write-Host "✗ Failed to scale service" -ForegroundColor Red
        }
    }
}

Write-Host ""
