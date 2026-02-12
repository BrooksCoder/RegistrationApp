Write-Host "Rebuilding and deploying frontend..." -ForegroundColor Cyan
Write-Host ""

$resourceGroup = "rg-registration-app"
$registryName = "registrationappacr"
$registryUrl = "registrationappacr.azurecr.io"

# Build
docker build -f frontend/Dockerfile -t "$registryUrl/registration-frontend:latest" ./frontend

# Push to ACR
az acr login --name $registryName
docker push "$registryUrl/registration-frontend:latest"

# Get backend URL
$backendUrl = az container show --resource-group $resourceGroup --name registration-api-prod --query ipAddress.fqdn -o tsv

# Get ACR credentials
$acrUser = az acr credential show --resource-group $resourceGroup --name $registryName --query username -o tsv
$acrPassword = az acr credential show --resource-group $resourceGroup --name $registryName --query "passwords[0].value" -o tsv

# Clean up old containers
az container delete --resource-group $resourceGroup --name registration-frontend-prod --yes 2>/dev/null | Out-Null
Start-Sleep -Seconds 3

# Deploy
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

Write-Host "Frontend deployment initiated" -ForegroundColor Green
Write-Host ""
Start-Sleep -Seconds 15

$frontendUrl = az container show --resource-group $resourceGroup --name registration-frontend-prod --query ipAddress.fqdn -o tsv

Write-Host "Frontend URL: http://$frontendUrl" -ForegroundColor Cyan
Write-Host "Backend URL:  http://$backendUrl" -ForegroundColor Cyan
