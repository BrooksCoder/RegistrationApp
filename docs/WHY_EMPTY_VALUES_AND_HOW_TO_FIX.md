# Why Are AppServiceName, StaticWebAppName, and SqlServerName Empty?

## What's Happening

```
appServiceName: ''           ← Empty
staticWebAppName: ''         ← Empty
sqlServerName: ''            ← Empty
```

**Reason:** These Azure resources haven't been created yet!

When you run:
```powershell
az webapp list --resource-group rg-registration-app --query "[0].name" -o tsv
```

It returns empty because NO web apps exist in your resource group.

---

## What Resources You Currently Have

You only have:
```
✅ Container Registry: registrationappacr
✅ Key Vault: regsql-kv-2807
❌ App Service: NOT CREATED
❌ Static Web App: NOT CREATED
❌ SQL Server: NOT CREATED
❌ SQL Database: NOT CREATED
```

---

## What Happens If You Don't Create Them?

### ❌ Without These Resources:

1. **Pipeline will run but FAIL** at deployment stage
   ```
   Deploy stage → Tries to deploy to non-existent App Service → ERROR
   ```

2. **Frontend won't deploy** - no Static Web App to host it

3. **Database won't exist** - backend can't store data

4. **Backend has nowhere to run** - no App Service

---

## How to Fix It

### Option 1: Create Resources Manually (Recommended for First Time)

Run this PowerShell script to create everything:

```powershell
$resourceGroup = "rg-registration-app"
$location = "eastus"
$suffix = "2807"

Write-Host "Creating missing resources..." -ForegroundColor Green

# 1. Create App Service Plan (required before App Service)
Write-Host "`n[1/7] Creating App Service Plan..." -ForegroundColor Cyan
az appservice plan create `
  --name "registration-api-plan-$suffix" `
  --resource-group $resourceGroup `
  --location $location `
  --sku B2 `
  --is-linux

# 2. Create App Service (Backend)
Write-Host "`n[2/7] Creating App Service for Backend..." -ForegroundColor Cyan
az webapp create `
  --name "registration-api-$suffix" `
  --resource-group $resourceGroup `
  --plan "registration-api-plan-$suffix" `
  --runtime "DOTNET|8.0"

# 3. Create Static Web App (Frontend)
Write-Host "`n[3/7] Creating Static Web App for Frontend..." -ForegroundColor Cyan
az staticwebapp create `
  --name "registration-frontend-$suffix" `
  --resource-group $resourceGroup `
  --location $location `
  --sku Free

# 4. Create SQL Server
Write-Host "`n[4/7] Creating SQL Server..." -ForegroundColor Cyan
az sql server create `
  --name "regsql$suffix" `
  --resource-group $resourceGroup `
  --location $location `
  --admin-user "sqladmin" `
  --admin-password "YourSecurePassword123!@#"

# 5. Create SQL Database
Write-Host "`n[5/7] Creating SQL Database..." -ForegroundColor Cyan
az sql db create `
  --name "RegistrationAppDb" `
  --server "regsql$suffix" `
  --resource-group $resourceGroup `
  --sku Basic

# 6. Allow Azure services to access SQL
Write-Host "`n[6/7] Configuring SQL Firewall..." -ForegroundColor Cyan
az sql server firewall-rule create `
  --resource-group $resourceGroup `
  --server "regsql$suffix" `
  --name "AllowAzureServices" `
  --start-ip-address 0.0.0.0 `
  --end-ip-address 0.0.0.0

# 7. Configure App Service connection string
Write-Host "`n[7/7] Configuring App Service settings..." -ForegroundColor Cyan
$connString = "Server=tcp:regsql$suffix.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourSecurePassword123!@#;Encrypt=True;Connection Timeout=30;"
az webapp config appsettings set `
  --resource-group $resourceGroup `
  --name "registration-api-$suffix" `
  --settings `
    ConnectionStrings__DefaultConnection="$connString" `
    ASPNETCORE_ENVIRONMENT="Production"

Write-Host "`n✅ All resources created successfully!" -ForegroundColor Green
Write-Host "`nYour resources:" -ForegroundColor Yellow
Write-Host "  • App Service: registration-api-$suffix"
Write-Host "  • Static Web App: registration-frontend-$suffix"
Write-Host "  • SQL Server: regsql$suffix.database.windows.net"
Write-Host "  • SQL Database: RegistrationAppDb"
```

---

## After Creating Resources

### Step 1: Get the Values Again

```powershell
$resourceGroup = "rg-registration-app"

Write-Host "appServiceName: $(az webapp list --resource-group $resourceGroup --query "[0].name" -o tsv)"
Write-Host "staticWebAppName: $(az staticwebapp list --resource-group $resourceGroup --query "[0].name" -o tsv)"
Write-Host "sqlServerName: $(az sql server list --resource-group $resourceGroup --query "[0].name" -o tsv)"
```

Now you should get:
```
appServiceName: registration-api-2807
staticWebAppName: registration-frontend-2807
sqlServerName: regsql2807
```

### Step 2: Update `azure-pipelines.yml`

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
  appServiceName: 'registration-api-2807'           # ← NOW FILLED IN
  staticWebAppName: 'registration-frontend-2807'   # ← NOW FILLED IN
  sqlServerName: 'regsql2807'                       # ← NOW FILLED IN
```

### Step 3: Commit and Push

```powershell
cd c:\Users\Admin\source\repos\RegistrationApp
git add azure-pipelines.yml
git commit -m "Update pipeline variables with Azure resources"
git push origin main
```

---

## What Happens Next

```
1. Code pushed to main
   ↓
2. Pipeline triggers automatically
   ↓
3. Build stage: Builds Angular + .NET
   ✅ Success (no resources needed)
   ↓
4. Test stage: Runs tests
   ✅ Success (no resources needed)
   ↓
5. Docker stage: Builds containers
   ✅ Success (uses ACR which exists)
   ↓
6. Deploy stage: Deploys to App Service + Static Web App
   ✅ SUCCESS (now that resources exist!)
```

---

## Why Can't We Skip Creating Resources?

### If You Don't Create Them:

| Stage | Result |
|-------|--------|
| Build | ✅ Works (no Azure needed) |
| Test | ✅ Works (no Azure needed) |
| Docker | ✅ Works (ACR exists) |
| **Deploy** | ❌ **FAILS** - no App Service to deploy to |
| Backend runs | ❌ No App Service hosting it |
| Frontend runs | ❌ No Static Web App hosting it |
| Database | ❌ No SQL Server for data |

**Result:** Pipeline fails, nothing deployed to Azure

---

## Summary

| Status | What It Means | Action |
|--------|--------------|--------|
| `appServiceName: ''` | App Service doesn't exist | Create it ✅ |
| `staticWebAppName: ''` | Static Web App doesn't exist | Create it ✅ |
| `sqlServerName: ''` | SQL Server doesn't exist | Create it ✅ |

---

## Next Steps

1. **Run the creation script** (above) to create all resources
2. **Get the values** again with the commands
3. **Update `azure-pipelines.yml`** with the new values
4. **Commit and push** to trigger pipeline
5. **Watch pipeline deploy** to your new Azure resources! 🚀

---

## Verification

After creating resources, verify everything exists:

```powershell
# List all resources
az resource list --resource-group rg-registration-app --output table

# Expected output:
# Name                           ResourceGroup          Type
# -----------                    ------------------     ------------------
# registration-api-plan-2807     rg-registration-app    App Service Plan
# registration-api-2807          rg-registration-app    App Service
# registration-frontend-2807     rg-registration-app    Static Web App
# regsql2807                      rg-registration-app    SQL Server
# RegistrationAppDb              rg-registration-app    SQL Database
# registrationappacr             rg-registration-app    Container Registry
# regsql-kv-2807                 rg-registration-app    Key Vault
```

---

## Cost Consideration

These resources have monthly costs:
- **App Service Plan (B2):** ~$50/month
- **Static Web App (Free):** Free tier available
- **SQL Server (Basic):** ~$5/month  
- **Container Registry (Basic):** ~$5/month

**Total:** ~$60/month for a basic setup

If cost is a concern, use:
- B1 tier for App Service (~$12/month)
- Free tier for Static Web App
- Serverless database options

---

**TL;DR:** Create the resources, get their names, update your pipeline variables, commit, and push! The pipeline will then deploy successfully! ✅
