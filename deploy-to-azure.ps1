#!/usr/bin/env pwsh
# Quick deployment script - Redeploy Container to Azure

$ErrorActionPreference = "Stop"

$ResourceGroup = "rg-registration-app"
$ContainerName = "registration-api-prod"
$AcrName = "registrationappacr"
$AcrUrl = "$AcrName.azurecr.io"
$ImageName = "registration-api"
$ImageTag = "latest"
$FullImageName = "$AcrUrl/$ImageName`:$ImageTag"

Write-Host ""
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "  QUICK DEPLOYMENT - Redeploying Container" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Verify Azure Login
Write-Host "[1/3] Verifying Azure Login..." -ForegroundColor Yellow
$currentAccount = az account show --query "name" -o tsv
if (-not $currentAccount) {
    Write-Host "FAILED: Not logged into Azure. Run 'az login' first." -ForegroundColor Red
    exit 1
}
Write-Host "OK: Logged in as: $currentAccount" -ForegroundColor Green
Write-Host ""

# Step 2: Delete Old Container
Write-Host "[2/3] Cleaning up old container..." -ForegroundColor Yellow
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

# Step 3: Deploy New Container
Write-Host "[3/3] Deploying new container instance..." -ForegroundColor Yellow
$acrUsername = az acr credential show --resource-group $ResourceGroup --name $AcrName --query "username" -o tsv
$acrPassword = az acr credential show --resource-group $ResourceGroup --name $AcrName --query "passwords[0].value" -o tsv

if (-not $acrUsername -or -not $acrPassword) {
    Write-Host "FAILED: Could not retrieve ACR credentials" -ForegroundColor Red
    exit 1
}

Write-Host "  Retrieving database connection string..." -ForegroundColor Cyan
try {
    $connString = az keyvault secret show --vault-name "kv-registrationapp" --name "ConnectionString" --query "value" -o tsv
}
catch {
    Write-Host "ERROR: Connection string not found in Key Vault, using placeholder" -ForegroundColor Yellow
    $connString = "Server=tcp:regsql2807.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourSecurePassword123!@#;Encrypt=True;Connection Timeout=30;"
}

Write-Host "  Creating container instance..." -ForegroundColor Cyan
az container create `
    --resource-group $ResourceGroup `
    --name $ContainerName `
    --image $FullImageName `
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

Write-Host "Container Information:" -ForegroundColor Cyan
$containerInfo = az container show --resource-group $ResourceGroup --name $ContainerName --query "{FQDN: ipAddress.fqdn, IP: ipAddress.ip, State: containers[0].instanceView.currentState.state}" -o json | ConvertFrom-Json
Write-Host "  FQDN: $($containerInfo.FQDN)" -ForegroundColor Green
Write-Host "  IP: $($containerInfo.IP)" -ForegroundColor Green
Write-Host "  State: $($containerInfo.State)" -ForegroundColor Green
Write-Host ""

Write-Host "=================================================" -ForegroundColor Green
Write-Host "  DEPLOYMENT COMPLETE!" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green
$endpoint = "http://$($containerInfo.FQDN)/api/Items"
Write-Host "API Endpoint: $endpoint" -ForegroundColor Cyan
Write-Host ""
