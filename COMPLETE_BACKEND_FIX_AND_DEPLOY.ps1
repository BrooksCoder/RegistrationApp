#!/usr/bin/env pwsh
<#
.SYNOPSIS
Complete backend fix: Build, push, and redeploy
Handles all remaining steps automatically
#>

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  RegistrationApp - COMPLETE Backend Fix and Deployment   ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Configuration
$resourceGroup = "rg-registration-app"
$acrName = "registrationappacr"
$acrServer = "$acrName.azurecr.io"
$location = "centralindia"
$backendName = "registration-api-2807"
$sqlServer = "regsql2807"
$sqlDb = "RegistrationAppDb"
$sqlUser = "sqladmin"
$sqlPass = "YourSecurePassword123!@#"

Write-Host "[STEP 1/5] Building Docker image in Azure Container Registry..." -ForegroundColor Yellow
Write-Host ""

try {
    Write-Host "Command: az acr build --registry $acrName --image registration-api:latest --file backend/Dockerfile ./backend" -ForegroundColor Cyan
    Write-Host ""
    
    # Use Azure to build the image (no local Docker needed)
    $buildOutput = az acr build `
      --registry $acrName `
      --image "registration-api:latest" `
      --file backend/Dockerfile `
      c:\Users\Admin\source\repos\RegistrationApp\backend `
      2>&1
    
    Write-Host $buildOutput
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[✓] Image built and pushed successfully" -ForegroundColor Green
    } else {
        Write-Host "[✗] Build failed - check errors above" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "[✗] Build error: $($_)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[STEP 2/5] Getting ACR credentials..." -ForegroundColor Yellow

try {
    $acrUser = az acr credential show --resource-group $resourceGroup --name $acrName --query username -o tsv
    $acrPassword = az acr credential show --resource-group $resourceGroup --name $acrName --query "passwords[0].value" -o tsv
    
    if ($acrUser -and $acrPassword) {
        Write-Host "[✓] ACR credentials obtained" -ForegroundColor Green
        Write-Host "    Username: $acrUser" -ForegroundColor Cyan
    } else {
        throw "Failed to retrieve ACR credentials"
    }
} catch {
    Write-Host "[✗] Error: $($_)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[STEP 3/5] Deleting old backend container..." -ForegroundColor Yellow

try {
    Write-Host "Container: $backendName" -ForegroundColor Cyan
    az container delete --resource-group $resourceGroup --name $backendName --yes 2>$null
    Write-Host "[✓] Old container deleted" -ForegroundColor Green
    Start-Sleep -Seconds 10
} catch {
    Write-Host "[!] Container deletion note: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[STEP 4/5] Creating new backend container with fixed image..." -ForegroundColor Yellow

# Build connection string
$sqlFqdn = "$sqlServer.database.windows.net"
$connString = "Server=tcp:$sqlFqdn,1433;Initial Catalog=$sqlDb;Persist Security Info=False;User ID=$sqlUser;Password=$sqlPass;Encrypt=True;Connection Timeout=30;"

Write-Host ""
Write-Host "Container Configuration:" -ForegroundColor Cyan
Write-Host "  Name: $backendName" -ForegroundColor Cyan
Write-Host "  Image: $acrServer/registration-api:latest" -ForegroundColor Cyan
Write-Host "  Region: $location" -ForegroundColor Cyan
Write-Host "  Port: 80" -ForegroundColor Cyan
Write-Host "  Environment:" -ForegroundColor Cyan
Write-Host "    ASPNETCORE_ENVIRONMENT=Production" -ForegroundColor Cyan
Write-Host "    ConnectionStrings__DefaultConnection=<connection string>" -ForegroundColor Cyan
Write-Host ""

try {
    az container create `
      --resource-group $resourceGroup `
      --name $backendName `
      --image "$acrServer/registration-api:latest" `
      --cpu 1 `
      --memory 1 `
      --os-type Linux `
      --registry-login-server $acrServer `
      --registry-username $acrUser `
      --registry-password $acrPassword `
      --ports 80 `
      --dns-name-label $backendName `
      --location $location `
      --environment-variables `
        "ASPNETCORE_ENVIRONMENT=Production" `
        "ConnectionStrings__DefaultConnection=$connString"
    
    Write-Host "[✓] Container created successfully" -ForegroundColor Green
} catch {
    Write-Host "[✗] Container creation failed: $($_)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[STEP 5/5] Waiting for container to start and testing..." -ForegroundColor Yellow
Write-Host "Waiting 90 seconds for application to initialize..." -ForegroundColor Cyan

$waitCount = 0
$maxWait = 90
$testUrl = "http://$backendName.centralindia.azurecontainer.io/api/items"

while ($waitCount -lt $maxWait) {
    Write-Host "." -NoNewline
    Start-Sleep -Seconds 3
    $waitCount += 3
    
    if ($waitCount % 15 -eq 0) {
        try {
            $testResponse = Invoke-WebRequest -Uri $testUrl -UseBasicParsing -TimeoutSec 5 -ErrorAction SilentlyContinue
            if ($testResponse.StatusCode -eq 200) {
                Write-Host ""
                Write-Host "[✓✓✓] SUCCESS! Backend is responding!" -ForegroundColor Green
                break
            }
        } catch {
            # Still waiting
        }
    }
}

Write-Host ""
Write-Host ""

# Final test
Write-Host "[FINAL TEST] Testing backend API..." -ForegroundColor Yellow
Write-Host "URL: $testUrl" -ForegroundColor Cyan
Write-Host ""

try {
    $response = Invoke-WebRequest -Uri $testUrl -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║              ✓ SUCCESS - BACKEND IS WORKING!               ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "Status Code: $($response.StatusCode)" -ForegroundColor Green
    Write-Host ""
    Write-Host "📊 API Endpoints:" -ForegroundColor Cyan
    Write-Host "   GET  http://$backendName.centralindia.azurecontainer.io/api/items" -ForegroundColor Cyan
    Write-Host "   GET  http://$backendName.centralindia.azurecontainer.io/swagger" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "🎨 Frontend URL:" -ForegroundColor Cyan
    Write-Host "   http://registration-frontend-prod.centralindia.azurecontainer.io" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📝 Next Steps:" -ForegroundColor Yellow
    Write-Host "   1. Open frontend URL in browser" -ForegroundColor Yellow
    Write-Host "   2. Hard refresh (Ctrl+Shift+R)" -ForegroundColor Yellow
    Write-Host "   3. You should see the dashboard WITHOUT 502 errors" -ForegroundColor Yellow
    Write-Host ""
    
} catch {
    Write-Host "⚠️  Backend not responding yet (may still be starting)" -ForegroundColor Yellow
    Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Check container logs:" -ForegroundColor Cyan
    Write-Host "az container logs --resource-group $resourceGroup --name $backendName --tail 100" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "If container is still crashing:" -ForegroundColor Yellow
    Write-Host "1. Run the logs command above" -ForegroundColor Yellow
    Write-Host "2. Look for error messages in the output" -ForegroundColor Yellow
    Write-Host "3. Verify database connection string is correct" -ForegroundColor Yellow
}

Write-Host ""
