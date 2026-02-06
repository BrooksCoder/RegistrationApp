#!/usr/bin/env pwsh
<#
.SYNOPSIS
Fix 502 Bad Gateway by running EF Core database migrations

.DESCRIPTION
The backend container is crashing because the database schema doesn't exist yet.
This script runs the EF Core migrations to initialize the database.

#>

Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  RegistrationApp - EF Core Database Migration Fix         ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Configuration
$backendPath = "c:\Users\Admin\source\repos\RegistrationApp\backend"
$connectionString = "Server=tcp:regsql2807.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourSecurePassword123!@#;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

Write-Host "Step 1: Checking dotnet-ef installation..." -ForegroundColor Yellow
$efVersion = dotnet ef --version 2>$null
if ($efVersion) {
    Write-Host "✅ dotnet-ef is installed: $efVersion" -ForegroundColor Green
} else {
    Write-Host "⚠️  dotnet-ef not found. Installing..." -ForegroundColor Yellow
    dotnet tool install --global dotnet-ef
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ dotnet-ef installed successfully" -ForegroundColor Green
    } else {
        Write-Host "❌ Failed to install dotnet-ef" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "Step 2: Navigating to backend directory..." -ForegroundColor Yellow
cd $backendPath
Write-Host "✅ In directory: $(Get-Location)" -ForegroundColor Green

Write-Host ""
Write-Host "Step 3: Running EF Core database migrations..." -ForegroundColor Yellow
Write-Host "Connection: regsql2807.database.windows.net" -ForegroundColor Cyan
Write-Host "Database: RegistrationAppDb" -ForegroundColor Cyan
Write-Host ""

dotnet ef database update --connection $connectionString

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Database schema deployed successfully!" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "❌ Migration failed with exit code: $LASTEXITCODE" -ForegroundColor Red
    Write-Host "Try running manually:"
    Write-Host "  dotnet ef database update --connection `"$connectionString`"" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Step 4: Restarting backend container..." -ForegroundColor Yellow
az container restart --resource-group rg-registration-app --name registration-api-2807

Write-Host "✅ Restart command sent" -ForegroundColor Green
Write-Host "Waiting 40 seconds for container to start..." -ForegroundColor Cyan
Start-Sleep -Seconds 40

Write-Host ""
Write-Host "Step 5: Testing backend API..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest `
      -Uri "http://registration-api-2807.centralindia.azurecontainer.io/api/items" `
      -UseBasicParsing `
      -TimeoutSec 10 `
      -ErrorAction Stop
    
    Write-Host "✅ SUCCESS! Backend is now responding!" -ForegroundColor Green
    Write-Host "   Status Code: $($response.StatusCode)" -ForegroundColor Green
    
    $content = $response.Content | ConvertFrom-Json
    $itemCount = @($content).Count
    Write-Host "   Items in database: $itemCount" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║           ✅ BACKEND IS NOW FIXED AND RUNNING!            ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "Next: Refresh the frontend in your browser:" -ForegroundColor Cyan
    Write-Host "  http://registration-frontend-prod.centralindia.azurecontainer.io" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "The dashboard should now load without the 502 error!" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Backend is still not responding" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    
    Write-Host ""
    Write-Host "Troubleshooting steps:" -ForegroundColor Yellow
    Write-Host "1. Check backend container logs:" -ForegroundColor Yellow
    Write-Host "   az container logs --resource-group rg-registration-app --name registration-api-2807 --tail 50" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "2. Check if migrations were actually applied:" -ForegroundColor Yellow
    Write-Host "   sqlcmd -S regsql2807.database.windows.net -U sqladmin -P 'YourSecurePassword123!@#' -d RegistrationAppDb -Q 'SELECT * FROM INFORMATION_SCHEMA.TABLES'" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "3. Manually check database via Azure Portal:" -ForegroundColor Yellow
    Write-Host "   SQL Server 'regsql2807' → Database 'RegistrationAppDb' → Tables" -ForegroundColor Cyan
}

Write-Host ""
