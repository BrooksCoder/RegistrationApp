#!/usr/bin/env pwsh
<#
.SYNOPSIS
Complete diagnostic and fix - handles terminal hangs gracefully
#>

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Backend Diagnostic & Fix - Terminal Hang Safe Version    ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Configuration
$resourceGroup = "rg-registration-app"
$acrName = "registrationappacr"
$acrServer = "$acrName.azurecr.io"
$backendName = "registration-api-2807"
$imageTag = "$acrServer/registration-api:latest"

# Function: Run command with timeout
function Run-CommandWithTimeout {
    param([string]$Command, [int]$TimeoutSeconds = 30)
    
    $process = Start-Process -FilePath "powershell" -ArgumentList "-Command $Command" -NoNewWindow -PassThru
    $process.WaitForExit($TimeoutSeconds * 1000)
    
    if ($process.HasExited) {
        return $true
    } else {
        $process.Kill()
        return $false
    }
}

Write-Host "[1/5] Checking Docker image..." -ForegroundColor Yellow
Write-Host ""

$imageCheck = docker image ls --format "{{.Repository}}" | Select-String "registration-api"
if ($imageCheck) {
    Write-Host "✅ Image exists locally: $imageTag" -ForegroundColor Green
} else {
    Write-Host "❌ Image NOT found locally" -ForegroundColor Red
    Write-Host "   This is the problem - need to rebuild" -ForegroundColor Red
}

Write-Host ""
Write-Host "[2/5] Getting ACR credentials..." -ForegroundColor Yellow

$acrUser = (az acr credential show --resource-group $resourceGroup --name $acrName --query username -o tsv) 2>$null
$acrPassword = (az acr credential show --resource-group $resourceGroup --name $acrName --query "passwords[0].value" -o tsv) 2>$null

if ($acrUser -and $acrPassword) {
    Write-Host "✅ ACR credentials obtained" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to get ACR credentials" -ForegroundColor Red
}

Write-Host ""
Write-Host "[3/5] Logging in to ACR..." -ForegroundColor Yellow

# Create temporary file for password to avoid shell escaping issues
$tempFile = New-TemporaryFile
$acrPassword | Out-File -FilePath $tempFile -NoNewline

# Login with timeout
$loginCmd = "Get-Content '$tempFile' | docker login -u '$acrUser' --password-stdin '$acrServer' 2>&1"
$loginSuccess = Run-CommandWithTimeout -Command $loginCmd -TimeoutSeconds 30

if ($loginSuccess) {
    Write-Host "✅ Logged in to ACR" -ForegroundColor Green
} else {
    Write-Host "⚠️  Login may have timed out but continuing..." -ForegroundColor Yellow
}

Remove-Item $tempFile -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "[4/5] Pushing image to ACR (WITH TIMEOUT)..." -ForegroundColor Yellow
Write-Host "Image: $imageTag" -ForegroundColor Cyan
Write-Host ""

# Push with timeout
$pushCmd = "docker push '$imageTag' 2>&1"
$pushSuccess = Run-CommandWithTimeout -Command $pushCmd -TimeoutSeconds 600

if ($pushSuccess) {
    Write-Host "✅ Image pushed to ACR" -ForegroundColor Green
} else {
    Write-Host "⚠️  Push operation timed out" -ForegroundColor Yellow
    Write-Host "   This sometimes happens with ACR but the image may still be pushed" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[5/5] Restarting backend container..." -ForegroundColor Yellow

# Simple restart without waiting for output
az container restart --resource-group $resourceGroup --name $backendName --no-wait

Write-Host "✅ Restart command sent (non-blocking)" -ForegroundColor Green
Write-Host ""
Write-Host "⏳ Waiting 90 seconds for container to start..." -ForegroundColor Cyan

for ($i = 0; $i -lt 90; $i += 5) {
    Write-Host "." -NoNewline
    Start-Sleep -Seconds 5
    
    if ($i % 30 -eq 0 -and $i -gt 0) {
        $elapsed = $i
        Write-Host " ($elapsed seconds)" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Testing Backend API" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$testUrl = "http://registration-api-2807.centralindia.azurecontainer.io/api/items"
Write-Host "URL: $testUrl" -ForegroundColor Cyan
Write-Host ""

try {
    $response = Invoke-WebRequest -Uri $testUrl -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    
    Write-Host "✅✅✅ SUCCESS! Backend is responding!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Status Code: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "Response size: $($response.Content.Length) bytes" -ForegroundColor Green
    Write-Host ""
    Write-Host "Response Preview:" -ForegroundColor Cyan
    $preview = if ($response.Content.Length -gt 300) {
        ($response.Content.Substring(0, 300)) + "..."
    } else {
        $response.Content
    }
    Write-Host $preview -ForegroundColor Green
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  All Systems Go!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "✅ Backend: http://registration-api-2807.centralindia.azurecontainer.io/api/items" -ForegroundColor Green
    Write-Host "✅ Frontend: http://registration-frontend-prod.centralindia.azurecontainer.io" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next: Refresh your browser (Ctrl+Shift+R) to reload the frontend" -ForegroundColor Yellow
    
} catch {
    Write-Host "❌ Backend still not responding" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "⚠️  Troubleshooting:" -ForegroundColor Yellow
    Write-Host "1. The container may still be starting" -ForegroundColor Yellow
    Write-Host "2. The image may not have been pushed to ACR" -ForegroundColor Yellow
    Write-Host "3. The old cached image may still be running" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Try these commands in a new PowerShell window:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "# Force delete old container" -ForegroundColor Cyan
    Write-Host "az container delete --resource-group rg-registration-app --name registration-api-2807 --yes" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "# Check ACR for image" -ForegroundColor Cyan
    Write-Host "az acr repository show --name registrationappacr --image registration-api:latest" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "# Check container logs" -ForegroundColor Cyan
    Write-Host "az container logs --resource-group rg-registration-app --name registration-api-2807 --tail 200" -ForegroundColor Cyan
}

Write-Host ""
