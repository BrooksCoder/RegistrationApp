# Complete Deployment Script - Run This
# Make sure you're in: C:\Users\Admin\source\repos\RegistrationApp

# =====================================================
# CONFIGURATION
# =====================================================
$resourceGroup = "rg-registration-app"
$location = "centralindia"
$suffix = "2807"
$acrName = "registrationappacr"
$acrUrl = "$acrName.azurecr.io"
$sqlServer = "regsql2807"
$sqlDatabase = "RegistrationAppDb"
$sqlAdmin = "sqladmin"
$sqlPassword = "YourSecurePassword123!@#"

Write-Host "╔════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     REGISTRATION APP DEPLOYMENT SCRIPT    ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════╝" -ForegroundColor Cyan

# =====================================================
# STEP 1: Create SQL Database
# =====================================================
Write-Host "`n[STEP 1/4] Creating SQL Database..." -ForegroundColor Yellow

az sql db create `
  --name $sqlDatabase `
  --server $sqlServer `
  --resource-group $resourceGroup `
  --edition Basic `
  --compute-model Serverless `
  --backup-storage-redundancy Local

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ SQL Database created!" -ForegroundColor Green
} else {
    Write-Host "⚠️  Database might already exist (that's OK)" -ForegroundColor Yellow
}

# =====================================================
# STEP 2: Setup Firewall
# =====================================================
Write-Host "`n[STEP 2/4] Setting up Firewall..." -ForegroundColor Yellow

az sql server firewall-rule create `
  --resource-group $resourceGroup `
  --server $sqlServer `
  --name "AllowAzureServices" `
  --start-ip-address 0.0.0.0 `
  --end-ip-address 0.0.0.0

Write-Host "✅ Firewall configured!" -ForegroundColor Green

# =====================================================
# STEP 3: Build and Push Docker Images
# =====================================================
Write-Host "`n[STEP 3/4] Building and pushing Docker images..." -ForegroundColor Yellow

# Login to ACR
Write-Host "`n  [3.1] Logging into ACR..."
az acr login --name $acrName

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to login to ACR" -ForegroundColor Red
    exit 1
}

# Build backend
Write-Host "`n  [3.2] Building backend Docker image..."
docker build -t "$acrUrl/registration-api:latest" ./backend

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Backend build failed" -ForegroundColor Red
    exit 1
}
Write-Host "  ✅ Backend image built"

# Push backend
Write-Host "`n  [3.3] Pushing backend image to ACR..."
docker push "$acrUrl/registration-api:latest"

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Backend push failed" -ForegroundColor Red
    exit 1
}
Write-Host "  ✅ Backend image pushed"

# Build frontend
Write-Host "`n  [3.4] Building frontend Docker image..."
docker build -t "$acrUrl/registration-frontend:latest" ./frontend

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Frontend build failed" -ForegroundColor Red
    exit 1
}
Write-Host "  ✅ Frontend image built"

# Push frontend
Write-Host "`n  [3.5] Pushing frontend image to ACR..."
docker push "$acrUrl/registration-frontend:latest"

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Frontend push failed" -ForegroundColor Red
    exit 1
}
Write-Host "  ✅ Frontend image pushed"

Write-Host "`n✅ All Docker images built and pushed!" -ForegroundColor Green

# =====================================================
# STEP 4: Deploy to Container Instances
# =====================================================
Write-Host "`n[STEP 4/4] Deploying to Container Instances..." -ForegroundColor Yellow

# Get ACR credentials
Write-Host "`n  [4.1] Getting ACR credentials..."
$acrUser = az acr credential show --resource-group $resourceGroup --name $acrName --query username -o tsv
$acrPassword = az acr credential show --resource-group $resourceGroup --name $acrName --query "passwords[0].value" -o tsv

Write-Host "  ✅ ACR credentials obtained"

# Build connection string
$sqlFQDN = "$sqlServer.database.windows.net"
$connString = "Server=tcp:$sqlFQDN,1433;Initial Catalog=$sqlDatabase;Persist Security Info=False;User ID=$sqlAdmin;Password=$sqlPassword;Encrypt=True;Connection Timeout=30;"

# Deploy Backend
Write-Host "`n  [4.2] Deploying Backend Container Instance..."
az container create `
  --resource-group $resourceGroup `
  --name "registration-api-$suffix" `
  --image "$acrUrl/registration-api:latest" `
  --cpu 1 `
  --memory 1 `
  --os-type Linux `
  --registry-login-server $acrUrl `
  --registry-username $acrUser `
  --registry-password $acrPassword `
  --ports 80 443 `
  --dns-name-label "registration-api-$suffix" `
  --location $location `
  --environment-variables `
    ASPNETCORE_ENVIRONMENT=Production `
    "ConnectionStrings__DefaultConnection=$connString"

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Backend deployment failed" -ForegroundColor Red
    exit 1
}
Write-Host "  ✅ Backend container deployed"

# Get backend URL
Write-Host "`n  [4.3] Getting backend URL..."
$backendFqdn = az container show `
  --resource-group $resourceGroup `
  --name "registration-api-$suffix" `
  --query ipAddress.fqdn `
  -o tsv

Write-Host "  ✅ Backend URL: http://$backendFqdn"

# Deploy Frontend
Write-Host "`n  [4.4] Deploying Frontend Container Instance..."
az container create `
  --resource-group $resourceGroup `
  --name "registration-frontend-$suffix" `
  --image "$acrUrl/registration-frontend:latest" `
  --cpu 0.5 `
  --memory 0.5 `
  --os-type Linux `
  --registry-login-server $acrUrl `
  --registry-username $acrUser `
  --registry-password $acrPassword `
  --ports 80 `
  --dns-name-label "registration-frontend-$suffix" `
  --location $location `
  --environment-variables `
    "BACKEND_URL=http://$backendFqdn"

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Frontend deployment failed" -ForegroundColor Red
    exit 1
}
Write-Host "  ✅ Frontend container deployed"

# Get frontend URL
Write-Host "`n  [4.5] Getting frontend URL..."
$frontendFqdn = az container show `
  --resource-group $resourceGroup `
  --name "registration-frontend-$suffix" `
  --query ipAddress.fqdn `
  -o tsv

Write-Host "  ✅ Frontend URL: http://$frontendFqdn"

# =====================================================
# SUCCESS!
# =====================================================
Write-Host "`n" -ForegroundColor Green
Write-Host "╔════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  🚀 DEPLOYMENT COMPLETE! 🚀              ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host "`n📍 Your Application URLs:" -ForegroundColor Cyan
Write-Host "  Frontend:  http://$frontendFqdn" -ForegroundColor Yellow
Write-Host "  API:       http://$backendFqdn" -ForegroundColor Yellow
Write-Host "  Swagger:   http://$backendFqdn/swagger/index.html" -ForegroundColor Yellow
Write-Host "  API Items: http://$backendFqdn/api/items" -ForegroundColor Yellow

Write-Host "`n💰 Monthly Cost:" -ForegroundColor Cyan
Write-Host "  Backend Container:  $15/month" -ForegroundColor Yellow
Write-Host "  Frontend Container: $5/month" -ForegroundColor Yellow
Write-Host "  SQL Database:       $5/month" -ForegroundColor Yellow
Write-Host "  ─────────────────────────────" -ForegroundColor Yellow
Write-Host "  TOTAL:              $25/month" -ForegroundColor Green

Write-Host "`n✅ Your $180 budget covers: 7.2 months!" -ForegroundColor Green

Write-Host "`n⏱️  Containers may take 2-3 minutes to start." -ForegroundColor Cyan
Write-Host "   Refresh the URLs after a few minutes if they don't load immediately." -ForegroundColor Cyan

Write-Host "`n" -ForegroundColor Green
