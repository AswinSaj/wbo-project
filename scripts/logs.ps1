# View WBO Application Logs Script

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("tail", "recent", "errors")]
    [string]$Mode = "tail",
    
    [Parameter(Mandatory=$false)]
    [int]$Lines = 50,
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "us-east-1"
)

$LogGroup = "/ecs/wbo"

Write-Host "WBO Application Logs" -ForegroundColor Cyan
Write-Host "====================" -ForegroundColor Cyan
Write-Host ""

switch ($Mode) {
    "tail" {
        Write-Host "Tailing logs (Ctrl+C to stop)..." -ForegroundColor Yellow
        Write-Host ""
        aws logs tail $LogGroup --follow --region $Region
    }
    
    "recent" {
        Write-Host "Fetching last $Lines log entries..." -ForegroundColor Yellow
        Write-Host ""
        aws logs tail $LogGroup --since 1h --region $Region | Select-Object -Last $Lines
    }
    
    "errors" {
        Write-Host "Searching for errors in last 1 hour..." -ForegroundColor Yellow
        Write-Host ""
        
        $startTime = (Get-Date).AddHours(-1).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss")
        
        aws logs filter-log-events `
            --log-group-name $LogGroup `
            --start-time (Get-Date).AddHours(-1).Ticks `
            --filter-pattern "ERROR" `
            --region $Region | ConvertFrom-Json | Select-Object -ExpandProperty events | ForEach-Object {
                $timestamp = [DateTimeOffset]::FromUnixTimeMilliseconds($_.timestamp).LocalDateTime
                Write-Host "[$timestamp] $($_.message)" -ForegroundColor Red
            }
    }
}

Write-Host ""
