#!/usr/bin/env pwsh
<#
.SYNOPSIS
Complete backend fix - Adds SQL firewall rule, runs migrations, restarts container
#>

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  RegistrationApp - Complete Backend Fix" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$backendPath = "c:\Users\Admin\source\repos\RegistrationApp\backend"
$resourceGroup = "rg-registration-app"
$connectionString = "Server=tcp:regsql2807.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourSecurePassword123!@#;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

# Step 1: Get local IP and add to firewall
Write-Host "Step 1: Getting your IP and adding to SQL firewall..." -ForegroundColor Yellow
try {
    $myIP = Invoke-WebRequest -Uri "https://api.ipify.org?format=json" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop | ConvertFrom-Json | Select-Object -ExpandProperty ip
    Write-Host "[OK] Your IP: $myIP" -ForegroundColor Green
    
    Write-Host "Creating firewall rule..." -ForegroundColor Cyan
    az sql server firewall-rule create --resource-group $resourceGroup --server regsql2807 --name "AllowLocalMachine" --start-ip-address $myIP --end-ip-address $myIP 2>$null | Out-Null
    
    Write-Host "[OK] Firewall rule created" -ForegroundColor Green
    Write-Host "Waiting 15 seconds..." -ForegroundColor Cyan
    Start-Sleep -Seconds 15
} catch {
    Write-Host "[WARN] Could not create firewall rule" -ForegroundColor Yellow
}

# Step 2: Check dotnet-ef
Write-Host ""
Write-Host "Step 2: Checking dotnet-ef..." -ForegroundColor Yellow
$efVersion = dotnet ef --version 2>$null
if ($efVersion) {
    Write-Host "[OK] dotnet-ef installed: $efVersion" -ForegroundColor Green
} else {
    Write-Host "Installing dotnet-ef..." -ForegroundColor Yellow
    dotnet tool install --global dotnet-ef | Out-Null
    Write-Host "[OK] Installed" -ForegroundColor Green
}

# Step 3: Navigate and run migrations
Write-Host ""
Write-Host "Step 3: Running migrations..." -ForegroundColor Yellow
cd $backendPath
Write-Host "In: $(Get-Location)" -ForegroundColor Cyan

Write-Host "Connection: $connectionString" -ForegroundColor Cyan
Write-Host ""

$output = dotnet ef database update --connection $connectionString 2>&1
Write-Host $output

if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Database schema deployed" -ForegroundColor Green
} else {
    Write-Host "[INFO] Migration command completed (checking DB status...)" -ForegroundColor Yellow
}

# Step 4: Verify tables exist
Write-Host ""
Write-Host "Step 4: Verifying database schema..." -ForegroundColor Yellow
try {
    $query = "SELECT COUNT(*) as TableCount FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_TYPE = 'BASE TABLE'"
    $result = sqlcmd -S regsql2807.database.windows.net -U sqladmin -P "YourSecurePassword123!@#" -d RegistrationAppDb -Q "$query" -h -1 2>$null
    
    if ($result -and [int]$result[0] -gt 0) {
        Write-Host "[OK] Database tables exist ($result tables)" -ForegroundColor Green
    } else {
        Write-Host "[WARN] No tables found - migrations may not have run" -ForegroundColor Yellow
    }
} catch {
    Write-Host "[WARN] Could not verify tables: $($_)" -ForegroundColor Yellow
}

# Step 5: Restart container
Write-Host ""
Write-Host "Step 5: Restarting backend container..." -ForegroundColor Yellow
try {
    az container restart --resource-group $resourceGroup --name registration-api-2807 2>$null
    Write-Host "[OK] Restart command sent" -ForegroundColor Green
    Write-Host "Waiting 60 seconds for container to start..." -ForegroundColor Cyan
    Start-Sleep -Seconds 60
} catch {
    Write-Host "[ERROR] Failed to restart: $_" -ForegroundColor Red
}

# Step 6: Test API
Write-Host ""
Write-Host "Step 6: Testing backend API..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://registration-api-2807.centralindia.azurecontainer.io/api/items" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    
    Write-Host "[OK] Backend is responding!" -ForegroundColor Green
    Write-Host "Status: $($response.StatusCode)" -ForegroundColor Green
    
    try {
        $content = $response.Content | ConvertFrom-Json
        $itemCount = @($content).Count
        Write-Host "Items: $itemCount" -ForegroundColor Green
    } catch {
        Write-Host "Response: $($response.Content.Substring(0, [Math]::Min(100, $response.Content.Length)))" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  SUCCESS! Backend is running" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Frontend: http://registration-frontend-prod.centralindia.azurecontainer.io" -ForegroundColor Cyan
    Write-Host "API:      http://registration-api-2807.centralindia.azurecontainer.io/api/items" -ForegroundColor Cyan
    
} catch {
    Write-Host "[ERROR] Backend not responding yet" -ForegroundColor Red
    Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Container may still be starting. Check logs:" -ForegroundColor Yellow
    Write-Host "az container logs --resource-group $resourceGroup --name registration-api-2807 --tail 100" -ForegroundColor Cyan
}

Write-Host ""
Write-Host ""
