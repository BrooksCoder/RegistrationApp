#!/usr/bin/env pwsh
# Quick deployment script - Skip docker build, use existing image

$ErrorActionPreference = "Stop"

$ResourceGroup = "rg-registration-app"
$ContainerName = "registration-api-prod"
$AcrName = "registrationappacr"
$AcrUrl = "$AcrName.azurecr.io"
$ImageName = "registration-api"
$ImageTag = "latest"
$FullImageName = "$AcrUrl/$ImageName`:$ImageTag"

Write-Host "`n=================================================" -ForegroundColor Cyan
Write-Host "  QUICK DEPLOYMENT - Redeploying Container" -ForegroundColor Cyan
Write-Host "=================================================`n" -ForegroundColor Cyan

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
$existingContainer = az container show --resource-group $ResourceGroup --name $ContainerName --query "id" -o tsv -ErrorAction SilentlyContinue
if ($existingContainer) {
    Write-Host "  Deleting: $ContainerName" -ForegroundColor Cyan
    az container delete --resource-group $ResourceGroup --name $ContainerName --yes | Out-Null
    Write-Host "  Waiting 10 seconds..." -ForegroundColor Cyan
    Start-Sleep -Seconds 10
    Write-Host "OK: Container deleted" -ForegroundColor Green
}
else {
    Write-Host "OK: No existing container found" -ForegroundColor Green
}
Write-Host ""

# Step 3: Get ACR Credentials
Write-Host "[3/3] Deploying new container instance..." -ForegroundColor Yellow
$acrUsername = az acr credential show --resource-group $ResourceGroup --name $AcrName --query "username" -o tsv
$acrPassword = az acr credential show --resource-group $ResourceGroup --name $AcrName --query "passwords[0].value" -o tsv

if (-not $acrUsername -or -not $acrPassword) {
    Write-Host "FAILED: Could not retrieve ACR credentials" -ForegroundColor Red
    exit 1
}

# Get connection string from Key Vault
Write-Host "  Retrieving database connection string..." -ForegroundColor Cyan
$connString = az keyvault secret show --vault-name "kv-registrationapp" --name "ConnectionString" --query "value" -o tsv

if (-not $connString) {
    Write-Host "FAILED: Could not retrieve connection string from Key Vault" -ForegroundColor Red
    exit 1
}

# Create/Update Container Instance
Write-Host "  Creating container instance: $ContainerName" -ForegroundColor Cyan
az container create `
    --resource-group $ResourceGroup `
    --name $ContainerName `
    --image $FullImageName `
    --cpu 1 `
    --memory 1 `
    --registry-login-server $AcrUrl `
    --registry-username $acrUsername `
    --registry-password $acrPassword `
    --ports 80 `
    --dns-name-label registration-api-prod `
    --environment-variables `
        ASPNETCORE_ENVIRONMENT=Production `
        ConnectionStrings__DefaultConnection="$connString" `
    --restart-policy OnFailure 2>&1 | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILED: Container creation failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Container deployed successfully`n" -ForegroundColor Green

# Get container info
Write-Host "Container Information:" -ForegroundColor Cyan
$containerInfo = az container show --resource-group $ResourceGroup --name $ContainerName --query "{FQDN: ipAddress.fqdn, IP: ipAddress.ip, State: containers[0].instanceView.currentState.state}" -o json | ConvertFrom-Json
Write-Host "  FQDN: $($containerInfo.FQDN)" -ForegroundColor Green
Write-Host "  IP: $($containerInfo.IP)" -ForegroundColor Green
Write-Host "  State: $($containerInfo.State)" -ForegroundColor Green

Write-Host ""
Write-Host "OK: DEPLOYMENT COMPLETE!" -ForegroundColor Green
Write-Host ("  API Endpoint: http://" + $containerInfo.FQDN + "/api/Items") -ForegroundColor Cyan
Write-Host ""
