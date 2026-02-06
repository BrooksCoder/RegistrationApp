#!/usr/bin/env pwsh
<#
.SYNOPSIS
Redeploy backend container with environment variables for database connection
#>

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Redeploy Backend with Environment Variables" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$resourceGroup = "rg-registration-app"
$backendName = "registration-api-2807"
$acrName = "registrationappacr"
$acrServer = "$acrName.azurecr.io"
$location = "centralindia"
$sqlServer = "regsql2807"
$sqlDb = "RegistrationAppDb"
$sqlUser = "sqladmin"
$sqlPass = "YourSecurePassword123!@#"

Write-Host "[1/5] Getting ACR credentials..." -ForegroundColor Yellow
try {
    $acrUser = az acr credential show --resource-group $resourceGroup --name $acrName --query username -o tsv
    $acrPassword = az acr credential show --resource-group $resourceGroup --name $acrName --query "passwords[0].value" -o tsv
    Write-Host "[OK] ACR credentials obtained" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to get ACR credentials: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[2/5] Deleting old backend container..." -ForegroundColor Yellow
try {
    az container delete --resource-group $resourceGroup --name $backendName --yes 2>$null | Out-Null
    Write-Host "[OK] Old container deleted" -ForegroundColor Green
    Start-Sleep -Seconds 5
} catch {
    Write-Host "[WARN] Could not delete old container (may not exist)" -ForegroundColor Yellow
}

# Build connection string
$sqlFqdn = "$sqlServer.database.windows.net"
$connString = "Server=tcp:$sqlFqdn,1433;Initial Catalog=$sqlDb;Persist Security Info=False;User ID=$sqlUser;Password=$sqlPass;Encrypt=True;Connection Timeout=30;"

Write-Host ""
Write-Host "[3/5] Creating backend container with environment variables..." -ForegroundColor Yellow
Write-Host "Container Name: $backendName" -ForegroundColor Cyan
Write-Host "Image: $acrServer/registration-api:latest" -ForegroundColor Cyan
Write-Host "Connection String: $connString" -ForegroundColor Cyan

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
      --dns-name-label "registration-api-2807" `
      --location $location `
      --environment-variables `
        ASPNETCORE_ENVIRONMENT=Production `
        "ConnectionStrings__DefaultConnection=$connString"
    
    Write-Host "[OK] Backend container deployed" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to deploy container: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[4/5] Waiting for container to start (45 seconds)..." -ForegroundColor Yellow
Start-Sleep -Seconds 45

Write-Host ""
Write-Host "[5/5] Testing backend API..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://registration-api-2807.centralindia.azurecontainer.io/api/items" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    
    Write-Host "[OK] Backend is responding!" -ForegroundColor Green
    Write-Host "Status Code: $($response.StatusCode)" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  SUCCESS! Backend is running" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "API Endpoints:" -ForegroundColor Cyan
    Write-Host "  • GET Items: http://registration-api-2807.centralindia.azurecontainer.io/api/items" -ForegroundColor Cyan
    Write-Host "  • Swagger: http://registration-api-2807.centralindia.azurecontainer.io/swagger/index.html" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Frontend URL:" -ForegroundColor Cyan
    Write-Host "  • http://registration-frontend-prod.centralindia.azurecontainer.io" -ForegroundColor Cyan
    
} catch {
    Write-Host "[ERROR] Backend not responding yet" -ForegroundColor Red
    Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "This is normal if the container just started. Try again in 30 seconds." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "View container logs:" -ForegroundColor Cyan
    Write-Host "az container logs --resource-group $resourceGroup --name $backendName --tail 50" -ForegroundColor Cyan
}

Write-Host ""
