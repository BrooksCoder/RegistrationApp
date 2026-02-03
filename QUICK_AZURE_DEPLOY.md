# Azure Deployment - Quick Start Summary

Congratulations! Your application is running perfectly in Docker locally. Now let's deploy it to Azure with full CI/CD pipeline automation.

## 📋 Quick Reference: 5 Main Steps

### **STEP 1: Prepare Azure Account (10 minutes)**
```powershell
# Login to Azure
az login

# Create resource group
az group create --name RegistrationApp-RG --location "East US"
```

**What you need:**
- ✅ Azure subscription (free trial works)
- ✅ Azure CLI installed
- ✅ Created resource group

---

### **STEP 2: Create Azure Resources (30 minutes)**
```powershell
# Run infrastructure setup script
cd c:\Users\Admin\source\repos\RegistrationApp\scripts
.\setup-azure-infrastructure.ps1 `
  -ResourceGroupName "RegistrationApp-RG" `
  -Location "East US"
```

**Resources Created:**
- ✅ Container Registry (ACR) - stores Docker images
- ✅ App Service - hosts backend API
- ✅ Static Web App - hosts frontend
- ✅ SQL Database - stores data
- ✅ Key Vault - manages secrets
- ✅ Application Insights - monitors performance

---

### **STEP 3: Setup Azure DevOps (15 minutes)**

1. **Create DevOps Project**
   - Go to: https://dev.azure.com
   - Click "+ New project"
   - Name: `RegistrationApp`
   - Visibility: `Private`

2. **Create Service Connections**
   - Go to: Project Settings → Service connections
   - Add **Azure Resource Manager** connection
     - Name: `RegistrationApp-Azure`
     - Subscription: Your subscription
     - Resource Group: `RegistrationApp-RG`
   - Add **Docker Registry** connection
     - Name: `RegistrationApp-ACR`
     - Registry: `registrationappacr.azurecr.io`

3. **Link Repository**
   - Go to: Pipelines → Create Pipeline
   - Select your Git provider (GitHub or Azure Repos)
   - Select `RegistrationApp` repository
   - Choose **Existing Azure Pipelines YAML file**
   - Select: `azure-pipelines.yml`

---

### **STEP 4: Configure Secrets (5 minutes)**
```powershell
# Store SQL connection string in Key Vault
$kvName = "registrationappkv-XXXXX"  # From Step 2 output

az keyvault secret set `
  --vault-name $kvName `
  --name "SqlConnectionString" `
  --value "Server=tcp:registrationapp-sqlserver.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourPassword123!;MultipleActiveResultSets=False;Encrypt=True;Connection Timeout=30;"
```

---

### **STEP 5: Run First Deployment (10 minutes)**

1. **Trigger Pipeline**
   - Go to: https://dev.azure.com/YOUR_ORG/RegistrationApp/_build
   - Click "Run pipeline"
   - Monitor progress

2. **What Happens Automatically:**
   - ✅ Code builds (3-5 min)
   - ✅ Tests run (2-3 min)
   - ✅ Docker images build (5-7 min)
   - ✅ Backend deploys (2-3 min)
   - ✅ Frontend deploys (2-3 min)
   - ✅ Database migrations run (1 min)

3. **Verify Success**
   ```powershell
   # Test backend API
   curl "https://registrationapp-api.azurewebsites.net/swagger/index.html"
   
   # Open frontend in browser
   # https://registrationapp-frontend.azurewebsites.net
   ```

---

## 🎯 Automated Deployment (After First Deploy)

**Every time you push to `main` branch:**

```powershell
# Make changes
code .\backend\Controllers\ItemsController.cs

# Commit and push
git add .
git commit -m "Add new feature"
git push origin main

# ✅ Pipeline runs automatically
# ✅ Tests pass/fail shown in DevOps
# ✅ Deployment happens automatically
```

---

## 📊 Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                   GitHub / Azure Repos                   │
│              (Your RegistrationApp repository)           │
└──────────────────────┬──────────────────────────────────┘
                       │ Push to main branch
                       ▼
┌─────────────────────────────────────────────────────────┐
│              Azure DevOps Pipelines                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  Build Stage │→ │  Test Stage  │→ │ Docker Stage │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└──────────────────────┬──────────────────────────────────┘
                       │
            ┌──────────┴──────────┐
            ▼                     ▼
    ┌──────────────┐      ┌──────────────┐
    │   ACR Push   │      │ Deploy Stage │
    │   (Docker)   │      └──────────────┘
    └──────────────┘            │
            │         ┌─────────┴─────────┐
            │         ▼                   ▼
            │    ┌──────────────┐   ┌──────────────┐
            │    │  App Service │   │ Static Web   │
            │    │  (Backend)   │   │   App        │
            │    │              │   │ (Frontend)   │
            │    └──────────────┘   └──────────────┘
            │         │                    │
            └─────────┴────────────────────┘
                      │
                      ▼
            ┌──────────────────────┐
            │  Azure SQL Database  │
            │  (RegistrationAppDb) │
            └──────────────────────┘
```

---

## 💻 Useful Commands

### View Deployment Status
```powershell
# Watch backend logs live
az webapp log tail --resource-group RegistrationApp-RG --name registrationapp-api

# View deployment history
az webapp deployment list --resource-group RegistrationApp-RG --name registrationapp-api

# Check all resources
az resource list --resource-group RegistrationApp-RG --output table
```

### Restart Services
```powershell
# Restart backend
az webapp restart --resource-group RegistrationApp-RG --name registrationapp-api

# View backend metrics
az monitor metrics list --resource /subscriptions/YOUR_SUB/resourceGroups/RegistrationApp-RG/providers/Microsoft.Web/sites/registrationapp-api
```

### Database Management
```powershell
# Connect to SQL Database
sqlcmd -S registrationapp-sqlserver.database.windows.net -U sqladmin -P YourPassword123!

# Run query in Azure
sqlcmd -S registrationapp-sqlserver.database.windows.net -U sqladmin -P YourPassword123! -d RegistrationAppDb -q "SELECT * FROM Items"
```

---

## 🔧 Common Troubleshooting

| Issue | Solution |
|-------|----------|
| **Pipeline fails on build** | Check error logs in Azure DevOps → Pipeline logs |
| **Frontend can't reach API** | Verify CORS in `Program.cs` has frontend URL |
| **Database connection fails** | Check connection string in App Service settings |
| **Static assets not loading** | Clear browser cache (Ctrl+Shift+Del) and refresh |
| **Deployment slot issue** | Check deployment slot swap settings |

---

## 📈 Performance Monitoring

After deployment, monitor your application:

1. **Go to Azure Portal**
   - Search for "Application Insights"
   - Select your insights resource
   - View:
     - Request rates
     - Response times
     - Error rates
     - Dependencies

2. **Set up Alerts**
   ```powershell
   # Alert on HTTP 5xx errors
   az monitor alert create --name "Http500Alert" \
     --resource-group RegistrationApp-RG \
     --condition "avg http5xx total > 5"
   ```

3. **Create Dashboards**
   - Pin metrics to custom dashboard
   - Share with team

---

## 🔐 Security Best Practices (Already Implemented)

✅ HTTPS encryption (automatic with Azure)
✅ SQL injection prevention (using EF Core)
✅ CORS policy configured
✅ Secrets in Key Vault (not in code)
✅ Authentication ready (add Microsoft Entra ID when needed)
✅ GDPR compliant logging

---

## 💰 Cost Optimization

**Current Setup Costs:**
- Static Web App: ~$10/month (or free tier)
- App Service (B1): ~$10-15/month
- SQL Database (Basic): ~$5/month
- Application Insights: Free (5GB/month)
- **Total: ~$25-30/month** (scales based on usage)

**Tips:**
- Use free tier for dev/test
- Auto-scale during peak hours
- Monitor costs in Azure Cost Management

---

## 📚 Documentation Files

| File | Purpose |
|------|---------|
| `AZURE_DEPLOYMENT_GUIDE.md` | Detailed step-by-step guide |
| `DEPLOYMENT_CHECKLIST.md` | Checklist to track progress |
| `AZURE_DEVOPS_PIPELINE.md` | Pipeline configuration details |
| `docs/SETUP_AND_DEPLOYMENT.md` | Local setup guide |
| `README.md` | Project overview |

---

## 🚀 Next Steps

1. ✅ **Complete the 5 main steps above**

2. ✅ **Test the deployment**
   - Visit frontend URL
   - Create test items
   - Verify they persist in database

3. ✅ **Enable continuous deployment**
   - Every push to main triggers pipeline
   - Automatic tests and deployment

4. ✅ **Setup monitoring**
   - Application Insights dashboard
   - Email alerts for errors

5. ✅ **Document for your team**
   - How to deploy
   - How to troubleshoot
   - How to scale

---

## 📞 Support Resources

- **Azure Docs:** https://docs.microsoft.com/azure
- **DevOps Docs:** https://docs.microsoft.com/azure/devops
- **App Service Docs:** https://docs.microsoft.com/azure/app-service
- **Static Web Apps:** https://docs.microsoft.com/azure/static-web-apps

---

**Ready to deploy? Start with Step 1 above! 🎉**

Questions? Check `AZURE_DEPLOYMENT_GUIDE.md` for detailed instructions.
