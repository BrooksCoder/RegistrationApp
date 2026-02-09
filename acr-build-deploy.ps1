#!/usr/bin/env pwsh
# ACR Build and Deploy - No Docker Desktop required

$ErrorActionPreference = "Stop"

$ResourceGroup = "rg-registration-app"
$ContainerName = "registration-api-prod"
$AcrName = "registrationappacr"
$AcrUrl = "$AcrName.azurecr.io"
$ImageName = "registration-api"
$ImageTag = "latest"
$BackendPath = ".\backend"

Write-Host ""
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "  AZURE ACR BUILD AND DEPLOYMENT" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Verify Azure Login
Write-Host "[1/4] Verifying Azure Login..." -ForegroundColor Yellow
$currentAccount = az account show --query "name" -o tsv
if (-not $currentAccount) {
    Write-Host "FAILED: Not logged into Azure. Run 'az login' first." -ForegroundColor Red
    exit 1
}
Write-Host "OK: Logged in as: $currentAccount" -ForegroundColor Green
Write-Host ""

# Step 2: Build in Azure ACR (no Docker Desktop needed)
Write-Host "[2/4] Building Docker Image in Azure ACR..." -ForegroundColor Yellow
Write-Host "  This uses Azure Container Registry build service" -ForegroundColor Cyan
Write-Host "  Building: $AcrUrl/$ImageName`:$ImageTag" -ForegroundColor Cyan

if (-not (Test-Path $BackendPath)) {
    Write-Host "FAILED: Backend directory not found at $BackendPath" -ForegroundColor Red
    exit 1
}

az acr build --registry $AcrName --image "$ImageName`:$ImageTag" --file "$BackendPath/Dockerfile" "$BackendPath"

if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILED: ACR build failed" -ForegroundColor Red
    exit 1
}
Write-Host "OK: Image built in ACR successfully" -ForegroundColor Green
Write-Host ""

# Step 3: Delete Old Container
Write-Host "[3/4] Cleaning up old container..." -ForegroundColor Yellow
try {
    $existingContainer = az container show --resource-group $ResourceGroup --name $ContainerName --query "id" -o tsv
}
catch {
    $existingContainer = $null
}

if ($existingContainer) {
    Write-Host "  Deleting: $ContainerName" -ForegroundColor Cyan
    az container delete --resource-group $ResourceGroup --name $ContainerName --yes | Out-Null
    Write-Host "  Waiting 10 seconds for cleanup..." -ForegroundColor Cyan
    Start-Sleep -Seconds 10
    Write-Host "OK: Container deleted" -ForegroundColor Green
}
else {
    Write-Host "OK: No existing container found" -ForegroundColor Green
}
Write-Host ""

# Step 4: Deploy New Container
Write-Host "[4/4] Deploying new container instance..." -ForegroundColor Yellow

$connString = "Server=tcp:regsql2807.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourSecurePassword123!@#;Encrypt=True;Connection Timeout=30;"

$acrUsername = az acr credential show --resource-group $ResourceGroup --name $AcrName --query "username" -o tsv
$acrPassword = az acr credential show --resource-group $ResourceGroup --name $AcrName --query "passwords[0].value" -o tsv

Write-Host "  Creating container instance..." -ForegroundColor Cyan
az container create `
    --resource-group $ResourceGroup `
    --name $ContainerName `
    --image "$AcrUrl/$ImageName`:$ImageTag" `
    --cpu 1 `
    --memory 1 `
    --location "centralindia" `
    --os-type Linux `
    --registry-login-server $AcrUrl `
    --registry-username $acrUsername `
    --registry-password $acrPassword `
    --ports 80 `
    --dns-name-label registration-api-prod `
    --environment-variables ASPNETCORE_ENVIRONMENT="Production" ConnectionStrings__DefaultConnection="$connString" `
    --restart-policy OnFailure | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILED: Container creation failed" -ForegroundColor Red
    exit 1
}

Write-Host "OK: Container created successfully" -ForegroundColor Green
Write-Host ""

# Get container info
Write-Host "Container Information:" -ForegroundColor Cyan
$containerInfo = az container show --resource-group $ResourceGroup --name $ContainerName --query "{FQDN: ipAddress.fqdn, IP: ipAddress.ip, State: containers[0].instanceView.currentState.state}" -o json | ConvertFrom-Json
Write-Host "  FQDN: $($containerInfo.FQDN)" -ForegroundColor Green
Write-Host "  IP: $($containerInfo.IP)" -ForegroundColor Green
Write-Host "  State: $($containerInfo.State)" -ForegroundColor Green
Write-Host ""

Write-Host "=================================================" -ForegroundColor Green
Write-Host "  DEPLOYMENT INITIATED!" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green
$endpoint = "http://$($containerInfo.FQDN)/api/Items"
Write-Host "API Endpoint: $endpoint" -ForegroundColor Cyan
Write-Host ""
Write-Host "Container starting (checking status in 45 seconds)..." -ForegroundColor Yellow
Start-Sleep -Seconds 45

Write-Host ""
Write-Host "Container Status:" -ForegroundColor Cyan
$status = az container show --resource-group $ResourceGroup --name $ContainerName --query "containers[0].instanceView.currentState"
Write-Host $status | ConvertFrom-Json | Format-Table -AutoSize

Write-Host ""
Write-Host "To view logs:" -ForegroundColor Cyan
Write-Host "  az container logs --resource-group $ResourceGroup --name $ContainerName" -ForegroundColor White
Write-Host ""
Write-Host "To test API:" -ForegroundColor Cyan
Write-Host "  curl $endpoint" -ForegroundColor White
Write-Host ""
