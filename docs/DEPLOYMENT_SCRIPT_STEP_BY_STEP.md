# Automated Deployment Script - Container Instances

## Prerequisites Checklist
Before running this script, verify:
- ✅ SQL Server created: `regsql2807.database.windows.net`
- ✅ Resource group: `rg-registration-app`
- ✅ Location: `centralindia`
- ✅ Docker images built locally (backend & frontend)
- ✅ Container Registry (ACR) exists: `registrationappacr`
- ✅ Logged into ACR: `az acr login --name registrationappacr`

---

## STEP 1: Create SQL Database (Run This First)

```powershell
# Configuration
$resourceGroup = "rg-registration-app"
$sqlServer = "regsql2807"
$dbName = "RegistrationAppDb"
$location = "centralindia"

Write-Host "Creating SQL Database..." -ForegroundColor Green

# Create database (Basic tier = $5/month)
az sql db create `
  --name $dbName `
  --server $sqlServer `
  --resource-group $resourceGroup `
  --edition Basic `
  --compute-model Serverless `
  --backup-storage-redundancy Local

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ SQL Database created successfully!" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to create database" -ForegroundColor Red
    exit 1
}
```

---

## STEP 2: Configure Firewall Rules

```powershell
$resourceGroup = "rg-registration-app"
$sqlServer = "regsql2807"

Write-Host "Setting up Firewall rules..." -ForegroundColor Green

# Allow Azure services
az sql server firewall-rule create `
  --resource-group $resourceGroup `
  --server $sqlServer `
  --name "AllowAzureServices" `
  --start-ip-address 0.0.0.0 `
  --end-ip-address 0.0.0.0

# Allow your local machine (replace with your IP if needed)
# az sql server firewall-rule create `
#   --resource-group $resourceGroup `
#   --server $sqlServer `
#   --name "AllowMyIP" `
#   --start-ip-address YOUR_IP_ADDRESS `
#   --end-ip-address YOUR_IP_ADDRESS

Write-Host "✅ Firewall rules configured!" -ForegroundColor Green
```

---

## STEP 3: Build and Push Docker Images to ACR

```powershell
$acrName = "registrationappacr"
$acrLoginServer = "$acrName.azurecr.io"

Write-Host "Logging into ACR..." -ForegroundColor Green
az acr login --name $acrName

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to login to ACR" -ForegroundColor Red
    exit 1
}

Write-Host "Building and pushing Docker images..." -ForegroundColor Green

# Build and push backend image
Write-Host "`n[1/2] Building backend image..."
docker build -t "$acrLoginServer/registration-api:latest" ./backend

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Backend build failed" -ForegroundColor Red
    exit 1
}

Write-Host "Pushing backend image..."
docker push "$acrLoginServer/registration-api:latest"

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Backend push failed" -ForegroundColor Red
    exit 1
}

# Build and push frontend image
Write-Host "`n[2/2] Building frontend image..."
docker build -t "$acrLoginServer/registration-frontend:latest" ./frontend

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Frontend build failed" -ForegroundColor Red
    exit 1
}

Write-Host "Pushing frontend image..."
docker push "$acrLoginServer/registration-frontend:latest"

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Frontend push failed" -ForegroundColor Red
    exit 1
}

Write-Host "`n✅ Docker images built and pushed successfully!" -ForegroundColor Green
```

---

## STEP 4: Deploy to Container Instances (THE MAIN DEPLOYMENT)

```powershell
# =====================================================
# CONFIGURATION - UPDATE THESE VALUES
# =====================================================

$resourceGroup = "rg-registration-app"
$location = "centralindia"
$acrName = "registrationappacr"
$acrLoginServer = "$acrName.azurecr.io"
$sqlServer = "regsql2807"
$sqlDatabase = "RegistrationAppDb"
$sqlAdmin = "sqladmin"
$sqlPassword = "YourSecurePassword123!@#"

# Container names
$backendContainerName = "registration-api-prod"
$frontendContainerName = "registration-frontend-prod"

# DNS names (must be globally unique)
$backendDnsLabel = "registration-api-2808"  # Change 2808 to unique suffix if needed
$frontendDnsLabel = "registration-frontend-2808"  # Change 2808 to unique suffix if needed

# =====================================================
# GET ACR CREDENTIALS
# =====================================================

Write-Host "Getting ACR credentials..." -ForegroundColor Green

$acrUser = az acr credential show --resource-group $resourceGroup --name $acrName --query username -o tsv
$acrPassword = az acr credential show --resource-group $resourceGroup --name $acrName --query "passwords[0].value" -o tsv

if (-not $acrUser -or -not $acrPassword) {
    Write-Host "❌ Failed to get ACR credentials" -ForegroundColor Red
    exit 1
}

Write-Host "✅ ACR credentials obtained" -ForegroundColor Green

# =====================================================
# BUILD CONNECTION STRING
# =====================================================

$sqlFQDN = "$sqlServer.database.windows.net"
$connString = "Server=tcp:$sqlFQDN,1433;Initial Catalog=$sqlDatabase;Persist Security Info=False;User ID=$sqlAdmin;Password=$sqlPassword;Encrypt=True;Connection Timeout=30;"

Write-Host "Connection String: $connString" -ForegroundColor Cyan

# =====================================================
# DEPLOY BACKEND CONTAINER
# =====================================================

Write-Host "`n[1/2] Deploying Backend Container Instance..." -ForegroundColor Yellow

az container create `
  --resource-group $resourceGroup `
  --name $backendContainerName `
  --image "$acrLoginServer/registration-api:latest" `
  --cpu 1 `
  --memory 1 `
  --registry-login-server $acrLoginServer `
  --registry-username $acrUser `
  --registry-password $acrPassword `
  --ports 80 `
  --dns-name-label $backendDnsLabel `
  --location $location `
  --environment-variables `
    ASPNETCORE_ENVIRONMENT=Production `
    "ConnectionStrings__DefaultConnection=$connString"

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Backend deployment failed" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Backend container deployed!" -ForegroundColor Green

# Get backend FQDN
$backendFqdn = az container show `
  --resource-group $resourceGroup `
  --name $backendContainerName `
  --query ipAddress.fqdn `
  -o tsv

Write-Host "Backend URL: http://$backendFqdn" -ForegroundColor Cyan

# =====================================================
# DEPLOY FRONTEND CONTAINER
# =====================================================

Write-Host "`n[2/2] Deploying Frontend Container Instance..." -ForegroundColor Yellow

az container create `
  --resource-group $resourceGroup `
  --name $frontendContainerName `
  --image "$acrLoginServer/registration-frontend:latest" `
  --cpu 0.5 `
  --memory 0.5 `
  --registry-login-server $acrLoginServer `
  --registry-username $acrUser `
  --registry-password $acrPassword `
  --ports 80 `
  --dns-name-label $frontendDnsLabel `
  --location $location `
  --environment-variables `
    "BACKEND_URL=http://$backendFqdn"

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Frontend deployment failed" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Frontend container deployed!" -ForegroundColor Green

# Get frontend FQDN
$frontendFqdn = az container show `
  --resource-group $resourceGroup `
  --name $frontendContainerName `
  --query ipAddress.fqdn `
  -o tsv

Write-Host "Frontend URL: http://$frontendFqdn" -ForegroundColor Cyan

# =====================================================
# DEPLOYMENT COMPLETE!
# =====================================================

Write-Host "`n" -ForegroundColor Green
Write-Host "╔════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║     🚀 DEPLOYMENT COMPLETE! 🚀            ║" -ForegroundColor Green
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

Write-Host "`n⏱️  First run may take 2-3 minutes to start serving requests." -ForegroundColor Cyan
Write-Host "   Check status with:" -ForegroundColor Cyan
Write-Host "   az container show --resource-group rg-registration-app --name $backendContainerName --query instanceView.state -o tsv" -ForegroundColor Cyan
```

---

## STEP 5: Verify Deployment

```powershell
# Check if containers are running
Write-Host "Checking container status..." -ForegroundColor Green

az container list --resource-group rg-registration-app --output table

# Check specific container logs
Write-Host "`nBackend logs:" -ForegroundColor Green
az container logs --resource-group rg-registration-app --name registration-api-prod

Write-Host "`nFrontend logs:" -ForegroundColor Green
az container logs --resource-group rg-registration-app --name registration-frontend-prod
```

---

## Complete Deployment Flow

```powershell
# RUN THESE IN ORDER:

# 1. Create SQL Database
# (Copy STEP 1 code and run)

# 2. Configure Firewall
# (Copy STEP 2 code and run)

# 3. Build and Push Images
# (Copy STEP 3 code and run)

# 4. Deploy Containers
# (Copy STEP 4 code and run)

# 5. Verify
# (Copy STEP 5 code and run)
```

---

## Troubleshooting

### Container won't start
```powershell
# Check logs
az container logs --resource-group rg-registration-app --name registration-api-prod

# Check state
az container show --resource-group rg-registration-app --name registration-api-prod --query instanceView
```

### Connection string issues
```powershell
# Verify SQL Server is reachable
# Connection string format:
# Server=tcp:regsql2807.database.windows.net,1433;Initial Catalog=RegistrationAppDb;User ID=sqladmin;Password=***
```

### DNS label already exists
```powershell
# Change the DNS label to something unique:
# $backendDnsLabel = "registration-api-YOUR-UNIQUE-ID"
# $frontendDnsLabel = "registration-frontend-YOUR-UNIQUE-ID"
```

---

## Next Steps After Deployment

1. **Test your app**
   - Open frontend URL in browser
   - Add an item through the UI
   - Verify it appears in the list

2. **Check database**
   - Items should be persisted in SQL Database
   - Connect using SQL Server Management Studio if needed

3. **Monitor costs**
   - Check Azure Portal > Cost Management
   - Verify charges match projections

4. **Set up alerts**
   - Azure Portal > Cost Management + Billing > Budgets
   - Alert at 90% of $180 budget

---

## Cost Tracking Command

```powershell
# Check current spending
az costmanagement query create `
  --scope "/subscriptions/YOUR_SUBSCRIPTION_ID" `
  --timeframe MonthToDate `
  --type "Usage"
```
