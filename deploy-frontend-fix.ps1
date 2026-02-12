# Deploy Frontend with Fixed Nginx Configuration
# This script redeploys the frontend container with the corrected configuration

param(
    [string]$ResourceGroup = "rg-registration-app",
    [string]$ContainerName = "registration-frontend-prod-v3",
    [string]$RegistryUrl = "registrationappacr.azurecr.io",
    [string]$RegistryName = "registrationappacr",
    [string]$Location = "centralindia"
)

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "🔧 FRONTEND DEPLOYMENT FIX - Correcting Backend URL Proxy" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Get backend container URL
Write-Host "Getting backend container URL..." -ForegroundColor Yellow
$backendUrl = az container show `
    --resource-group $ResourceGroup `
    --name registration-api-prod `
    --query ipAddress.fqdn -o tsv

if (-not $backendUrl) {
    Write-Host "❌ Backend container not found!" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Backend URL: $backendUrl" -ForegroundColor Green
Write-Host ""

# Get ACR credentials
Write-Host "Getting ACR credentials..." -ForegroundColor Yellow
$acrUser = az acr credential show `
    --resource-group $ResourceGroup `
    --name $RegistryName `
    --query username -o tsv

$acrPassword = az acr credential show `
    --resource-group $ResourceGroup `
    --name $RegistryName `
    --query "passwords[0].value" -o tsv

Write-Host "✅ ACR credentials retrieved" -ForegroundColor Green
Write-Host ""

# Delete old frontend containers
Write-Host "Cleaning up old containers..." -ForegroundColor Yellow
az container delete --resource-group $ResourceGroup --name registration-frontend-prod --yes 2>/dev/null | Out-Null
az container delete --resource-group $ResourceGroup --name registration-frontend-prod-v2 --yes 2>/dev/null | Out-Null
Start-Sleep -Seconds 3
Write-Host "✅ Old containers deleted" -ForegroundColor Green
Write-Host ""

# Deploy frontend container
Write-Host "Deploying frontend container..." -ForegroundColor Yellow
Write-Host "Container Name: $ContainerName" -ForegroundColor White
Write-Host "Backend URL: $backendUrl" -ForegroundColor White
Write-Host ""

az container create `
    --resource-group $ResourceGroup `
    --name $ContainerName `
    --image "$RegistryUrl/registration-frontend:latest" `
    --cpu 0.5 `
    --memory 1 `
    --os-type Linux `
    --registry-login-server $RegistryUrl `
    --registry-username "$acrUser" `
    --registry-password "$acrPassword" `
    --ports 80 `
    --dns-name-label $ContainerName `
    --location $Location `
    --restart-policy OnFailure `
    --environment-variables `
        "BACKEND_URL=http://$backendUrl" `
        'NODE_ENV=production'

Write-Host ""
Write-Host "Container deployment initiated..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Get frontend URL
$frontendUrl = az container show `
    --resource-group $ResourceGroup `
    --name $ContainerName `
    --query ipAddress.fqdn -o tsv

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "✅ DEPLOYMENT COMPLETE" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Frontend URL:  http://$frontendUrl" -ForegroundColor Cyan
Write-Host "Backend URL:   http://$backendUrl" -ForegroundColor Cyan
Write-Host "API Base:      http://$backendUrl/api" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Wait 30-60 seconds for the container to fully start" -ForegroundColor White
Write-Host "2. Open http://$frontendUrl in your browser" -ForegroundColor White
Write-Host "3. Check the browser console for any errors" -ForegroundColor White
Write-Host "4. Test API calls to verify data loading" -ForegroundColor White
Write-Host ""
