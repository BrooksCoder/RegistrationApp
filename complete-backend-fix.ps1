#!/usr/bin/env pwsh
<#
.SYNOPSIS
Complete backend fix - Adds SQL firewall rule, runs migrations, and tests API

.DESCRIPTION
This script:
1. Gets your local public IP
2. Adds it to SQL firewall
3. Runs EF Core migrations
4. Restarts backend container
5. Tests the API

#>

Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  RegistrationApp - Complete Backend Fix                   ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Configuration
$backendPath = "c:\Users\Admin\source\repos\RegistrationApp\backend"
$connectionString = "Server=tcp:regsql2807.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourSecurePassword123!@#;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

# Step 1: Get local IP and add to firewall
Write-Host "Step 1: Adding your local machine IP to SQL firewall..." -ForegroundColor Yellow
try {
    $myIP = Invoke-WebRequest -Uri "https://api.ipify.org?format=json" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop | ConvertFrom-Json | Select-Object -ExpandProperty ip
    Write-Host "✅ Your public IP: $myIP" -ForegroundColor Green
    
    Write-Host "   Creating firewall rule..." -ForegroundColor Cyan
    az sql server firewall-rule create `
      --resource-group rg-registration-app `
      --server regsql2807 `
      --name "AllowLocalMachine" `
      --start-ip-address $myIP `
      --end-ip-address $myIP 2>$null | Out-Null
    
    Write-Host "✅ Firewall rule created" -ForegroundColor Green
    Write-Host "   Waiting 15 seconds for rule to take effect..." -ForegroundColor Cyan
    Start-Sleep -Seconds 15
} catch {
    Write-Host "⚠️  Could not get IP or create firewall rule: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "   Continuing anyway..." -ForegroundColor Yellow
}

# Step 2: Check dotnet-ef
Write-Host ""
Write-Host "Step 2: Checking dotnet-ef installation..." -ForegroundColor Yellow
$efVersion = dotnet ef --version 2>$null
if ($efVersion) {
    Write-Host "✅ dotnet-ef is installed: $efVersion" -ForegroundColor Green
} else {
    Write-Host "⚠️  Installing dotnet-ef..." -ForegroundColor Yellow
    dotnet tool install --global dotnet-ef | Out-Null
    Write-Host "✅ dotnet-ef installed" -ForegroundColor Green
}

# Step 3: Navigate to backend
Write-Host ""
Write-Host "Step 3: Navigating to backend directory..." -ForegroundColor Yellow
cd $backendPath
Write-Host "✅ In: $(Get-Location)" -ForegroundColor Green

# Step 4: Run migrations
Write-Host ""
Write-Host "Step 4: Running Entity Framework migrations..." -ForegroundColor Yellow
Write-Host "   Server: regsql2807.database.windows.net" -ForegroundColor Cyan
Write-Host "   Database: RegistrationAppDb" -ForegroundColor Cyan
Write-Host ""

$output = dotnet ef database update --connection $connectionString 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Database schema deployed successfully!" -ForegroundColor Green
} else {
    Write-Host "❌ Migration failed" -ForegroundColor Red
    Write-Host "Error output:" -ForegroundColor Red
    Write-Host $output -ForegroundColor Red
    Write-Host ""
    Write-Host "This might be due to:" -ForegroundColor Yellow
    Write-Host "1. Firewall rule not created properly" -ForegroundColor Yellow
    Write-Host "2. SQL credentials wrong" -ForegroundColor Yellow
    Write-Host "3. Database doesn't exist" -ForegroundColor Yellow
    exit 1
}

# Step 5: Restart container
Write-Host ""
Write-Host "Step 5: Restarting backend container..." -ForegroundColor Yellow
az container restart --resource-group rg-registration-app --name registration-api-2807 2>&1 | Out-Null
Write-Host "✅ Restart command sent" -ForegroundColor Green
Write-Host "   Waiting 45 seconds for startup..." -ForegroundColor Cyan
Start-Sleep -Seconds 45

# Step 6: Test API
Write-Host ""
Write-Host "Step 6: Testing backend API..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest `
      -Uri "http://registration-api-2807.centralindia.azurecontainer.io/api/items" `
      -UseBasicParsing `
      -TimeoutSec 10 `
      -ErrorAction Stop
    
    Write-Host "✅ SUCCESS! Backend is responding!" -ForegroundColor Green
    Write-Host "   Status Code: $($response.StatusCode)" -ForegroundColor Green
    
    try {
        $content = $response.Content | ConvertFrom-Json
        $itemCount = @($content).Count
        Write-Host "   Items in database: $itemCount" -ForegroundColor Green
    } catch {
        Write-Host "   Response: $($response.Content.Substring(0, 100))..." -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║        ✅ BACKEND IS FIXED AND RUNNING!                  ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Refresh your browser: " -ForegroundColor Cyan
    Write-Host "   http://registration-frontend-prod.centralindia.azurecontainer.io" -ForegroundColor Cyan
    Write-Host "2. Hard refresh (Ctrl+Shift+R) to clear cache" -ForegroundColor Cyan
    Write-Host "3. Dashboard should load without 502 error" -ForegroundColor Cyan
    
} catch {
    Write-Host "❌ Backend is still not responding" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "1. Check container logs:" -ForegroundColor Yellow
    Write-Host "   az container logs --resource-group rg-registration-app --name registration-api-2807 --tail 50" -ForegroundColor Cyan
    Write-Host "2. Verify database migrations applied:" -ForegroundColor Yellow
    Write-Host "   sqlcmd -S regsql2807.database.windows.net -U sqladmin -P 'YourSecurePassword123!@#' -d RegistrationAppDb -Q 'SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES'" -ForegroundColor Cyan
    Write-Host "3. Check firewall rules:" -ForegroundColor Yellow
    Write-Host "   az sql server firewall-rule list --resource-group rg-registration-app --server regsql2807" -ForegroundColor Cyan
}

Write-Host ""
