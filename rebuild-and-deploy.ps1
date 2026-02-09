#!/usr/bin/env pwsh
# Full rebuild and deployment script

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
Write-Host "  FULL REBUILD AND DEPLOYMENT" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Verify Azure Login
Write-Host "[1/5] Verifying Azure Login..." -ForegroundColor Yellow
$currentAccount = az account show --query "name" -o tsv
if (-not $currentAccount) {
    Write-Host "FAILED: Not logged into Azure. Run 'az login' first." -ForegroundColor Red
    exit 1
}
Write-Host "OK: Logged in as: $currentAccount" -ForegroundColor Green
Write-Host ""

# Step 2: Build Docker Image
Write-Host "[2/5] Building Docker Image..." -ForegroundColor Yellow
Write-Host "  Building: $ImageName`:$ImageTag" -ForegroundColor Cyan

if (-not (Test-Path $BackendPath)) {
    Write-Host "FAILED: Backend directory not found at $BackendPath" -ForegroundColor Red
    exit 1
}

docker build -t "$AcrUrl/$ImageName`:$ImageTag" -f "$BackendPath/Dockerfile" "$BackendPath"

if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILED: Docker build failed" -ForegroundColor Red
    exit 1
}
Write-Host "OK: Docker image built successfully" -ForegroundColor Green
Write-Host ""

# Step 3: Push to ACR
Write-Host "[3/5] Logging into ACR and Pushing Image..." -ForegroundColor Yellow
Write-Host "  ACR: $AcrUrl" -ForegroundColor Cyan

$acrPassword = az acr credential show --resource-group $ResourceGroup --name $AcrName --query "passwords[0].value" -o tsv

if (-not $acrPassword) {
    Write-Host "FAILED: Could not retrieve ACR password" -ForegroundColor Red
    exit 1
}

# Login to ACR
docker login "$AcrUrl" -u "$AcrName" -p "$acrPassword" --silent

if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILED: Docker ACR login failed" -ForegroundColor Red
    exit 1
}

# Push image
Write-Host "  Pushing image to ACR..." -ForegroundColor Cyan
docker push "$AcrUrl/$ImageName`:$ImageTag"

if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILED: Docker push failed" -ForegroundColor Red
    exit 1
}
Write-Host "OK: Image pushed to ACR successfully" -ForegroundColor Green
Write-Host ""

# Step 4: Delete Old Container
Write-Host "[4/5] Cleaning up old container..." -ForegroundColor Yellow
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

# Step 5: Deploy New Container
Write-Host "[5/5] Deploying new container instance..." -ForegroundColor Yellow

$connString = "Server=tcp:regsql2807.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourSecurePassword123!@#;Encrypt=True;Connection Timeout=30;"

$acrUsername = az acr credential show --resource-group $ResourceGroup --name $AcrName --query "username" -o tsv

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
Write-Host "Waiting 60 seconds for container to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 60

Write-Host "Testing API endpoint..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri $endpoint -ErrorAction SilentlyContinue
    Write-Host "SUCCESS! API is responding with status: $($response.StatusCode)" -ForegroundColor Green
}
catch {
    Write-Host "Container still starting, check status with:" -ForegroundColor Cyan
    Write-Host "  az container logs --resource-group $ResourceGroup --name $ContainerName" -ForegroundColor White
    Write-Host "  az container show --resource-group $ResourceGroup --name $ContainerName --query 'containers[0].instanceView.currentState'" -ForegroundColor White
}

Write-Host ""
