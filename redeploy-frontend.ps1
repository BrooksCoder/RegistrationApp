# Redeploy Frontend with Fixed Configuration
# This rebuilds and redeploys the frontend container with corrected entrypoint script

param(
    [string]$ResourceGroup = "rg-registration-app",
    [string]$ACRName = "registrationappacr",
    [string]$ImageName = "registration-frontend",
    [string]$Location = "centralindia",
    [string]$ContainerName = "registration-frontend-prod"
)

Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "🚀 Rebuilding and Redeploying Frontend Container" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Get ACR credentials
Write-Host "Step 1: Getting ACR credentials..." -ForegroundColor Yellow
$acrUser = az acr credential show --resource-group $ResourceGroup --name $ACRName --query username -o tsv
$acrPass = az acr credential show --resource-group $ResourceGroup --name $ACRName --query "passwords[0].value" -o tsv
$acrServer = "$ACRName.azurecr.io"

Write-Host "  ✓ ACR credentials retrieved" -ForegroundColor Green
Write-Host ""

# Get backend URL
Write-Host "Step 2: Getting backend container URL..." -ForegroundColor Yellow
$backendUrl = az container show --resource-group $ResourceGroup --name "registration-api-prod" --query ipAddress.fqdn -o tsv 2>/dev/null
if ($backendUrl) {
    Write-Host "  Backend URL: $backendUrl" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  Could not retrieve backend URL - using default" -ForegroundColor Yellow
    $backendUrl = "http://registration-api-prod.centralindia.azurecontainer.io"
}
Write-Host ""

# Build the frontend image
Write-Host "Step 3: Building frontend Docker image..." -ForegroundColor Yellow
docker build -f frontend/Dockerfile -t "$acrServer/$ImageName`:latest" ./frontend
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Docker build failed" -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ Image built successfully" -ForegroundColor Green
Write-Host ""

# Login to ACR
Write-Host "Step 4: Logging into Azure Container Registry..." -ForegroundColor Yellow
docker login -u $acrUser -p $acrPass $acrServer
Write-Host "  ✓ Logged into ACR" -ForegroundColor Green
Write-Host ""

# Push the image
Write-Host "Step 5: Pushing image to ACR..." -ForegroundColor Yellow
docker push "$acrServer/$ImageName`:latest"
Write-Host "  ✓ Image pushed to ACR" -ForegroundColor Green
Write-Host ""

# Delete old container
Write-Host "Step 6: Deleting old frontend container..." -ForegroundColor Yellow
az container delete --resource-group $ResourceGroup --name $ContainerName --yes 2>$null
Start-Sleep -Seconds 3
Write-Host "  ✓ Old container deleted" -ForegroundColor Green
Write-Host ""

# Deploy new container
Write-Host "Step 7: Creating new frontend container..." -ForegroundColor Yellow
az container create `
    --resource-group $ResourceGroup `
    --name $ContainerName `
    --image "$acrServer/$ImageName`:latest" `
    --cpu 0.5 `
    --memory 1 `
    --os-type Linux `
    --registry-login-server $acrServer `
    --registry-username $acrUser `
    --registry-password $acrPass `
    --ports 80 `
    --dns-name-label "registration-frontend-prod" `
    --location $Location `
    --restart-policy OnFailure `
    --environment-variables `
        'NODE_ENV=production' `
        "BACKEND_URL=$backendUrl" `
        "BACKEND_API_URL=$backendUrl"

Write-Host "  ✓ Container created" -ForegroundColor Green
Write-Host ""

# Wait for container to start
Write-Host "Step 8: Waiting for container to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Get the container URL
$frontendUrl = az container show --resource-group $ResourceGroup --name $ContainerName --query ipAddress.fqdn -o tsv
$state = az container show --resource-group $ResourceGroup --name $ContainerName --query instanceView.state -o tsv

Write-Host ""
Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "✅ Deployment Complete!" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Container Status: $state" -ForegroundColor White
Write-Host "Frontend URL: http://$frontendUrl" -ForegroundColor Green
Write-Host "Backend URL: http://$backendUrl" -ForegroundColor Green
Write-Host ""

# Wait a bit more for container to fully start
Write-Host "Waiting for container to fully initialize (30 seconds)..." -ForegroundColor Yellow
$sw = [System.Diagnostics.Stopwatch]::StartNew()
do {
    $state = az container show --resource-group $ResourceGroup --name $ContainerName --query instanceView.state -o tsv 2>/dev/null
    $restarts = az container show --resource-group $ResourceGroup --name $ContainerName --query instanceView.restartCount -o tsv 2>/dev/null
    
    if ($state -eq "Running") {
        Write-Host "✅ Container is Running! (Restarts: $restarts)" -ForegroundColor Green
        break
    } else {
        Write-Host "  State: $state (Restarts: $restarts)" -ForegroundColor Yellow
    }
    
    Start-Sleep -Seconds 2
} while ($sw.Elapsed.TotalSeconds -lt 30)

Write-Host ""
Write-Host "Testing frontend accessibility..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://$frontendUrl" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    Write-Host "✅ Frontend is accessible!" -ForegroundColor Green
    Write-Host "  Status Code: $($response.StatusCode)" -ForegroundColor White
}
catch {
    Write-Host "⚠️  Frontend not fully ready yet (might still be initializing)" -ForegroundColor Yellow
    Write-Host "  Try accessing http://$frontendUrl in a few moments" -ForegroundColor White
}

Write-Host ""
Write-Host "🎯 Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Access the frontend: http://$frontendUrl" -ForegroundColor White
Write-Host "  2. Check if data loads from the backend" -ForegroundColor White
Write-Host "  3. If issues persist, run: .\diagnose-connectivity.ps1" -ForegroundColor White
