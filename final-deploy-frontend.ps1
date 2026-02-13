Write-Host "Building frontend image..." -ForegroundColor Cyan

# Build
docker build -f frontend/Dockerfile -t registrationappacr.azurecr.io/registration-frontend:latest ./frontend

# Login and push
az acr login --name registrationappacr
docker push registrationappacr.azurecr.io/registration-frontend:latest

Write-Host ""
Write-Host "Deploying frontend..." -ForegroundColor Yellow

# Get backend URL
$backendUrl = az container show --resource-group rg-registration-app --name registration-api-prod --query ipAddress.fqdn -o tsv
Write-Host "Backend URL: $backendUrl" -ForegroundColor White

# Get ACR creds
$acrUser = az acr credential show --resource-group rg-registration-app --name registrationappacr --query username -o tsv
$acrPassword = az acr credential show --resource-group rg-registration-app --name registrationappacr --query "passwords[0].value" -o tsv

# Delete old
az container delete --resource-group rg-registration-app --name registration-frontend-prod --yes 2>/dev/null | Out-Null
Start-Sleep -Seconds 3

# Deploy
az container create `
    --resource-group rg-registration-app `
    --name registration-frontend-prod `
    --image registrationappacr.azurecr.io/registration-frontend:latest `
    --registry-login-server registrationappacr.azurecr.io `
    --registry-username "$acrUser" `
    --registry-password "$acrPassword" `
    --os-type Linux `
    --ports 80 `
    --dns-name-label registration-frontend-prod `
    --location eastus `
    --cpu 0.5 `
    --memory 1 `
    --restart-policy OnFailure `
    --environment-variables `
        "BACKEND_URL=http://$backendUrl" `
        'NODE_ENV=production'

Write-Host "Deployment initiated..." -ForegroundColor Green
Start-Sleep -Seconds 15

# Get frontend URL
$frontendUrl = az container show --resource-group rg-registration-app --name registration-frontend-prod --query ipAddress.fqdn -o tsv

Write-Host ""
Write-Host "Frontend: http://$frontendUrl" -ForegroundColor Cyan
Write-Host "Backend:  http://$backendUrl" -ForegroundColor Cyan
Write-Host ""
Write-Host "Check logs: az container logs --resource-group rg-registration-app --name registration-frontend-prod" -ForegroundColor Yellow
