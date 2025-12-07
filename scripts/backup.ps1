# Backup WBO S3 Data Script

param(
    [Parameter(Mandatory=$false)]
    [string]$BackupDir = ".\backups",
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "us-east-1"
)

Write-Host "WBO S3 Backup Tool" -ForegroundColor Cyan
Write-Host "==================" -ForegroundColor Cyan
Write-Host ""

# Get S3 bucket name from Terraform output
Set-Location -Path "..\terraform"
$bucketName = terraform output -raw s3_bucket_name 2>$null

if (-not $bucketName) {
    Write-Host "✗ Could not get S3 bucket name from Terraform output" -ForegroundColor Red
    Write-Host "Make sure Terraform has been applied successfully" -ForegroundColor Yellow
    exit 1
}

Write-Host "Bucket: $bucketName" -ForegroundColor White
Write-Host "Backup Directory: $BackupDir" -ForegroundColor White
Write-Host ""

# Create backup directory if it doesn't exist
if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir | Out-Null
    Write-Host "✓ Created backup directory" -ForegroundColor Green
}

# Create timestamped backup folder
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$backupPath = Join-Path $BackupDir $timestamp

Write-Host "Backing up S3 bucket to: $backupPath" -ForegroundColor Yellow
Write-Host ""

# Sync S3 bucket to local directory
aws s3 sync "s3://$bucketName" $backupPath --region $Region

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✓ Backup completed successfully!" -ForegroundColor Green
    Write-Host "Backup location: $backupPath" -ForegroundColor White
    
    # Get backup size
    $size = (Get-ChildItem $backupPath -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Host "Backup size: $([math]::Round($size, 2)) MB" -ForegroundColor White
} else {
    Write-Host "✗ Backup failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
