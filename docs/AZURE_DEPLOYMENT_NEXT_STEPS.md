# ✅ Azure Resources Created - Next Steps to Deploy

## Your Azure Resources
```
Resource Group:    rg-registration-app
SQL Server:        regsql2807.database.windows.net
SQL Database:      RegistrationAppDb
Backend App:       https://registration-api-2807.azurewebsites.net
Key Vault:         regsql-kv-2807
```

---

## Step 1: Configure SQL Database

### 1.1 Get SQL Server Admin Password
Check the Key Vault or your setup script output for the SQL admin password.

### 1.2 Enable Firewall Rules
```powershell
# Allow your current IP to access SQL Server
az sql server firewall-rule create `
  --resource-group rg-registration-app `
  --server regsql2807 `
  --name "AllowMyIP" `
  --start-ip-address YOUR_IP `
  --end-ip-address YOUR_IP

# Example: Allow Azure services
az sql server firewall-rule create `
  --resource-group rg-registration-app `
  --server regsql2807 `
  --name "AllowAzureServices" `
  --start-ip-address 0.0.0.0 `
  --end-ip-address 0.0.0.0
```

### 1.3 Run Database Migrations
```powershell
# Get connection string from Key Vault
az keyvault secret show `
  --vault-name regsql-kv-2807 `
  --name "SqlConnectionString" `
  --query value -o tsv

# Copy the connection string and run from backend folder
cd backend
dotnet ef database update --connection "YOUR_CONNECTION_STRING"
```

---

## Step 2: Push Code to Repository

### 2.1 Initialize Git (if not done)
```powershell
cd C:\Users\Admin\source\repos\RegistrationApp
git init
git add .
git commit -m "Initial commit: Full-stack Registration Application"
```

### 2.2 Add Remote Repository

**Option A: Azure Repos (Recommended for Azure DevOps)**
```powershell
# Go to: https://dev.azure.com/YOUR_ORG/RegistrationApp
# Create a new project named "RegistrationApp"
# Then add the remote:

git remote add origin https://dev.azure.com/YOUR_ORG/RegistrationApp/_git/RegistrationApp
git branch -M main
git push -u origin main
```

**Option B: GitHub**
```powershell
git remote add origin https://github.com/YOUR_USERNAME/RegistrationApp.git
git branch -M main
git push -u origin main
```

---

## Step 3: Setup Azure DevOps Project

### 3.1 Create DevOps Project
1. Go to https://dev.azure.com
2. Click **+ New project**
3. Name: `RegistrationApp`
4. Visibility: **Private**
5. Click **Create**

### 3.2 Create Service Connection
1. Go to **Project Settings** → **Service connections**
2. Click **New service connection** → **Azure Resource Manager**
3. Configure:
   - **Scope level**: Subscription
   - **Connection name**: `RegistrationApp-Azure`
   - **Subscription**: Select your Azure subscription
   - **Resource Group**: `rg-registration-app`
4. Click **Save**

### 3.3 Create Container Registry Connection
1. Go to **Service connections** → **New service connection**
2. Select **Docker Registry**
3. Configure:
   - **Docker Registry**: Azure Container Registry
   - **Connection name**: `RegistrationApp-ACR`
   - **Resource**: registrationappacr (from your resources)
4. Click **Save**

---

## Step 4: Setup CI/CD Pipeline

### 4.1 Configure Pipeline Variables
Edit `azure-pipelines.yml` in your repository:

```yaml
variables:
  azureSubscription: 'RegistrationApp-Azure'
  containerRegistry: 'registrationappacr.azurecr.io'
  dockerRegistryServiceConnection: 'RegistrationApp-ACR'
  resourceGroupName: 'rg-registration-app'
  appServiceName: 'registration-api-2807'
  staticWebAppName: 'registration-frontend-2807'
```

### 4.2 Create Pipeline in Azure DevOps
1. Go to **Pipelines** → **Create Pipeline**
2. Select **Azure Repos Git**
3. Select repository: `RegistrationApp`
4. Select **Existing Azure Pipelines YAML file**
5. Select `/azure-pipelines.yml`
6. Click **Continue**
7. Click **Save and run**

---

## Step 5: Configure Backend App Service

### 5.1 Set Connection String
```powershell
# Get SQL connection string
$connString = az keyvault secret show `
  --vault-name regsql-kv-2807 `
  --name "SqlConnectionString" `
  --query value -o tsv

# Set in App Service
az webapp config appsettings set `
  --resource-group rg-registration-app `
  --name registration-api-2807 `
  --settings ConnectionStrings__DefaultConnection="$connString"
```

### 5.2 Enable Managed Identity
```powershell
# Assign system-managed identity
az webapp identity assign `
  --resource-group rg-registration-app `
  --name registration-api-2807 `
  --identities [system]
```

### 5.3 Configure CORS (if frontend on different domain)
```powershell
# Update backend to allow frontend origin
az webapp cors add `
  --resource-group rg-registration-app `
  --name registration-api-2807 `
  --allowed-origins "https://registration-frontend-2807.azurewebsites.net"
```

---

## Step 6: Configure Frontend Static Web App

### 6.1 Create Static Web App (if not created)
```powershell
# Check if it exists
az staticwebapp show `
  --resource-group rg-registration-app `
  --name registration-frontend-2807

# If needed, create with deployment token
az staticwebapp create `
  --resource-group rg-registration-app `
  --name registration-frontend-2807 `
  --source https://YOUR_REPO_URL `
  --branch main `
  --location "eastus"
```

### 6.2 Get Deployment Token
```powershell
$token = az staticwebapp secrets list `
  --resource-group rg-registration-app `
  --name registration-frontend-2807 `
  --query properties.apiKey -o tsv

Write-Host "Add this to Azure DevOps secret: $token"
```

---

## Step 7: Deploy Backend

### 7.1 Manual Deployment (First Time)
```powershell
# Build backend
cd backend
dotnet build -c Release

# Publish to folder
dotnet publish -c Release -o ./publish

# Deploy to App Service
az webapp up `
  --resource-group rg-registration-app `
  --name registration-api-2807 `
  --plan registration-api-plan-2807 `
  --runtime "dotnet:8" `
  --source-location ./publish
```

### 7.2 Or Use Pipeline (Recommended)
1. Push code to your repository
2. Pipeline automatically builds and deploys
3. Monitor at: https://dev.azure.com/YOUR_ORG/RegistrationApp/_build

---

## Step 8: Deploy Frontend

### 8.1 Build Angular App
```powershell
cd frontend
npm install
ng build --configuration production
```

### 8.2 Deploy to Static Web App
```powershell
# Option A: Using CLI
az staticwebapp upload `
  --resource-group rg-registration-app `
  --name registration-frontend-2807 `
  --source-location ./dist/registration-app `
  --api-location ./api `
  --deployment-token $token

# Option B: Via Pipeline (automatic on git push)
```

---

## Step 9: Verify Deployment

### 9.1 Test Backend API
```powershell
# Get backend URL
$backendUrl = "https://registration-api-2807.azurewebsites.net"

# Test health endpoint
Invoke-RestMethod "$backendUrl/health" -Method GET

# Test items endpoint
Invoke-RestMethod "$backendUrl/api/items" -Method GET
```

### 9.2 Test Frontend
```
Navigate to:
https://registration-frontend-2807.azurewebsites.net

You should see the Angular app with working Add/Delete items functionality
```

---

## Step 10: Configure Monitoring & Alerts

### 10.1 Enable Application Insights
```powershell
# Check if Application Insights is linked
az webapp config appsettings show `
  --resource-group rg-registration-app `
  --name registration-api-2807 `
  --query "[?name=='APPINSIGHTS_INSTRUMENTATIONKEY']"
```

### 10.2 View Logs
```powershell
# Stream backend logs
az webapp log tail `
  --resource-group rg-registration-app `
  --name registration-api-2807
```

### 10.3 Setup Alert
```powershell
# Alert on failed requests (5xx errors)
az monitor metrics alert create `
  --resource-group rg-registration-app `
  --name "HighErrorRate" `
  --scopes /subscriptions/YOUR_SUB/resourceGroups/rg-registration-app/providers/Microsoft.Web/sites/registration-api-2807 `
  --condition "avg Http5xx > 10" `
  --window-size 5m `
  --evaluation-frequency 1m
```

---

## Quick Troubleshooting

### Frontend can't reach backend API
**Fix:** Update frontend URL to match backend App Service URL
```
File: frontend/src/app/services/item.service.ts
Change: https://registration-api-2807.azurewebsites.net/api/items
```

### Database connection fails
**Fix:** Check firewall rules and connection string
```powershell
az sql server firewall-rule list --resource-group rg-registration-app --server regsql2807
```

### Pipeline fails
**Fix:** Check service connections
```
Azure DevOps → Project Settings → Service connections
Verify: RegistrationApp-Azure and RegistrationApp-ACR both working
```

---

## Summary Checklist

- [ ] SQL Server firewall configured
- [ ] Database migrations applied
- [ ] Code pushed to repository (Azure Repos or GitHub)
- [ ] Azure DevOps project created
- [ ] Service connections configured
- [ ] Pipeline created and tested
- [ ] Backend deployed and working
- [ ] Frontend deployed and working
- [ ] CORS configured correctly
- [ ] Monitoring enabled
- [ ] Alerts configured

---

## Next: Production Deployment

Once everything is working:

1. **Setup Production Environment**
   - Create separate Resource Group: `rg-registration-app-prod`
   - Run infrastructure script again for production

2. **Setup CI/CD for Production**
   - Configure pipeline to deploy to prod on tag release
   - Setup approval gates before production deployment

3. **Security Hardening**
   - Enable Azure Private Endpoints
   - Setup WAF (Web Application Firewall)
   - Configure Key Vault access policies

4. **Performance Optimization**
   - Enable CDN for frontend
   - Setup database read replicas
   - Configure auto-scaling

See `AZURE_DEPLOYMENT_GUIDE.md` for detailed information on all topics.
