# Complete Azure Deployment Guide

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Phase 1: Prepare Your Code](#phase-1-prepare-your-code)
3. [Phase 2: Create Azure Resources](#phase-2-create-azure-resources)
4. [Phase 3: Setup Azure DevOps](#phase-3-setup-azure-devops)
5. [Phase 4: Configure CI/CD Pipeline](#phase-4-configure-cicd-pipeline)
6. [Phase 5: Deploy and Monitor](#phase-5-deploy-and-monitor)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Accounts & Tools
- ✅ **Azure Subscription** (paid or free trial)
- ✅ **Azure DevOps Account** (free, at dev.azure.com)
- ✅ **Git & GitHub** (or Azure Repos)
- ✅ **Azure CLI** installed locally (`az` command)
- ✅ **PowerShell 7+** or **Azure Cloud Shell**

### Install Azure CLI (if not already installed)
```powershell
# Windows
choco install azure-cli

# Or download from: https://aka.ms/azcliinstall

# Verify installation
az --version
```

---

## Phase 1: Prepare Your Code

### Step 1.1: Initialize Git Repository

```powershell
cd c:\Users\Admin\source\repos\RegistrationApp

# Initialize git if not already done
git init

# Add all files
git add .

# Create initial commit
git commit -m "Initial commit: Full-stack Registration Application"
```

### Step 1.2: Create a Remote Repository

**Option A: GitHub**
1. Go to https://github.com/new
2. Create repository `RegistrationApp`
3. Add remote:
   ```powershell
   git remote add origin https://github.com/YOUR_USERNAME/RegistrationApp.git
   git branch -M main
   git push -u origin main
   ```

**Option B: Azure Repos**
1. Go to https://dev.azure.com
2. Create new project `RegistrationApp`
3. Add remote:
   ```powershell
   git remote add origin https://dev.azure.com/YOUR_ORG/RegistrationApp/_git/RegistrationApp
   git push -u origin main
   ```

### Step 1.3: Verify Files Are Ready
Ensure these files exist in your repo:
- ✅ `azure-pipelines.yml` - CI/CD configuration
- ✅ `docker-compose.yml` - Docker setup (for local testing)
- ✅ `backend/Dockerfile` - Backend container
- ✅ `frontend/Dockerfile` - Frontend container
- ✅ `scripts/setup-azure-infrastructure.ps1` - Infrastructure setup

---

## Phase 2: Create Azure Resources

### Step 2.1: Login to Azure

```powershell
# Login to Azure
az login

# Select subscription (if you have multiple)
az account list --output table
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Verify login
az account show
```

### Step 2.2: Create Resource Group

```powershell
# Define variables
$resourceGroup = "RegistrationApp-RG"
$location = "East US"  # or your preferred region

# Create resource group
az group create `
  --name $resourceGroup `
  --location $location

# Verify
az group show --name $resourceGroup
```

### Step 2.3: Run Infrastructure Setup Script

```powershell
cd c:\Users\Admin\source\repos\RegistrationApp\scripts

# Review the script first
Get-Content setup-azure-infrastructure.ps1

# Run with your parameters
.\setup-azure-infrastructure.ps1 `
  -ResourceGroupName "RegistrationApp-RG" `
  -Location "East US" `
  -Environment "Production"
```

**What this script creates:**
- ✅ Azure Container Registry (ACR) - for Docker images
- ✅ App Service Plan - hosting for backend API
- ✅ App Service - .NET Core backend API
- ✅ Static Web App - Angular frontend hosting
- ✅ SQL Server & Database - RegistrationAppDb
- ✅ Key Vault - secrets management
- ✅ Application Insights - monitoring

### Step 2.4: Configure Secrets in Key Vault

```powershell
# Get the Key Vault name from the script output
$keyVaultName = "registrationappkv-XXXXX"

# Store SQL connection string
az keyvault secret set `
  --vault-name $keyVaultName `
  --name "SqlConnectionString" `
  --value "Server=tcp:registrationapp-sqlserver.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourPassword123!;MultipleActiveResultSets=False;Encrypt=True;Connection Timeout=30;"

# Store container registry credentials
az keyvault secret set `
  --vault-name $keyVaultName `
  --name "ContainerRegistryUrl" `
  --value "registrationappacr.azurecr.io"

az keyvault secret set `
  --vault-name $keyVaultName `
  --name "ContainerRegistryUsername" `
  --value "USERNAME"

az keyvault secret set `
  --vault-name $keyVaultName `
  --name "ContainerRegistryPassword" `
  --value "PASSWORD"

# Verify
az keyvault secret list --vault-name $keyVaultName
```

---

## Phase 3: Setup Azure DevOps

### Step 3.1: Create Azure DevOps Project

1. Go to https://dev.azure.com
2. Click "+ New project"
3. Enter project name: `RegistrationApp`
4. Select visibility: **Private**
5. Click **Create**

### Step 3.2: Create Service Connection

**In your Azure DevOps Project:**

1. Go to **Project Settings** → **Service connections**
2. Click **New service connection** → **Azure Resource Manager**
3. Choose **Managed Identity** or **Service Principal**
4. Fill in:
   - Connection name: `RegistrationApp-Azure`
   - Subscription: Your subscription
   - Resource Group: `RegistrationApp-RG`
5. Click **Save**

### Step 3.3: Create Container Registry Connection

1. In **Service connections**, click **New**
2. Select **Docker Registry**
3. Fill in:
   - Connection name: `RegistrationApp-ACR`
   - Docker Registry: `registrationappacr.azurecr.io`
   - Registry type: **Azure Container Registry**
   - Azure subscription: Select your service connection
   - Azure container registry: `registrationappacr`
4. Click **Save**

### Step 3.4: Link Repository

1. Go to **Pipelines** → **Create Pipeline**
2. Select your repository source (GitHub or Azure Repos)
3. Select **RegistrationApp** repository
4. Click **Continue**

---

## Phase 4: Configure CI/CD Pipeline

### Step 4.1: Review and Customize Pipeline

Your `azure-pipelines.yml` is already created. Here's what it does:

**Build Stage:**
- Builds Angular frontend (production build)
- Builds .NET Core backend
- Publishes artifacts

**Test Stage:**
- Runs backend unit tests
- Runs frontend tests

**Docker Stage:**
- Builds Docker images for both frontend and backend
- Pushes to Azure Container Registry

**Deploy Stage:**
- Deploys to App Service (backend)
- Deploys to Static Web App (frontend)

### Step 4.2: Update Pipeline Variables

Edit `azure-pipelines.yml` and update these variables:

```yaml
variables:
  azureSubscription: 'RegistrationApp-Azure'  # Your service connection name
  containerRegistry: 'registrationappacr.azurecr.io'
  dockerRegistryServiceConnection: 'RegistrationApp-ACR'
  imageRepository: 'registrationapp'
  acrName: 'registrationappacr'
  appServiceName: 'registrationapp-api'
  staticWebAppName: 'registrationapp-frontend'
  sqlServerName: 'registrationapp-sqlserver'
```

### Step 4.3: Create Pipeline

1. In Azure DevOps → **Pipelines** → **Create Pipeline**
2. Select **Azure Repos Git** or **GitHub**
3. Select repository
4. Select **Existing Azure Pipelines YAML file**
5. Select `azure-pipelines.yml`
6. Click **Save and run**

---

## Phase 5: Deploy and Monitor

### Step 5.1: Run Initial Pipeline

1. Go to **Pipelines** in Azure DevOps
2. Click on your pipeline
3. Click **Run pipeline**
4. Monitor the build progress in real-time

**Pipeline Stages:**
- 🔨 Build: 3-5 minutes
- 🧪 Test: 2-3 minutes
- 📦 Docker: 5-7 minutes
- 🚀 Deploy: 5-10 minutes

### Step 5.2: Verify Deployments

**Backend API:**
```powershell
# Get the backend URL
az webapp show `
  --name registrationapp-api `
  --resource-group RegistrationApp-RG `
  --query "defaultHostName"

# Test the API
$apiUrl = "https://registrationapp-api.azurewebsites.net"
curl "$apiUrl/swagger/index.html"
curl "$apiUrl/api/items"
```

**Frontend:**
```powershell
# Get the static web app URL
az staticwebapp show `
  --name registrationapp-frontend `
  --resource-group RegistrationApp-RG `
  --query "defaultHostName"

# Open in browser
# https://registrationapp-frontend.azurewebsites.net
```

### Step 5.3: Configure Application Settings

**Backend API Settings (App Service):**

```powershell
$resourceGroup = "RegistrationApp-RG"
$appServiceName = "registrationapp-api"

# Set connection string
az webapp config connection-string set `
  --resource-group $resourceGroup `
  --name $appServiceName `
  --settings DefaultConnection="Server=tcp:registrationapp-sqlserver.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourPassword123!;MultipleActiveResultSets=False;Encrypt=True;Connection Timeout=30;" `
  --connection-string-type SQLAzure

# Set application settings
az webapp config appsettings set `
  --resource-group $resourceGroup `
  --name $appServiceName `
  --settings `
    ASPNETCORE_ENVIRONMENT=Production `
    WEBSITES_ENABLE_APP_SERVICE_STORAGE=true
```

**Frontend Configuration (Static Web App):**

Create `staticwebapp.config.json` in frontend root:

```json
{
  "routes": [
    {
      "route": "/api/*",
      "allowedRoles": ["authenticated", "anonymous"],
      "methods": ["GET", "POST", "PUT", "DELETE", "PATCH"]
    },
    {
      "route": "/*",
      "serve": "/index.html",
      "statusCode": 200
    }
  ],
  "env": {
    "production": {
      "apiBackend": "https://registrationapp-api.azurewebsites.net"
    }
  }
}
```

### Step 5.4: Setup Database Migrations

The backend API runs EF Core migrations on startup. Ensure `Program.cs` has:

```csharp
// Apply migrations automatically
var context = app.Services.CreateScope().ServiceProvider.GetRequiredService<ApplicationDbContext>();
context.Database.Migrate();
```

### Step 5.5: Monitor Application Health

**In Azure Portal:**

1. Go to **App Service** → **Monitoring**
2. Review:
   - HTTP 4xx, 5xx errors
   - Response time
   - CPU and memory usage
3. Set up **Alerts**:
   - Alert on HTTP 5xx > 5 in 5 minutes
   - Alert on CPU > 80% for 10 minutes
   - Alert on Response Time > 2 seconds

**View Logs:**

```powershell
# Tail backend logs
az webapp log tail `
  --resource-group RegistrationApp-RG `
  --name registrationapp-api

# Tail frontend logs (if using Static Web App)
az staticwebapp appsettings list `
  --name registrationapp-frontend `
  --resource-group RegistrationApp-RG
```

### Step 5.6: Setup Application Insights

Application Insights is automatically created by the infrastructure script.

**In Azure Portal:**

1. Go to **Application Insights** → **Performance**
2. Monitor:
   - Failed requests
   - Response time
   - Dependency issues (SQL, external APIs)
3. Create dashboards and workbooks for visualization

---

## Continuous Deployment Workflow

### Automatic Deployments

**Every time you push to `main` branch:**

1. ✅ Pipeline triggers automatically
2. ✅ Code builds and tests
3. ✅ Docker images build
4. ✅ Images push to ACR
5. ✅ Backend deploys to App Service
6. ✅ Frontend deploys to Static Web App
7. ✅ Database migrations run

**Example:**

```powershell
# Make a code change
code .\backend\Controllers\ItemsController.cs

# Commit and push
git add .
git commit -m "Add new feature"
git push origin main

# Watch pipeline in Azure DevOps
# https://dev.azure.com/YOUR_ORG/RegistrationApp/_build
```

---

## Manual Deployment (If Needed)

### Deploy Backend Manually

```powershell
# Build Docker image
docker build -t registrationappacr.azurecr.io/backend:latest ./backend

# Push to ACR
docker push registrationappacr.azurecr.io/backend:latest

# Deploy to App Service
az webapp deployment container config `
  --name registrationapp-api `
  --resource-group RegistrationApp-RG `
  --docker-custom-image-name registrationappacr.azurecr.io/backend:latest `
  --docker-registry-server-url https://registrationappacr.azurecr.io
```

### Deploy Frontend Manually

```powershell
# Build Angular app
cd frontend
ng build --configuration production

# Deploy to Static Web App
az staticwebapp update `
  --name registrationapp-frontend `
  --resource-group RegistrationApp-RG `
  --source ./dist/registration-app
```

---

## Rollback Strategy

### Rollback to Previous Version

```powershell
# View deployment history
az webapp deployment slot list `
  --name registrationapp-api `
  --resource-group RegistrationApp-RG

# Swap deployment slots to rollback
az webapp deployment slot swap `
  --name registrationapp-api `
  --resource-group RegistrationApp-RG `
  --slot staging
```

---

## Troubleshooting

### Issue: Pipeline Build Fails

**Check logs:**
```powershell
# View live logs
az webapp log tail --resource-group RegistrationApp-RG --name registrationapp-api

# View deployment history
az webapp deployment list --resource-group RegistrationApp-RG --name registrationapp-api
```

### Issue: Frontend Can't Call Backend

**Verify CORS settings in backend:**

```csharp
// In Program.cs
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFrontend",
        policy => policy
            .WithOrigins("https://registrationapp-frontend.azurewebsites.net")
            .AllowAnyMethod()
            .AllowAnyHeader());
});
```

### Issue: Database Connection Fails

**Check connection string:**
```powershell
az webapp config connection-string list `
  --resource-group RegistrationApp-RG `
  --name registrationapp-api

# Verify SQL server firewall
az sql server firewall-rule list `
  --resource-group RegistrationApp-RG `
  --server registrationapp-sqlserver
```

### Issue: Static Web App Returns 404

**Verify routing config:**
```powershell
az staticwebapp show `
  --resource-group RegistrationApp-RG `
  --name registrationapp-frontend
```

---

## Cost Optimization Tips

1. **Use Free Tier Services:**
   - Static Web App: Free tier available
   - Application Insights: 5GB/month free
   - Key Vault: Standard pricing only

2. **Optimize App Service:**
   - Use B1 or B2 tier for development
   - Scale down during off-hours
   - Use auto-scale for production

3. **Database Optimization:**
   - Use Basic tier for dev/test
   - Use Standard tier for production
   - Enable geo-replication only if needed

4. **Monitor Costs:**
   ```powershell
   az billing subscription list-invoices
   az cost management query create --timeframe TheLastMonth
   ```

---

## Next Steps

✅ Local development working ✓
✅ Docker containerization done ✓
✅ Azure infrastructure created ✓
✅ CI/CD pipeline configured ✓
✅ Ready for production deployment ✓

**After first successful deploy:**
1. Monitor application health daily
2. Setup auto-scaling policies
3. Configure backup strategy
4. Plan for disaster recovery
5. Document runbooks for your team

---

## Support & Documentation

- **Azure Docs:** https://docs.microsoft.com/azure
- **Azure CLI Reference:** https://docs.microsoft.com/cli/azure
- **Azure DevOps Docs:** https://docs.microsoft.com/azure/devops
- **App Service:** https://docs.microsoft.com/azure/app-service
- **Static Web Apps:** https://docs.microsoft.com/azure/static-web-apps
