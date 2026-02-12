# Rebuild Frontend and Deploy

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "🔨 REBUILDING FRONTEND IMAGE" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$resourceGroup = "rg-registration-app"
$registryName = "registrationappacr"
$registryUrl = "registrationappacr.azurecr.io"

# Step 1: Login to Azure
Write-Host "Step 1: Azure Login" -ForegroundColor Yellow
az account show | Out-Null

# Step 2: Login to ACR
Write-Host "Step 2: Login to ACR" -ForegroundColor Yellow
az acr login --name $registryName

# Step 3: Build frontend image
Write-Host "Step 3: Building frontend image..." -ForegroundColor Yellow
docker build -f frontend/Dockerfile -t "$registryUrl/registration-frontend:latest" ./frontend
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build failed!" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Build successful" -ForegroundColor Green
Write-Host ""

# Step 4: Push to ACR
Write-Host "Step 4: Pushing to ACR..." -ForegroundColor Yellow
docker push "$registryUrl/registration-frontend:latest"
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Push failed!" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Push successful" -ForegroundColor Green
Write-Host ""

# Step 5: Get backend URL
Write-Host "Step 5: Getting backend container URL..." -ForegroundColor Yellow
$backendUrl = az container show `
    --resource-group $resourceGroup `
    --name registration-api-prod `
    --query ipAddress.fqdn -o tsv

Write-Host "✅ Backend URL: $backendUrl" -ForegroundColor Green
Write-Host ""

# Step 6: Get ACR credentials
Write-Host "Step 6: Getting ACR credentials..." -ForegroundColor Yellow
$acrUser = az acr credential show `
    --resource-group $resourceGroup `
    --name $registryName `
    --query username -o tsv

$acrPassword = az acr credential show `
    --resource-group $resourceGroup `
    --name $registryName `
    --query "passwords[0].value" -o tsv

Write-Host "✅ ACR credentials obtained" -ForegroundColor Green
Write-Host ""

# Step 7: Delete old containers
Write-Host "Step 7: Cleaning up old containers..." -ForegroundColor Yellow
az container delete --resource-group $resourceGroup --name registration-frontend-prod --yes 2>/dev/null | Out-Null
az container delete --resource-group $resourceGroup --name registration-frontend-prod-v2 --yes 2>/dev/null | Out-Null
az container delete --resource-group $resourceGroup --name registration-frontend-prod-v3 --yes 2>/dev/null | Out-Null
Start-Sleep -Seconds 3
Write-Host "✅ Old containers cleaned up" -ForegroundColor Green
Write-Host ""

# Step 8: Deploy new frontend
Write-Host "Step 8: Deploying new frontend container..." -ForegroundColor Yellow
az container create `
    --resource-group $resourceGroup `
    --name registration-frontend-prod `
    --image "$registryUrl/registration-frontend:latest" `
    --cpu 0.5 `
    --memory 1 `
    --os-type Linux `
    --registry-login-server $registryUrl `
    --registry-username "$acrUser" `
    --registry-password "$acrPassword" `
    --ports 80 `
    --dns-name-label "registration-frontend-prod" `
    --location centralindia `
    --restart-policy OnFailure `
    --environment-variables `
        "BACKEND_URL=http://$backendUrl" `
        "BACKEND_API_URL=http://$backendUrl" `
        'NODE_ENV=production'

Write-Host "✅ Container deployment initiated" -ForegroundColor Green
Write-Host ""

# Step 9: Wait and get frontend URL
Write-Host "Step 9: Waiting for container to initialize..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

$frontendUrl = az container show `
    --resource-group $resourceGroup `
    --name registration-frontend-prod `
    --query ipAddress.fqdn -o tsv

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "✅ DEPLOYMENT COMPLETE" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Frontend URL:  http://$frontendUrl" -ForegroundColor Cyan
Write-Host "Backend URL:   http://$backendUrl" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 Next Steps:" -ForegroundColor Yellow
Write-Host "1. Wait 30-60 seconds for the container to fully start" -ForegroundColor White
Write-Host "2. Open http://$frontendUrl in your browser" -ForegroundColor White
Write-Host "3. Check DevTools > Network tab to verify API calls work" -ForegroundColor White
Write-Host ""
Write-Host "🔍 Verify Backend Connectivity:" -ForegroundColor Yellow
Write-Host "curl http://$backendUrl/api/items" -ForegroundColor White
Write-Host ""
