#!/usr/bin/env pwsh
<#
.SYNOPSIS
Quick fix script for RegistrationApp 502 Bad Gateway error

.DESCRIPTION
This script diagnostics and fixes common issues with the RegistrationApp deployment

.PARAMETER Action
The action to perform: 'diagnose', 'fix-firewall', 'restart-backend', 'restart-all', or 'test'
#>

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('diagnose', 'fix-firewall', 'restart-backend', 'restart-all', 'test', 'redeploy-backend')]
    [string]$Action = 'diagnose'
)

$ErrorActionPreference = 'Continue'
$WarningPreference = 'SilentlyContinue'

function Write-Status {
    param([string]$Message, [ValidateSet('Info', 'Success', 'Error', 'Warning')]$Status = 'Info')
    
    switch ($Status) {
        'Info'    { Write-Host "ℹ️  $Message" -ForegroundColor Cyan }
        'Success' { Write-Host "✅ $Message" -ForegroundColor Green }
        'Error'   { Write-Host "❌ $Message" -ForegroundColor Red }
        'Warning' { Write-Host "⚠️  $Message" -ForegroundColor Yellow }
    }
}

function Invoke-Diagnose {
    Write-Host "`n========== DIAGNOSTICS ==========" -ForegroundColor Cyan
    
    # Backend status
    Write-Status "Checking backend container..." Info
    $backend = az container show --resource-group rg-registration-app --name registration-api-2807 --query "{State:instanceView.state, Location:location, RestartCount:instanceView.restartCount}" -o json 2>$null | ConvertFrom-Json
    
    if ($backend) {
        Write-Status "Backend State: $($backend.State)" $(if ($backend.State -eq 'Running') { 'Success' } else { 'Warning' })
        Write-Status "Backend Location: $($backend.Location)" Info
        Write-Status "Backend Restart Count: $($backend.RestartCount)" $(if ($backend.RestartCount -lt 3) { 'Info' } else { 'Warning' })
    } else {
        Write-Status "Backend container not found" Error
    }
    
    # Frontend status
    Write-Status "`nChecking frontend container..." Info
    $frontend = az container show --resource-group rg-registration-app --name registration-frontend-prod --query "{State:instanceView.state, Location:location}" -o json 2>$null | ConvertFrom-Json
    
    if ($frontend) {
        Write-Status "Frontend State: $($frontend.State)" $(if ($frontend.State -eq 'Running') { 'Success' } else { 'Warning' })
        Write-Status "Frontend Location: $($frontend.Location)" Info
    } else {
        Write-Status "Frontend container not found" Error
    }
    
    # Backend logs
    if ($backend -and $backend.State -ne 'Running') {
        Write-Status "`nBackend logs (last 20 lines):" Warning
        az container logs --resource-group rg-registration-app --name registration-api-2807 --tail 20 2>$null
    }
    
    # API Test
    Write-Status "`nTesting backend API..." Info
    try {
        $response = Invoke-WebRequest -Uri "http://registration-api-2807.centralindia.azurecontainer.io/api/items" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        Write-Status "Backend API Status: $($response.StatusCode)" Success
    } catch {
        Write-Status "Backend API unreachable: $($_.Exception.Message)" Error
    }
}

function Invoke-FixFirewall {
    Write-Host "`n========== FIXING SQL FIREWALL ==========" -ForegroundColor Cyan
    
    Write-Status "Deleting old firewall rule..." Warning
    az sql server firewall-rule delete --resource-group rg-registration-app --server regsql2807 --name AllowAzureServices --yes 2>$null
    
    Write-Status "Waiting 15 seconds..." Info
    Start-Sleep -Seconds 15
    
    Write-Status "Creating new firewall rule..." Warning
    az sql server firewall-rule create `
        --resource-group rg-registration-app `
        --server regsql2807 `
        --name "AllowAzureServices" `
        --start-ip-address "0.0.0.0" `
        --end-ip-address "0.0.0.0" 2>$null
    
    Write-Status "Firewall rule created" Success
    Write-Status "Waiting 30 seconds for rule to take effect..." Info
    Start-Sleep -Seconds 30
}

function Invoke-RestartBackend {
    Write-Host "`n========== RESTARTING BACKEND ==========" -ForegroundColor Cyan
    
    Write-Status "Restarting backend container..." Warning
    az container restart --resource-group rg-registration-app --name registration-api-2807
    Write-Status "Backend restart command sent" Success
    
    Write-Status "Waiting 20 seconds for container to start..." Info
    Start-Sleep -Seconds 20
    
    Write-Status "Checking new state..." Info
    $state = az container show --resource-group rg-registration-app --name registration-api-2807 --query "instanceView.state" -o tsv
    Write-Status "New state: $state" $(if ($state -eq 'Running') { 'Success' } else { 'Warning' })
}

function Invoke-RestartAll {
    Write-Host "`n========== RESTARTING ALL CONTAINERS ==========" -ForegroundColor Cyan
    
    Write-Status "Restarting backend..." Warning
    az container restart --resource-group rg-registration-app --name registration-api-2807
    Start-Sleep -Seconds 15
    
    Write-Status "Restarting frontend..." Warning
    az container restart --resource-group rg-registration-app --name registration-frontend-prod
    
    Write-Status "All containers restarted" Success
    Write-Status "Waiting 30 seconds..." Info
    Start-Sleep -Seconds 30
}

function Invoke-Test {
    Write-Host "`n========== API TESTS ==========" -ForegroundColor Cyan
    
    # Test backend
    Write-Status "Testing backend API..." Info
    try {
        $backendResponse = Invoke-WebRequest -Uri "http://registration-api-2807.centralindia.azurecontainer.io/api/items" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        Write-Status "Backend API: HTTP $($backendResponse.StatusCode) ✓" Success
        Write-Host "Response: $($backendResponse.Content.Substring(0, [Math]::Min(100, $backendResponse.Content.Length)))" -ForegroundColor Green
    } catch {
        Write-Status "Backend API: FAILED" Error
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Test frontend
    Write-Status "`nTesting frontend..." Info
    try {
        $frontendResponse = Invoke-WebRequest -Uri "http://registration-frontend-prod.centralindia.azurecontainer.io" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        Write-Status "Frontend: HTTP $($frontendResponse.StatusCode) ✓" Success
    } catch {
        Write-Status "Frontend: FAILED" Error
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Invoke-RedeployBackend {
    Write-Host "`n========== REDEPLOYING BACKEND ==========" -ForegroundColor Cyan
    
    Write-Status "Getting ACR credentials..." Info
    $acrCreds = az acr credential show --resource-group rg-registration-app --name registrationappacr -o json | ConvertFrom-Json
    $username = $acrCreds.username
    $password = $acrCreds.passwords[0].value
    
    Write-Status "Deleting old backend container..." Warning
    az container delete --resource-group rg-registration-app --name registration-api-2807 --yes 2>$null
    
    Write-Status "Waiting 10 seconds..." Info
    Start-Sleep -Seconds 10
    
    Write-Status "Creating new backend container in Central India..." Warning
    az container create `
        --resource-group rg-registration-app `
        --name registration-api-2807 `
        --image registrationappacr.azurecr.io/registration-api:latest `
        --location centralindia `
        --os-type Linux `
        --registry-login-server registrationappacr.azurecr.io `
        --registry-username $username `
        --registry-password $password `
        --cpu 1 `
        --memory 1.5 `
        --ports 80 `
        --restart-policy OnFailure `
        --dns-name-label registration-api-2807 `
        --environment-variables `
            ASPNETCORE_ENVIRONMENT="Production" `
            ASPNETCORE_URLS="http://+:80" `
            ConnectionStrings__DefaultConnection="Server=tcp:regsql2807.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourSecurePassword123!@#;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
    
    Write-Status "Backend container created" Success
    Write-Status "Waiting 30 seconds for startup..." Info
    Start-Sleep -Seconds 30
    
    Write-Status "Checking status..." Info
    $state = az container show --resource-group rg-registration-app --name registration-api-2807 --query "instanceView.state" -o tsv
    Write-Status "Backend state: $state" $(if ($state -eq 'Running') { 'Success' } else { 'Warning' })
}

# Main
Write-Host "`n╔════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  RegistrationApp Quick Fix Script      ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Cyan

switch ($Action) {
    'diagnose'           { Invoke-Diagnose }
    'fix-firewall'       { Invoke-FixFirewall; Invoke-Diagnose }
    'restart-backend'    { Invoke-RestartBackend; Invoke-Test }
    'restart-all'        { Invoke-RestartAll; Invoke-Test }
    'test'               { Invoke-Test }
    'redeploy-backend'   { Invoke-RedeployBackend; Invoke-Diagnose }
}

Write-Host "`n════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Done!" -ForegroundColor Green
