#!/usr/bin/env pwsh
<#
.SYNOPSIS
Build backend image using Azure Container Registry build service
#>

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Building Backend Image in Azure" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$resourceGroup = "rg-registration-app"
$acrName = "registrationappacr"

Write-Host "Building image using ACR build service..." -ForegroundColor Yellow
Write-Host "Registry: $acrName" -ForegroundColor Cyan
Write-Host ""

try {
    # Build image in ACR (builds in Azure cloud, not locally)
    az acr build `
      --registry $acrName `
      --image registration-api:latest `
      --file backend/Dockerfile `
      c:\Users\Admin\source\repos\RegistrationApp\backend

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "[OK] Image built and pushed to ACR" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next step: Restart the container to use the new image" -ForegroundColor Cyan
    } else {
        Write-Host "[ERROR] Build failed" -ForegroundColor Red
    }
} catch {
    Write-Host "[ERROR] $($_)" -ForegroundColor Red
}

Write-Host ""
