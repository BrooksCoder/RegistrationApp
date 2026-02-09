#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Simple one-click deployment script for Registration App
.DESCRIPTION
    Builds, pushes, and deploys the application to Azure Container Instances
.PREREQUISITE
    - Docker Desktop must be running
    - Azure CLI must be installed and logged in
.USAGE
    .\SIMPLE-DEPLOY.ps1
#>

$ErrorActionPreference = "Stop"
$WarningPreference = "SilentlyContinue"

# Configuration
$ResourceGroup = "rg-registration-app"
$ContainerName = "registration-api-prod"
$AcrName = "registrationappacr"
$AcrUrl = "$AcrName.azurecr.io"
$ImageName = "registration-api"
$ImageTag = "latest"
$BackendPath = ".\backend"

function Write-Title {
    param([string]$Title)
    Write-Host ""
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Step, [int]$Number, [int]$Total)
    Write-Host "[$Number/$Total] $Step" -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
    exit 1
}

Write-Title "REGISTRATION APP - SIMPLE DEPLOYMENT"

# 1. Check Prerequisites
Write-Step "Checking prerequisites" 1 5

# Check Docker
$dockerCheck = docker ps 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error-Custom "Docker is not running. Please start Docker Desktop and try again."
}
Write-Success "Docker is running"

# Check Azure CLI
$azCheck = az account show --query name -o tsv
if (-not $azCheck) {
    Write-Error-Custom "Not logged into Azure. Run 'az login' first."
}
Write-Success "Logged into Azure as: $azCheck"

if (-not (Test-Path $BackendPath)) {
    Write-Error-Custom "Backend directory not found at $BackendPath"
}
Write-Success "Backend directory found"
Write-Host ""

# 2. Build Docker Image
Write-Step "Building Docker image" 2 5
Write-Host "This may take 2-3 minutes..." -ForegroundColor Cyan

$buildStart = Get-Date
docker build -t "$AcrUrl/$ImageName`:$ImageTag" -f "$BackendPath/Dockerfile" "$BackendPath" | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Error-Custom "Docker build failed"
}
$buildTime = [math]::Round(((Get-Date) - $buildStart).TotalSeconds)
Write-Success "Docker image built in ${buildTime}s"
Write-Host ""

# 3. Push to ACR
Write-Step "Pushing image to Azure Container Registry" 3 5

$acrPassword = az acr credential show --resource-group $ResourceGroup --name $AcrName --query "passwords[0].value" -o tsv
if (-not $acrPassword) {
    Write-Error-Custom "Could not retrieve ACR credentials"
}

docker login "$AcrUrl" -u "$AcrName" -p "$acrPassword" --silent 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error-Custom "Failed to login to ACR"
}

Write-Host "Uploading to $AcrUrl..." -ForegroundColor Cyan
docker push "$AcrUrl/$ImageName`:$ImageTag" | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error-Custom "Failed to push image to ACR"
}
Write-Success "Image pushed to ACR"
Write-Host ""

# 4. Delete Old Container
Write-Step "Preparing deployment (cleaning old container)" 4 5

try {
    $existing = az container show --resource-group $ResourceGroup --name $ContainerName --query "id" -o tsv 2>&1
}
catch {
    $existing = $null
}

if ($existing) {
    Write-Host "Deleting old container..." -ForegroundColor Cyan
    az container delete --resource-group $ResourceGroup --name $ContainerName --yes | Out-Null
    Write-Host "Waiting for cleanup..." -ForegroundColor Cyan
    Start-Sleep -Seconds 10
    Write-Success "Old container deleted"
}
else {
    Write-Success "No old container to delete"
}
Write-Host ""

# 5. Deploy Container
Write-Step "Deploying new container" 5 5

$connString = "Server=tcp:regsql2807.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourSecurePassword123!@#;Encrypt=True;Connection Timeout=30;"

$acrUsername = az acr credential show --resource-group $ResourceGroup --name $AcrName --query "username" -o tsv

Write-Host "Creating container instance..." -ForegroundColor Cyan
az container create `
    --resource-group $ResourceGroup `
    --name $ContainerName `
    --image "$AcrUrl/$ImageName`:$ImageTag" `
    --cpu 1 --memory 1 `
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
    Write-Error-Custom "Container creation failed"
}
Write-Success "Container deployed"
Write-Host ""

# Show Results
Write-Title "DEPLOYMENT COMPLETE!"

$containerInfo = az container show --resource-group $ResourceGroup --name $ContainerName --query "{FQDN: ipAddress.fqdn, IP: ipAddress.ip}" -o json | ConvertFrom-Json

Write-Host ""
Write-Host "Container Information:" -ForegroundColor Cyan
Write-Host "  FQDN: $($containerInfo.FQDN)" -ForegroundColor Green
Write-Host "  IP:   $($containerInfo.IP)" -ForegroundColor Green
Write-Host ""
Write-Host "API Endpoint:" -ForegroundColor Cyan
Write-Host "  http://$($containerInfo.FQDN)/api/items" -ForegroundColor Green
Write-Host ""
Write-Host "The container is starting (this usually takes 1-2 minutes)..." -ForegroundColor Yellow
Write-Host ""
Write-Host "Quick Commands:" -ForegroundColor Cyan
Write-Host "  View logs:"
Write-Host "    az container logs --resource-group $ResourceGroup --name $ContainerName" -ForegroundColor White
Write-Host ""
Write-Host "  Test API:"
Write-Host "    curl http://$($containerInfo.FQDN)/api/items" -ForegroundColor White
Write-Host ""
Write-Host "  Check status:"
Write-Host "    az container show --resource-group $ResourceGroup --name $ContainerName --query 'containers[0].instanceView.currentState'" -ForegroundColor White
Write-Host ""

# Wait and check status
Write-Host "Waiting 60 seconds for container startup..." -ForegroundColor Yellow
Start-Sleep -Seconds 60

$status = az container show --resource-group $ResourceGroup --name $ContainerName --query "containers[0].instanceView.currentState.state" -o tsv

Write-Host ""
Write-Host "Container Status: $status" -ForegroundColor Cyan
Write-Host ""

if ($status -eq "Running") {
    Write-Success "Container is running! API should be available shortly."
}
else {
    Write-Host "Container is $status. Check logs for details:" -ForegroundColor Yellow
    Write-Host "  az container logs --resource-group $ResourceGroup --name $ContainerName" -ForegroundColor White
}

Write-Host ""
