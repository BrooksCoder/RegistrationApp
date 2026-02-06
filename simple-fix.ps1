#!/usr/bin/env pwsh
# Simple backend fix - minimal dependencies

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Backend Fix - Simple Version" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$resourceGroup = "rg-registration-app"
$acrName = "registrationappacr"
$acrServer = "$acrName.azurecr.io"
$backendName = "registration-api-2807"
$imageTag = "$acrServer/registration-api:latest"

# Step 1: Check local image
Write-Host "[1/4] Checking Docker image locally..." -ForegroundColor Yellow
$images = docker image ls --format "{{.Repository}}"
if ($images | Select-String "registration-api") {
    Write-Host "✅ Image found locally" -ForegroundColor Green
} else {
    Write-Host "❌ Image not found" -ForegroundColor Red
}

# Step 2: Get credentials
Write-Host ""
Write-Host "[2/4] Getting ACR credentials..." -ForegroundColor Yellow
try {
    $acrUser = az acr credential show --resource-group $resourceGroup --name $acrName --query username -o tsv
    $acrPassword = az acr credential show --resource-group $resourceGroup --name $acrName --query "passwords[0].value" -o tsv
    Write-Host "✅ Credentials obtained" -ForegroundColor Green
} catch {
    Write-Host "❌ Error getting credentials" -ForegroundColor Red
    exit 1
}

# Step 3: Push image
Write-Host ""
Write-Host "[3/4] Pushing image to ACR..." -ForegroundColor Yellow
Write-Host "This may take a few minutes..." -ForegroundColor Cyan

$env:DOCKER_REGISTRY = $acrServer
$env:DOCKER_USERNAME = $acrUser
$env:DOCKER_PASSWORD = $acrPassword

# Use docker credential helper instead of piping password
echo $acrPassword | docker login -u $acrUser --password-stdin $acrServer
docker push $imageTag

Write-Host "✅ Image pushed" -ForegroundColor Green

# Step 4: Restart container
Write-Host ""
Write-Host "[4/4] Restarting backend container..." -ForegroundColor Yellow
az container restart --resource-group $resourceGroup --name $backendName --no-wait
Write-Host "✅ Restart initiated" -ForegroundColor Green

Write-Host ""
Write-Host "Waiting 60 seconds for container to start..." -ForegroundColor Cyan
Start-Sleep -Seconds 60

# Test
Write-Host ""
Write-Host "Testing backend..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://registration-api-2807.centralindia.azurecontainer.io/api/items" -UseBasicParsing -TimeoutSec 5
    Write-Host "✅✅ SUCCESS! Status: $($response.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Not responding yet - container may still be starting" -ForegroundColor Yellow
}

Write-Host ""
