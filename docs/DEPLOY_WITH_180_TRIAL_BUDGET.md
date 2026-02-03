# Deploy with $180 Trial Budget - Cost-Effective Strategy

## ✅ Good News: You Have Enough Budget!

```
Trial Credit Remaining: $180
Minimum Cost to Deploy: ~$15-30/month
Duration You Can Run: 6-12 months!
```

---

## 💰 Cost-Effective Deployment Plan

### Option 1: CHEAPEST - Container Instances + SQL (Recommended) ✅

**Monthly Cost: ~$15-25**

```
Azure Container Instances (Backend):
- 1 vCPU, 1 GB RAM, always on: ~$15/month

SQL Database (Basic tier):
- 5 DTU Basic: ~$5/month

Static Web App (Frontend):
- Free tier: $0/month

Total: ~$20/month
Your $180 covers: 9 months!
```

**Why this is best:**
- ✅ Low cost
- ✅ No quota issues (Container Instances doesn't have same limits)
- ✅ Fully managed
- ✅ Your code ready to go

---

### Option 2: MODERATE - App Service (B1) + SQL

**Monthly Cost: ~$30-40**

```
App Service Plan (B1):
- Linux B1 tier: ~$12/month

SQL Database (Basic):
- 5 DTU: ~$5/month

Static Web App:
- Free tier: $0/month

Total: ~$17/month
Your $180 covers: 10+ months
```

---

### Option 3: PREMIUM - App Service (B2) + SQL

**Monthly Cost: ~$60-70**

```
App Service Plan (B2):
- Linux B2 tier: ~$50/month

SQL Database (Standard):
- S0 tier: ~$15/month

Static Web App:
- Free tier: $0/month

Total: ~$65/month
Your $180 covers: 2-3 months
```

---

## 🎯 RECOMMENDED: Option 1 (Container Instances)

### Why Container Instances?

1. **No Quota Issues** ✅
   - Container Instances doesn't have same quota restrictions
   - Can deploy immediately

2. **Cheapest** ✅
   - ~$15-20/month
   - $180 lasts 9+ months

3. **Perfect Fit** ✅
   - Your app is already Dockerized
   - Just deploy the containers

4. **Scalable** ✅
   - If traffic grows, upgrade to App Service later

---

## 🚀 Deployment Steps with $180 Budget

### Step 1: Register Required Providers

```powershell
# These are free, just enables services
az provider register --namespace Microsoft.ContainerInstance
az provider register --namespace Microsoft.Sql
az provider register --namespace Microsoft.App

# Wait ~5 minutes for registration
Write-Host "Waiting for providers to register..."
Start-Sleep -Seconds 300
```

### Step 2: Deploy Infrastructure (Cost-Optimized)

```powershell
$resourceGroup = "rg-registration-app"
$location = "eastus"
$suffix = "2807"
$acrName = "registrationappacr"

Write-Host "Deploying cost-effective infrastructure..." -ForegroundColor Green

# 1. SQL Server (Required)
Write-Host "`n[1/4] Creating SQL Server..."
az sql server create `
  --name "regsql$suffix" `
  --resource-group $resourceGroup `
  --location $location `
  --admin-user "sqladmin" `
  --admin-password "YourSecurePassword123!@#"

# 2. SQL Database (BASIC tier = $5/month)
Write-Host "`n[2/4] Creating SQL Database (Basic tier)..."
az sql db create `
  --name "RegistrationAppDb" `
  --server "regsql$suffix" `
  --resource-group $resourceGroup `
  --sku Basic `
  --edition Basic

# 3. Firewall
Write-Host "`n[3/4] Setting up Firewall..."
az sql server firewall-rule create `
  --resource-group $resourceGroup `
  --server "regsql$suffix" `
  --name "AllowAzureServices" `
  --start-ip-address 0.0.0.0 `
  --end-ip-address 0.0.0.0

# 4. Push Docker image to ACR
Write-Host "`n[4/4] Pushing Docker image to Container Registry..."

# Build and push backend
docker build -t "$acrName.azurecr.io/registration-api:latest" ./backend
docker push "$acrName.azurecr.io/registration-api:latest"

# Build and push frontend
docker build -t "$acrName.azurecr.io/registration-frontend:latest" ./frontend
docker push "$acrName.azurecr.io/registration-frontend:latest"

Write-Host "`n✅ SQL and images ready!"
```

### Step 3: Deploy to Container Instances

```powershell
$resourceGroup = "rg-registration-app"
$acrName = "registrationappacr"
$acrUrl = "$acrName.azurecr.io"
$suffix = "2807"

# Get ACR credentials
$acrUser = az acr credential show --resource-group $resourceGroup --name $acrName --query username -o tsv
$acrPassword = az acr credential show --resource-group $resourceGroup --name $acrName --query "passwords[0].value" -o tsv

Write-Host "Deploying to Container Instances..." -ForegroundColor Green

# Connection string for backend
$sqlServer = "regsql$suffix.database.windows.net"
$connString = "Server=tcp:$sqlServer,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourSecurePassword123!@#;Encrypt=True;Connection Timeout=30;"

# Deploy Backend Container Instance
Write-Host "`nDeploying Backend Container..."
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
  --environment-variables `
    ASPNETCORE_ENVIRONMENT=Production `
    ConnectionStrings__DefaultConnection="$connString"

# Get backend URL
$backendIp = az container show --resource-group $resourceGroup --name "registration-api-$suffix" --query ipAddress.fqdn -o tsv
Write-Host "Backend deployed at: http://$backendIp"

# Deploy Frontend Container Instance
Write-Host "`nDeploying Frontend Container..."
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
  --dns-name-label "registration-frontend-$suffix" `
  --environment-variables BACKEND_URL="http://$backendIp"

# Get frontend URL
$frontendUrl = az container show --resource-group $resourceGroup --name "registration-frontend-$suffix" --query ipAddress.fqdn -o tsv
Write-Host "Frontend deployed at: http://$frontendUrl"

Write-Host "`n✅ Deployment Complete!" -ForegroundColor Green
Write-Host "Frontend: http://$frontendUrl"
Write-Host "Backend: http://$backendIp/api/items"
Write-Host "Swagger: http://$backendIp/swagger/index.html"
```

---

## 💰 Monthly Cost Breakdown

### With Your $180 Budget:

```
Container Instance Backend: $15/month
SQL Database (Basic):       $5/month
Static Web App (Frontend):  $0/month
ACR (Basic):               $5/month (already created)
───────────────────────────────
TOTAL:                      $25/month

Duration: 180 ÷ 25 = 7.2 months
You can run full 7 months AND STILL have credits left!
```

### Cost Savings vs. App Service:

```
Option A (App Service B2):
- Cost: $65/month
- Duration: 180 ÷ 65 = 2.7 months

Option B (Container Instances):
- Cost: $25/month
- Duration: 180 ÷ 25 = 7.2 months

SAVINGS: 4.5 extra months of deployment!
```

---

## ✅ Deployment Comparison

| Feature | Local Docker | Container Instances | App Service B1 |
|---------|--------------|-------------------|----------------|
| **Cost/Month** | $0 | $25 | $17-20 |
| **Uptime** | Dev only | Always on | Always on |
| **Performance** | Good | Very good | Excellent |
| **Quota Issues** | N/A | ❌ No issues | ⚠️ Might have limits |
| **Setup Time** | 5 min | 30 min | 30 min |
| **Your $180 Covers** | N/A | 7 months | 9+ months |

---

## 🎯 Recommended Plan with $180 Budget

### Phase 1: Today (Next 30 minutes)
1. Register Azure providers
2. Create SQL infrastructure
3. Push Docker images to ACR
4. Deploy to Container Instances
5. Test deployment

**Cost this month: $25**

### Phase 2: Months 1-7
- Run in production
- Monitor costs
- Collect feedback
- Plan improvements

**Cost per month: $25**

### Phase 3: Month 7-8
**Option A:** Continue with paid subscription (~$25/month ongoing)
**Option B:** Upgrade to App Service if needed ($30-50/month)

---

## ⚠️ Important: Monitor Your Spending

### Set Up Cost Alerts:

```powershell
# Go to Azure Portal:
# Home → Cost Management + Billing → Budgets

# Create Budget:
# - Amount: $170 (keep $10 buffer)
# - Alert at: 90% ($153)
# - Action: Email notification
```

---

## 📊 Your Options with $180

### Option 1: Deploy NOW (Recommended) ✅
```
Deploy to Container Instances
Cost: $25/month
Duration: 7 months
Status: Recommended!
```

### Option 2: Deploy to App Service B1
```
Cost: $17-20/month
Duration: 9+ months
Status: Also good, more powerful
```

### Option 3: Hybrid Approach
```
Month 1-3: Container Instances ($25/month)
Month 4-7: Evaluate & upgrade to B1 if needed
Status: Flexible!
```

---

## 🚀 Quick Start with $180

### Run This TODAY:

```powershell
# 1. Register providers
az provider register --namespace Microsoft.ContainerInstance
az provider register --namespace Microsoft.Sql

# 2. Wait 5 minutes
Start-Sleep -Seconds 300

# 3. Run deployment script (above)

# 4. Access your app at:
# http://registration-api-2807.eastus.azurecontainers.io/api/items
# http://registration-frontend-2807.eastus.azurecontainers.io
```

---

## ✅ Action Plan with $180 Budget

1. **Register providers** (free, 5 min)
2. **Create SQL infrastructure** (5 min)
3. **Push Docker images** (10 min, free)
4. **Deploy containers** (10 min)
5. **Access your app** (DONE!)

**Total setup time: 30 minutes**
**Cost: $25/month**
**Duration: 7+ months on your $180 budget**

---

## Summary

**With $180 remaining, you can:**

✅ Deploy for 7+ months  
✅ Use Container Instances (cheaper, no quota issues)  
✅ Include SQL Database + Static Web App  
✅ Monitor costs and upgrade later if needed  
✅ Keep backup local version always working  

**RECOMMENDATION: Deploy with Container Instances today!** 🚀

Your app is ready, your budget is sufficient, no more quota issues!
