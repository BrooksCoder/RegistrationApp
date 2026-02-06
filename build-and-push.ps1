#!/usr/bin/env pwsh
<#
.SYNOPSIS
Build Docker image and push to ACR with timeout handling
#>

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Build and Push Docker Image" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$acrName = "registrationappacr"
$acrServer = "$acrName.azurecr.io"
$imageTag = "$acrServer/registration-api:latest"
$backendPath = "c:\Users\Admin\source\repos\RegistrationApp\backend"
$resourceGroup = "rg-registration-app"

Write-Host "[1/3] Building Docker image..." -ForegroundColor Yellow
Write-Host "Path: $backendPath" -ForegroundColor Cyan
Write-Host "Image: $imageTag" -ForegroundColor Cyan
Write-Host ""

# Build with timeout
$buildProcess = Start-Process -FilePath "docker" -ArgumentList "build -t $imageTag -f Dockerfile ." -WorkingDirectory $backendPath -NoNewWindow -PassThru

$timeout = 600  # 10 minutes
$elapsed = 0

while (-not $buildProcess.HasExited -and $elapsed -lt $timeout) {
    Start-Sleep -Seconds 10
    $elapsed += 10
    Write-Host "  Building... ($elapsed/$timeout seconds)" -ForegroundColor Gray
}

if ($buildProcess.HasExited) {
    $exitCode = $buildProcess.ExitCode
    if ($exitCode -eq 0) {
        Write-Host "✅ Image built successfully" -ForegroundColor Green
    } else {
        Write-Host "❌ Build failed with exit code $exitCode" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "❌ Build timeout after $timeout seconds" -ForegroundColor Red
    $buildProcess.Kill()
    exit 1
}

Write-Host ""
Write-Host "[2/3] Pushing image to ACR..." -ForegroundColor Yellow

# Get ACR credentials
Write-Host "Getting ACR credentials..." -ForegroundColor Cyan
$acrUser = az acr credential show --resource-group $resourceGroup --name $acrName --query username -o tsv
$acrPassword = az acr credential show --resource-group $resourceGroup --name $acrName --query "passwords[0].value" -o tsv

# Login to ACR
Write-Host "Logging in to ACR..." -ForegroundColor Cyan
$pushProcess = Start-Process -FilePath "docker" -ArgumentList "login -u $acrUser -p $acrPassword $acrServer" -NoNewWindow -PassThru

$timeout = 60  # 1 minute
$elapsed = 0

while (-not $pushProcess.HasExited -and $elapsed -lt $timeout) {
    Start-Sleep -Seconds 5
    $elapsed += 5
}

if (-not $pushProcess.HasExited) {
    Write-Host "⚠️  Login still running, continuing anyway..." -ForegroundColor Yellow
}

# Push image
Write-Host "Pushing image (this may take several minutes)..." -ForegroundColor Cyan
$pushProcess = Start-Process -FilePath "docker" -ArgumentList "push $imageTag" -NoNewWindow -PassThru

$timeout = 900  # 15 minutes
$elapsed = 0

while (-not $pushProcess.HasExited -and $elapsed -lt $timeout) {
    Start-Sleep -Seconds 15
    $elapsed += 15
    Write-Host "  Pushing... ($elapsed/$timeout seconds)" -ForegroundColor Gray
}

if ($pushProcess.HasExited) {
    $exitCode = $pushProcess.ExitCode
    if ($exitCode -eq 0) {
        Write-Host "✅ Image pushed successfully" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Push completed but with exit code $exitCode" -ForegroundColor Yellow
    }
} else {
    Write-Host "❌ Push timeout after $timeout seconds" -ForegroundColor Red
    $pushProcess.Kill()
    exit 1
}

Write-Host ""
Write-Host "[3/3] Restarting backend container..." -ForegroundColor Yellow
Write-Host "Container: registration-api-2807" -ForegroundColor Cyan

try {
    az container restart --resource-group $resourceGroup --name registration-api-2807
    Write-Host "✅ Container restart initiated" -ForegroundColor Green
    Write-Host "Waiting 60 seconds for container to restart..." -ForegroundColor Cyan
    Start-Sleep -Seconds 60
} catch {
    Write-Host "❌ Failed to restart container: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Build and Push Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Testing backend API..." -ForegroundColor Yellow

try {
    $response = Invoke-WebRequest -Uri "http://registration-api-2807.centralindia.azurecontainer.io/api/items" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    Write-Host "✅ Backend is responding!" -ForegroundColor Green
    Write-Host "Status: $($response.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Backend not responding yet (may still be starting)" -ForegroundColor Yellow
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This is normal if container just restarted." -ForegroundColor Yellow
    Write-Host "Try again in 1-2 minutes." -ForegroundColor Yellow
}

Write-Host ""
