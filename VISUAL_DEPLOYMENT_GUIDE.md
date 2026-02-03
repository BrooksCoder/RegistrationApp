# Azure Deployment - Step-by-Step Visual Guide

## Overview: Your Journey to Production 🚀

```
LOCAL DEVELOPMENT          AZURE SETUP              CI/CD PIPELINE          PRODUCTION
┌──────────────┐          ┌──────────────┐         ┌──────────────┐       ┌──────────────┐
│ Docker ✓     │   Push   │ GitHub/Azure │  Setup  │ DevOps       │Deploy │ Azure        │
│ - Frontend   │ ─────→   │ Repository   │ ─────→  │ Pipelines    │────→  │ - Frontend   │
│ - Backend    │          │              │         │              │       │ - Backend    │
│ - Database   │          └──────────────┘         └──────────────┘       │ - Database   │
└──────────────┘          Step 1-2 (5 min)        Step 3-4 (25 min)       └──────────────┘
  Status: ✅                 ~5 minutes               ~25 minutes           Auto-Deploy! ✅
```

---

## Phase 1: Azure Account Setup

### 1.1 Login to Azure

```powershell
# Open PowerShell and run:
az login

# Output will show your subscriptions and accounts
# Select the one you want to use
```

**What happens:**
- Browser opens for Microsoft login
- You authenticate with your Microsoft account
- Azure CLI gets access token
- Command completes with account info

**Result:** ✅ You're authenticated to Azure

---

### 1.2 Create Resource Group

```powershell
# Create a container for all resources
az group create `
  --name RegistrationApp-RG `
  --location "East US"

# Output: Resource group created successfully
```

**What happens:**
- Logical container created in Azure
- All resources go here
- Easy to delete everything later if needed

**Result:** ✅ Resource group ready

---

## Phase 2: Create Azure Resources

### 2.1 Run Infrastructure Setup Script

```powershell
# Navigate to scripts folder
cd c:\Users\Admin\source\repos\RegistrationApp\scripts

# Run the setup script
.\setup-azure-infrastructure.ps1 `
  -ResourceGroupName "RegistrationApp-RG" `
  -Location "East US" `
  -Environment "Production"

# Grab a coffee ☕ - This takes about 25-30 minutes
# Progress will be shown in real-time
```

**What gets created:**
- ✅ Container Registry (ACR) - For Docker images
- ✅ App Service Plan - Hosting tier (B1 Basic)
- ✅ App Service - Hosts backend API
- ✅ Static Web App - Hosts frontend
- ✅ SQL Server - Database server
- ✅ SQL Database - RegistrationAppDb
- ✅ Key Vault - Secrets storage
- ✅ Application Insights - Monitoring

**Script Output Example:**
```
✓ Creating Resource Group...
✓ Creating Container Registry (registrationappacr)...
✓ Creating App Service Plan...
✓ Creating App Service for Backend (registrationapp-api)...
✓ Creating Static Web App for Frontend...
✓ Creating SQL Server...
✓ Creating SQL Database (RegistrationAppDb)...
✓ Creating Key Vault (registrationappkv-xxxxx)...
✓ Creating Application Insights...

✓ All resources created successfully!

Key Information:
- App Service URL: https://registrationapp-api.azurewebsites.net
- Static Web App URL: https://registrationapp-frontend.azureapp.com
- SQL Server: registrationapp-sqlserver.database.windows.net
- Container Registry: registrationappacr.azurecr.io
- Key Vault: registrationappkv-xxxxx
```

**Result:** ✅ All Azure resources created

---

### 2.2 Store Secrets in Key Vault

```powershell
# Get the Key Vault name from script output
$kvName = "registrationappkv-xxxxx"

# Store SQL connection string
az keyvault secret set `
  --vault-name $kvName `
  --name "SqlConnectionString" `
  --value "Server=tcp:registrationapp-sqlserver.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourPassword123!;MultipleActiveResultSets=False;Encrypt=True;Connection Timeout=30;"

# Verify it was stored
az keyvault secret list --vault-name $kvName
```

**Result:** ✅ Secrets securely stored

---

## Phase 3: Azure DevOps Setup

### 3.1 Create DevOps Project

**Steps in Azure DevOps:**

1. Go to: https://dev.azure.com
2. Click "+ New project"
3. Enter:
   - **Project name:** `RegistrationApp`
   - **Visibility:** Private
   - **Version control:** Git
4. Click **Create**

```
Browser Window:
┌─────────────────────────────────────┐
│  Azure DevOps                    [X]│
├─────────────────────────────────────┤
│ + New project                       │
├─────────────────────────────────────┤
│ Project name: RegistrationApp       │
│                                     │
│ Visibility:  ☑ Private             │
│              ☐ Public              │
│                                     │
│ Version control: ☑ Git             │
│                  ☐ TFVC            │
│                                     │
│            [ Create ]               │
└─────────────────────────────────────┘
```

**Result:** ✅ DevOps project created

---

### 3.2 Create Service Connections

#### Service Connection 1: Azure Resource Manager

**In DevOps Project:**
1. Go: **Project Settings** → **Service connections**
2. Click: **New service connection**
3. Select: **Azure Resource Manager**
4. Authentication: **Service Principal (automatic)**
5. Fill in:
   - Subscription: Your subscription
   - Resource Group: `RegistrationApp-RG`
   - Service connection name: `RegistrationApp-Azure`
6. Click: **Verify and save**

```
Connection Details:
┌──────────────────────────────────────┐
│ Service Connection Name               │
│ RegistrationApp-Azure               │
├──────────────────────────────────────┤
│ Subscription:                         │
│ [Select your Azure subscription]     │
├──────────────────────────────────────┤
│ Resource Group:                       │
│ RegistrationApp-RG                  │
├──────────────────────────────────────┤
│ [Verify and save]                   │
└──────────────────────────────────────┘
```

#### Service Connection 2: Docker Registry

1. Go: **Project Settings** → **Service connections**
2. Click: **New service connection**
3. Select: **Docker Registry**
4. Registry type: **Azure Container Registry**
5. Fill in:
   - Connection name: `RegistrationApp-ACR`
   - Azure subscription: (Select the Azure service connection)
   - Container registry: `registrationappacr`
6. Click: **Verify and save**

**Result:** ✅ Both service connections created

---

### 3.3 Link Your Repository

**If using GitHub:**
1. Go to: https://dev.azure.com/YOUR_ORG/RegistrationApp
2. Click: **Pipelines** → **Create Pipeline**
3. Select: **GitHub**
4. Authorize DevOps to access GitHub
5. Select: **RegistrationApp** repository
6. Click: **Continue**

**If using Azure Repos:**
1. Same steps but select **Azure Repos Git**
2. No authorization needed

**Result:** ✅ Repository linked

---

## Phase 4: Configure CI/CD Pipeline

### 4.1 Create Pipeline from YAML

**In DevOps:**
1. Click: **Pipelines** → **Create Pipeline** (if not already shown)
2. Select: **Existing Azure Pipelines YAML file**
3. Select: `azure-pipelines.yml`
4. Click: **Continue**
5. Review the pipeline
6. Click: **Save** (or **Save and run**)

**What the pipeline does:**

```
Push to main branch
        ↓
    BUILD STAGE (3-5 min)
    • Download Node.js 18
    • npm ci (install dependencies)
    • ng build --configuration production
    • dotnet restore
    • dotnet build -c Release
        ↓
    TEST STAGE (2-3 min)
    • Run backend unit tests
    • Run frontend tests
    • Check code coverage
        ↓
    DOCKER STAGE (5-7 min)
    • Build frontend image
    • Build backend image
    • Push to Azure Container Registry
        ↓
    DEPLOY STAGE (5-10 min)
    • Deploy backend to App Service
    • Deploy frontend to Static Web App
    • Run database migrations
    • Health checks
        ↓
    ✅ APPLICATION LIVE IN PRODUCTION!
```

**Result:** ✅ Pipeline configured

---

### 4.2 First Pipeline Run

**Trigger manually:**
1. Go: https://dev.azure.com/YOUR_ORG/RegistrationApp/_build
2. Click: **Run pipeline**
3. Select: **main** branch
4. Click: **Run**

**Monitor progress:**
- Watch each stage complete in real-time
- See build logs if any errors
- Duration: ~20-30 minutes total

**Pipeline Dashboard Example:**
```
┌─────────────────────────────────────────┐
│ Pipeline: RegistrationApp               │
├─────────────────────────────────────────┤
│ Status: In progress...                  │
├─────────────────────────────────────────┤
│ ✓ Build Stage (Completed - 4 min)       │
│   ├─ Download Node.js                   │
│   ├─ Build frontend                     │
│   └─ Build backend                      │
│                                         │
│ ✓ Test Stage (Completed - 2 min)        │
│   ├─ Frontend tests                     │
│   └─ Backend tests                      │
│                                         │
│ ⟳ Docker Stage (In progress... 45%)     │
│   ├─ Build frontend image               │
│   ├─ Build backend image                │
│   └─ Push to registry...                │
│                                         │
│ ◯ Deploy Stage (Queued)                 │
│   ├─ Deploy backend                     │
│   ├─ Deploy frontend                    │
│   └─ Migrate database                   │
└─────────────────────────────────────────┘
```

**Result:** ✅ Pipeline running

---

## Phase 5: Verify Live Deployment

### 5.1 Check Backend

```powershell
# After pipeline completes, test the backend
curl "https://registrationapp-api.azurewebsites.net/swagger/index.html"

# Should return Swagger UI (HTML page)
# If successful: ✅ Backend is working
```

### 5.2 Check Frontend

```
Open browser to:
https://registrationapp-frontend.azureapp.com

You should see:
- ✅ Angular application loaded
- ✅ "Registration Items" heading
- ✅ Input field to add items
- ✅ List of items (if any exist)
```

### 5.3 Test Full Flow

1. **Add an item:**
   - Enter: Name = "Samsung", Description = "Samsung S24 Ultra"
   - Click: **Add Item**
   - Should see success message ✅

2. **View items:**
   - Items should appear in list below
   - Data persisted in Azure SQL Database ✅

3. **Delete item:**
   - Click delete button on item
   - Item should disappear
   - Should see success message ✅

**Result:** ✅ Full application working in production!

---

## Continuous Deployment Workflow

### After First Successful Deploy

**Every code change you make:**

```
Local Development:
┌─────────────────────┐
│ Make code changes   │
│ git add .           │
│ git commit -m "..."│
│ git push origin main│
└──────┬──────────────┘
       │
       ↓
Azure DevOps:
┌──────────────────────┐
│ Pipeline triggers    │
│ (automatically!)     │
└──────┬───────────────┘
       │
       ↓
┌──────────────────────┐
│ Build & Test (5 min) │
└──────┬───────────────┘
       │
       ↓
┌──────────────────────┐
│ Docker Build (7 min) │
└──────┬───────────────┘
       │
       ↓
┌──────────────────────┐
│ Deploy (10 min)      │
└──────┬───────────────┘
       │
       ↓
✅ Live in Production! (Automatic!)
```

**Example:**
```powershell
# Edit backend code
code .\backend\Controllers\ItemsController.cs

# Add new feature, save file

# Commit and push
git add .
git commit -m "Add new API endpoint"
git push origin main

# ✅ Pipeline runs automatically
# ✅ Tests pass
# ✅ Deployed to production in ~20 minutes
# ✅ Live without any manual steps!
```

---

## Troubleshooting Guide

### Problem: Pipeline Build Fails

**Solution:**
```powershell
# 1. Check the error logs in DevOps
# Go to: Pipeline → Failed run → See error in logs

# 2. Common issues:
# - Missing dependencies: Check npm install / dotnet restore
# - Syntax errors: Check build output for file/line number
# - Test failures: Run tests locally to reproduce

# 3. Fix and push again:
git add .
git commit -m "Fix build error"
git push origin main
# Pipeline re-runs automatically!
```

### Problem: Frontend Can't Call Backend API

**Solution:**
```csharp
// In backend/Program.cs, verify CORS is configured:
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFrontend",
        policy => policy
            .WithOrigins("https://registrationapp-frontend.azureapp.com")
            .AllowAnyMethod()
            .AllowAnyHeader());
});

app.UseCors("AllowFrontend");
```

### Problem: Database Connection Fails

**Solution:**
```powershell
# Check connection string in Key Vault
az keyvault secret show `
  --vault-name registrationappkv-xxxxx `
  --name "SqlConnectionString"

# Verify it's correct:
# Server=tcp:registrationapp-sqlserver.database.windows.net,1433;
# Database=RegistrationAppDb;
# User Id=sqladmin;
# Password=[Your Password]
```

---

## Post-Deployment Tasks

### 1. Setup Monitoring Alerts

```powershell
# Create alert for HTTP 500 errors
az monitor alert create `
  --name "Http500Alert" `
  --resource-group "RegistrationApp-RG" `
  --action email ADMIN_EMAIL@company.com
```

### 2. Configure Custom Domain (Optional)

```powershell
# If you have a custom domain:
# 1. Go to Azure Portal
# 2. App Service → Custom domains
# 3. Add custom domain
# 4. Update DNS CNAME record with registrar
```

### 3. Setup Auto-Scaling

```powershell
# Auto-scale App Service based on CPU
az appservice plan update `
  --name registrationapp-plan `
  --resource-group RegistrationApp-RG `
  --enable-autoscale true `
  --min-instances 1 `
  --max-instances 10 `
  --cpu-threshold 70
```

---

## Deployment Complete! 🎉

### What You Now Have:

✅ **Frontend** - Global CDN, Lightning fast  
✅ **Backend API** - Auto-scaling, HTTPS  
✅ **Database** - Azure SQL with backups  
✅ **CI/CD Pipeline** - Automated deployments  
✅ **Monitoring** - Real-time alerts  
✅ **Security** - Key Vault, SSL, CORS  

### Live URLs:

| Component | URL |
|-----------|-----|
| Frontend | `https://registrationapp-frontend.azureapp.com` |
| Backend | `https://registrationapp-api.azurewebsites.net` |
| API Docs | `https://registrationapp-api.azurewebsites.net/swagger/index.html` |

### Next Steps:

1. Share frontend URL with users
2. Monitor Application Insights
3. Continue developing with auto-deployment
4. Scale as needed (auto-scaling configured)

---

**Congratulations! Your app is now in production on Azure! 🚀**

Questions? Check `AZURE_DEPLOYMENT_GUIDE.md` for detailed help.
