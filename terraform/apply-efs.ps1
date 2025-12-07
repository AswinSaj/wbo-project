# Apply EFS configuration without interruption
Set-Location d:\wbo-v2\terraform

Write-Host "Applying Terraform configuration for EFS..."  -ForegroundColor Green

# Run terraform apply
$process = Start-Process -FilePath "terraform" -ArgumentList "apply", "-auto-approve" -PassThru -NoNewWindow -Wait

if ($process.ExitCode -eq 0) {
    Write-Host "`n✓ Terraform apply completed successfully!" -ForegroundColor Green
    
    # Get outputs
    Write-Host "`nALB URL:" -ForegroundColor Cyan
    terraform output -raw alb_dns_name
    
    Write-Host "`n`nEFS File System ID:" -ForegroundColor Cyan
    terraform output -raw efs_file_system_id
    
    Write-Host "`n`nChecking ECS service status..." -ForegroundColor Cyan
    aws ecs describe-services --cluster wbo-cluster --services wbo-service --query 'services[0].{status:status,desired:desiredCount,running:runningCount}' --output table
} else {
    Write-Host "`n✗ Terraform apply failed with exit code $($process.ExitCode)" -ForegroundColor Red
}
