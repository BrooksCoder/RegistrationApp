# Quick deployment script for frontend with correct backend URL (PowerShell)

Write-Host "🚀 Redeploying Frontend with Backend URL Configuration" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

# Configuration - CHANGE THESE VALUES
$resourceGroup = "YourResourceGroup"
$containerName = "registration-frontend-prod"
$imageName = "registrationapp.azurecr.io/registration-frontend:latest"
$registryServer = "registrationapp.azurecr.io"
$registryUsername = "<YOUR_USERNAME>"
$registryPassword = "<YOUR_PASSWORD>"

# Ask for backend URL
Write-Host "What is your backend API URL?" -ForegroundColor Yellow
Write-Host "Example: https://registration-api-prod.centralindia.azurecontainer.io" -ForegroundColor Gray
$backendUrl = Read-Host "Backend URL"

if ([string]::IsNullOrWhiteSpace($backendUrl)) {
    Write-Host "❌ Backend URL is required" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Resource Group: $resourceGroup"
Write-Host "  Container Name: $containerName"
Write-Host "  Backend URL: $backendUrl"
Write-Host "  Image: $imageName"
Write-Host ""

# Stop existing container
Write-Host "⏳ Stopping existing container..." -ForegroundColor Yellow
az container delete `
  --resource-group $resourceGroup `
  --name $containerName `
  --yes 2>$null

Write-Host "✓ Creating new container with backend URL..." -ForegroundColor Green
Write-Host ""

# Create container with backend URL
az container create `
  --resource-group $resourceGroup `
  --name $containerName `
  --image $imageName `
  --cpu 1 `
  --memory 1 `
  --ports 80 `
  --environment-variables BACKEND_URL=$backendUrl `
  --registry-login-server $registryServer `
  --registry-username $registryUsername `
  --registry-password $registryPassword `
  --restart-policy Always

Write-Host ""
Write-Host "✅ Container deployed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Frontend URL: http://registration-frontend-prod.centralindia.azurecontainer.io/" -ForegroundColor Cyan
Write-Host "Backend URL: $backendUrl" -ForegroundColor Cyan
Write-Host ""
Write-Host "⏱️  Waiting for container to start (30 seconds)..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

Write-Host ""
Write-Host "✓ Deployment complete!" -ForegroundColor Green
Write-Host "✓ Frontend is now pointing to: $backendUrl" -ForegroundColor Green
Write-Host ""
Write-Host "Test the application:" -ForegroundColor Yellow
Write-Host "  1. Open: http://registration-frontend-prod.centralindia.azurecontainer.io/" -ForegroundColor Gray
Write-Host "  2. Check browser console (F12)" -ForegroundColor Gray
Write-Host "  3. Items should load from the backend" -ForegroundColor Gray
Write-Host ""
Write-Host "Troubleshooting:" -ForegroundColor Yellow
Write-Host "  - Check backend is running and accessible" -ForegroundColor Gray
Write-Host "  - Verify BACKEND_URL is correct" -ForegroundColor Gray
Write-Host "  - Check browser console for API errors (F12)" -ForegroundColor Gray
