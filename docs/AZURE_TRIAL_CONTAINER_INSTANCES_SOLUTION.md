# Azure Trial - No Quota for App Service Plans

## Problem

Even FREE tier requires quota:
```
Current Limit (Free VMs): 0
Amount required: 1
```

Your trial subscription has **zero quota for App Service Plans**.

---

## Solution: Skip App Service - Use Docker + Container Instances

Since your app is already Dockerized, deploy directly to **Azure Container Instances** (no quota issues!):

---

## Step 1: Create SQL Resources Only

These don't need quota:

```powershell
$resourceGroup = "rg-registration-app"
$suffix = "2807"
$location = "eastus"

Write-Host "Creating SQL resources (no quota needed)..." -ForegroundColor Green

# 1. SQL Server
Write-Host "`n[1/3] Creating SQL Server..."
az sql server create `
  --name "regsql$suffix" `
  --resource-group $resourceGroup `
  --location $location `
  --admin-user "sqladmin" `
  --admin-password "YourSecurePassword123!@#"

# 2. SQL Database
Write-Host "`n[2/3] Creating SQL Database..."
az sql db create `
  --name "RegistrationAppDb" `
  --server "regsql$suffix" `
  --resource-group $resourceGroup `
  --sku Basic

# 3. Firewall
Write-Host "`n[3/3] Creating Firewall Rule..."
az sql server firewall-rule create `
  --resource-group $resourceGroup `
  --server "regsql$suffix" `
  --name "AllowAzureServices" `
  --start-ip-address 0.0.0.0 `
  --end-ip-address 0.0.0.0

Write-Host "`n✅ SQL resources created successfully!"
```

---

## Step 2: Deploy Backend Using Container Instances

```powershell
$resourceGroup = "rg-registration-app"
$suffix = "2807"
$acrName = "registrationappacr"
$acrUrl = "$acrName.azurecr.io"

# Get ACR credentials
$acrUser = az acr credential show --resource-group $resourceGroup --name $acrName --query username -o tsv
$acrPassword = az acr credential show --resource-group $resourceGroup --name $acrName --query "passwords[0].value" -o tsv

# Connection string
$sqlServer = "regsql$suffix.database.windows.net"
$connString = "Server=tcp:$sqlServer,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourSecurePassword123!@#;Encrypt=True;Connection Timeout=30;"

Write-Host "Creating Container Instance for Backend..."

# Deploy backend to Container Instance
az container create `
  --resource-group $resourceGroup `
  --name "registration-api-$suffix" `
  --image "$acrUrl/registration-api:latest" `
  --cpu 1 `
  --memory 1 `
  --registry-login-server $acrUrl `
  --registry-username $acrUser `
  --registry-password $acrPassword `
  --ports 80 443 `
  --environment-variables `
    ASPNETCORE_ENVIRONMENT=Production `
    ConnectionStrings__DefaultConnection="$connString"

Write-Host "✅ Backend deployed to Container Instance"

# Get the IP address
$backendIp = az container show --resource-group $resourceGroup --name "registration-api-$suffix" --query ipAddress.ip -o tsv
Write-Host "`nBackend URL: http://$backendIp"
```

---

## Step 3: Deploy Frontend Using Static Web App (or Container Instance)

### Option A: Static Web App (Recommended for Frontend)

```powershell
# Create Static Web App
az staticwebapp create `
  --name "registration-frontend-$suffix" `
  --resource-group $resourceGroup `
  --location $location `
  --sku Free

Write-Host "✅ Static Web App created"

# Get URL
$frontendUrl = az staticwebapp show --resource-group $resourceGroup --name "registration-frontend-$suffix" --query defaultHostName -o tsv
Write-Host "Frontend URL: https://$frontendUrl"
```

### Option B: Frontend Container Instance (Alternative)

```powershell
# Deploy frontend to Container Instance
az container create `
  --resource-group $resourceGroup `
  --name "registration-frontend-$suffix" `
  --image "$acrUrl/registration-frontend:latest" `
  --cpu 0.5 `
  --memory 0.5 `
  --registry-login-server $acrUrl `
  --registry-username $acrUser `
  --registry-password $acrPassword `
  --ports 80 `
  --environment-variables BACKEND_URL="http://$backendIp"

Write-Host "✅ Frontend deployed to Container Instance"

# Get frontend IP
$frontendIp = az container show --resource-group $resourceGroup --name "registration-frontend-$suffix" --query ipAddress.ip -o tsv
Write-Host "Frontend URL: http://$frontendIp"
```

---

## Complete Script (Recommended for Trial)

```powershell
#!/usr/bin/pwsh

$resourceGroup = "rg-registration-app"
$suffix = "2807"
$location = "eastus"
$acrName = "registrationappacr"
$acrUrl = "$acrName.azurecr.io"

Write-Host "================================" -ForegroundColor Green
Write-Host "DEPLOYING TO CONTAINER INSTANCES" -ForegroundColor Green
Write-Host "================================`n" -ForegroundColor Green

# 1. Create SQL Resources
Write-Host "[1/5] Creating SQL Server..." -ForegroundColor Cyan
az sql server create `
  --name "regsql$suffix" `
  --resource-group $resourceGroup `
  --location $location `
  --admin-user "sqladmin" `
  --admin-password "YourSecurePassword123!@#"

Write-Host "[2/5] Creating SQL Database..." -ForegroundColor Cyan
az sql db create `
  --name "RegistrationAppDb" `
  --server "regsql$suffix" `
  --resource-group $resourceGroup `
  --sku Basic

Write-Host "[3/5] Creating Firewall Rule..." -ForegroundColor Cyan
az sql server firewall-rule create `
  --resource-group $resourceGroup `
  --server "regsql$suffix" `
  --name "AllowAzureServices" `
  --start-ip-address 0.0.0.0 `
  --end-ip-address 0.0.0.0

# 2. Get ACR credentials
Write-Host "`n[4/5] Getting Container Registry credentials..." -ForegroundColor Cyan
$acrUser = az acr credential show --resource-group $resourceGroup --name $acrName --query username -o tsv
$acrPassword = az acr credential show --resource-group $resourceGroup --name $acrName --query "passwords[0].value" -o tsv

# 3. Deploy Backend
Write-Host "`n[5/5] Deploying Backend to Container Instance..." -ForegroundColor Cyan
$sqlServer = "regsql$suffix.database.windows.net"
$connString = "Server=tcp:$sqlServer,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourSecurePassword123!@#;Encrypt=True;Connection Timeout=30;"

az container create `
  --resource-group $resourceGroup `
  --name "registration-api-$suffix" `
  --image "$acrUrl/registration-api:latest" `
  --cpu 1 `
  --memory 1 `
  --registry-login-server $acrUrl `
  --registry-username $acrUser `
  --registry-password $acrPassword `
  --ports 80 443 `
  --environment-variables `
    ASPNETCORE_ENVIRONMENT=Production `
    ConnectionStrings__DefaultConnection="$connString"

# 4. Deploy Frontend
Write-Host "Deploying Frontend to Static Web App..." -ForegroundColor Cyan
az staticwebapp create `
  --name "registration-frontend-$suffix" `
  --resource-group $resourceGroup `
  --location $location `
  --sku Free

# 5. Get URLs
Write-Host "`n✅ DEPLOYMENT COMPLETE!" -ForegroundColor Green
Write-Host "`n=== Your Deployment URLs ===" -ForegroundColor Yellow

$backendIp = az container show --resource-group $resourceGroup --name "registration-api-$suffix" --query ipAddress.ip -o tsv
Write-Host "Backend API: http://$backendIp/swagger/index.html"
Write-Host "Backend URL: http://$backendIp"

$frontendUrl = az staticwebapp show --resource-group $resourceGroup --name "registration-frontend-$suffix" --query defaultHostName -o tsv
Write-Host "Frontend: https://$frontendUrl"

Write-Host "`n=== Update Your Variables ===" -ForegroundColor Yellow
Write-Host "appServiceName: registration-api-$suffix (Container Instance)"
Write-Host "staticWebAppName: registration-frontend-$suffix"
Write-Host "sqlServerName: regsql$suffix"
```

---

## Why Container Instances?

| Feature | App Service | Container Instances |
|---------|-------------|-------------------|
| Quota Issue | ❌ Zero quota on trial | ✅ No quota limits |
| Cost | ~$50/mo (B2) | ~$15/mo |
| Startup | Slow | Fast |
| Trial Friendly | ❌ No | ✅ Yes |
| Docker Support | ✅ Yes | ✅ Yes |

---

## After Deployment

### Update Pipeline Variables

```yaml
variables:
  buildConfiguration: 'Release'
  nodeVersion: '18.x'
  dotnetVersion: '8.x'
  azureSubscription: 'RegistrationApp-Azure'
  dockerRegistryServiceConnection: 'RegistrationApp-ACR'
  resourceGroupName: 'rg-registration-app'
  containerRegistry: 'registrationappacr.azurecr.io'
  acrName: 'registrationappacr'
  imageRepository: 'registration-api'
  appServiceName: 'registration-api-2807'           # Container Instance name
  staticWebAppName: 'registration-frontend-2807'   # Static Web App
  sqlServerName: 'regsql2807'                       # SQL Server
  deploymentType: 'ContainerInstance'               # NEW: Track deployment type
```

---

## Verify Deployment

```powershell
# Check backend container
az container show --resource-group rg-registration-app --name "registration-api-2807" --query ipAddress

# Check Static Web App
az staticwebapp show --resource-group rg-registration-app --name "registration-frontend-2807" --query defaultHostName

# Check SQL Server
az sql server show --resource-group rg-registration-app --name "regsql2807"
```

---

## Cost Comparison for Trial

| Option | Cost | Quota Issue |
|--------|------|-------------|
| App Service (B2) | $50/mo | ❌ No quota |
| **Container Instance** | **~$15/mo** | **✅ No quota** |
| FREE App Service | $0 | ❌ No quota |

**Container Instances = Best for Trial!** 🚀

---

## Next Steps

1. Run the complete script above
2. Get the backend & frontend URLs
3. Update `azure-pipelines.yml`
4. Commit and push
5. Pipeline will build Docker images and push to ACR
6. Manually deploy containers (or update pipeline for auto-deployment)

This is the **trial-friendly solution** that works without quota requests! ✅
