$resourceGroup = "rg-registration-app"
$containerName = "registration-frontend-prod"

Write-Host "Checking frontend container configuration..." -ForegroundColor Cyan
Write-Host ""

# Get the nginx config from the running container
Write-Host "Checking nginx config file in container..." -ForegroundColor Yellow

az container exec `
    --resource-group $resourceGroup `
    --name $containerName `
    --exec-command "/bin/cat /etc/nginx/conf.d/default.conf"

Write-Host ""
Write-Host "Checking container logs..." -ForegroundColor Yellow
az container logs --resource-group $resourceGroup --name $containerName
