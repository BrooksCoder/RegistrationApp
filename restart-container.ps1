#!/usr/bin/env pwsh
<#
.SYNOPSIS
Restart backend container after image push
#>

Write-Host ""
Write-Host "Waiting for Docker build to complete..." -ForegroundColor Cyan
Start-Sleep -Seconds 30

Write-Host "Restarting backend container in Azure..." -ForegroundColor Yellow

az container restart --resource-group rg-registration-app --name registration-api-2807

Write-Host "✅ Restart command sent" -ForegroundColor Green
Write-Host "Waiting 90 seconds for container to start..." -ForegroundColor Cyan

Start-Sleep -Seconds 90

Write-Host ""
Write-Host "Testing backend API..." -ForegroundColor Yellow

try {
    $response = Invoke-WebRequest -Uri "http://registration-api-2807.centralindia.azurecontainer.io/api/items" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    
    Write-Host "✅ SUCCESS! Backend is responding!" -ForegroundColor Green
    Write-Host "Status: $($response.StatusCode)" -ForegroundColor Green
    Write-Host ""
    Write-Host "API: http://registration-api-2807.centralindia.azurecontainer.io/api/items" -ForegroundColor Cyan
    Write-Host "Frontend: http://registration-frontend-prod.centralindia.azurecontainer.io" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "The 502 errors should be resolved now!" -ForegroundColor Green
    
} catch {
    Write-Host "⚠️  Backend still not responding" -ForegroundColor Yellow
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Try again in a few minutes, or check logs:" -ForegroundColor Cyan
    Write-Host "az container logs --resource-group rg-registration-app --name registration-api-2807 --tail 100" -ForegroundColor Cyan
}

Write-Host ""
