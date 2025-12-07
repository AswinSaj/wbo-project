# WBO Deployment Scripts

## Quick Start Script for Windows PowerShell

Write-Host "WBO AWS Deployment - Quick Start" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green
Write-Host ""

# Check prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor Yellow

# Check Terraform
if (Get-Command terraform -ErrorAction SilentlyContinue) {
    $tfVersion = terraform version | Select-String -Pattern "Terraform v(\d+\.\d+\.\d+)"
    Write-Host "✓ Terraform installed: $($tfVersion.Matches.Value)" -ForegroundColor Green
} else {
    Write-Host "✗ Terraform not found. Please install from: https://www.terraform.io/downloads" -ForegroundColor Red
    exit 1
}

# Check AWS CLI
if (Get-Command aws -ErrorAction SilentlyContinue) {
    Write-Host "✓ AWS CLI installed" -ForegroundColor Green
} else {
    Write-Host "✗ AWS CLI not found. Please install from: https://aws.amazon.com/cli/" -ForegroundColor Red
    exit 1
}

# Check AWS credentials
try {
    $awsIdentity = aws sts get-caller-identity 2>$null | ConvertFrom-Json
    Write-Host "✓ AWS credentials configured for account: $($awsIdentity.Account)" -ForegroundColor Green
} catch {
    Write-Host "✗ AWS credentials not configured. Run: aws configure" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "All prerequisites met!" -ForegroundColor Green
Write-Host ""

# Navigate to terraform directory
Set-Location -Path ".\terraform"

# Initialize Terraform
Write-Host "Initializing Terraform..." -ForegroundColor Yellow
terraform init

if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Terraform initialization failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Terraform initialized successfully" -ForegroundColor Green
Write-Host ""

# Create tfvars if it doesn't exist
if (-not (Test-Path "terraform.tfvars")) {
    Write-Host "Creating terraform.tfvars from example..." -ForegroundColor Yellow
    Copy-Item "terraform.tfvars.example" "terraform.tfvars"
    Write-Host "✓ Created terraform.tfvars - Please review and customize if needed" -ForegroundColor Green
}

Write-Host ""
Write-Host "Ready to deploy!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Review configuration: terraform plan" -ForegroundColor White
Write-Host "2. Deploy infrastructure: terraform apply" -ForegroundColor White
Write-Host "3. Get application URL: terraform output alb_url" -ForegroundColor White
Write-Host ""
Write-Host "Estimated deployment time: 10-15 minutes" -ForegroundColor Yellow
Write-Host ""

# Ask if user wants to continue with deployment
$continue = Read-Host "Do you want to run 'terraform plan' now? (y/n)"
if ($continue -eq 'y') {
    terraform plan
}
