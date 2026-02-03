# Azure Deployment Checklist

Use this checklist to track your deployment progress.

## Phase 1: Prerequisites ✅

- [ ] Azure Subscription (free or paid)
- [ ] Azure DevOps Account (free at dev.azure.com)
- [ ] Azure CLI installed (`az --version`)
- [ ] Git configured with username and email
- [ ] GitHub or Azure Repos account ready

```powershell
# Verify all prerequisites
az --version
git --version
dotnet --version
node --version
npm --version
```

---

## Phase 2: Code Preparation ✅

- [ ] Git repository initialized
- [ ] All files committed locally
- [ ] Remote repository created (GitHub or Azure Repos)
- [ ] Code pushed to main branch

```powershell
cd c:\Users\Admin\source\repos\RegistrationApp
git status
git log --oneline
```

---

## Phase 3: Azure Setup ✅

- [ ] Logged into Azure CLI
  ```powershell
  az login
  az account show
  ```

- [ ] Resource Group created
  ```powershell
  az group list --output table
  ```

- [ ] Infrastructure script executed
  ```powershell
  .\scripts\setup-azure-infrastructure.ps1 `
    -ResourceGroupName "RegistrationApp-RG" `
    -Location "East US"
  ```

- [ ] Secrets stored in Key Vault
  ```powershell
  az keyvault secret list --vault-name VAULT_NAME
  ```

### Resources Created:
- [ ] Azure Container Registry (ACR)
- [ ] App Service Plan
- [ ] App Service (Backend API)
- [ ] Static Web App (Frontend)
- [ ] SQL Server & Database
- [ ] Key Vault
- [ ] Application Insights

---

## Phase 4: Azure DevOps Setup ✅

- [ ] DevOps Project created at dev.azure.com
- [ ] Repository linked to project
- [ ] Service Connection created (`RegistrationApp-Azure`)
  - Resource type: Azure Resource Manager
  - Subscription: Your subscription
  - Resource Group: RegistrationApp-RG

- [ ] Container Registry Service Connection created (`RegistrationApp-ACR`)
  - Type: Docker Registry
  - Registry: registrationappacr.azurecr.io

```powershell
# Verify service connections
# https://dev.azure.com/YOUR_ORG/RegistrationApp/_settings/adminserviceconnections
```

---

## Phase 5: CI/CD Pipeline Setup ✅

- [ ] `azure-pipelines.yml` reviewed and customized
- [ ] Pipeline variables updated:
  - `azureSubscription`: Service connection name
  - `containerRegistry`: ACR URL
  - `appServiceName`: Backend app service name
  - `staticWebAppName`: Frontend static web app name
  - `sqlServerName`: SQL server name

- [ ] Pipeline created in DevOps

```powershell
# Variables to update in azure-pipelines.yml:
# azureSubscription: 'RegistrationApp-Azure'
# containerRegistry: 'registrationappacr.azurecr.io'
# dockerRegistryServiceConnection: 'RegistrationApp-ACR'
# appServiceName: 'registrationapp-api'
# staticWebAppName: 'registrationapp-frontend'
```

---

## Phase 6: First Deployment ✅

- [ ] Pipeline triggered manually
  - Go to: https://dev.azure.com/YOUR_ORG/RegistrationApp/_build
  - Click "Run pipeline"

- [ ] Build stage completed ✅
  - Angular build: Check output
  - Backend build: Check output
  - Artifacts published

- [ ] Test stage passed ✅
  - Backend tests: All passing
  - Frontend tests: All passing

- [ ] Docker stage completed ✅
  - Backend image: Built and pushed to ACR
  - Frontend image: Built and pushed to ACR

- [ ] Deploy stage completed ✅
  - Backend: Deployed to App Service
  - Frontend: Deployed to Static Web App
  - Migrations: Applied successfully

```bash
# Monitor pipeline
# https://dev.azure.com/YOUR_ORG/RegistrationApp/_build/latest
```

---

## Phase 7: Verify Deployments ✅

### Backend API Verification:
- [ ] API endpoint accessible
  ```powershell
  curl "https://registrationapp-api.azurewebsites.net/swagger/index.html"
  curl "https://registrationapp-api.azurewebsites.net/api/items"
  ```

- [ ] Database connection working
  - Check App Service Logs
  - Verify connection string in Key Vault

- [ ] CORS configured correctly
  - Frontend can call backend

### Frontend Verification:
- [ ] Website loads without errors
  - Open: https://registrationapp-frontend.azurewebsites.net

- [ ] Can load items list
  - No "Failed to load items" error

- [ ] Can add new items
  - Create new item through UI
  - Verify in backend database

- [ ] Static assets load correctly
  - CSS, JavaScript, images all present

---

## Phase 8: Configuration & Security ✅

### Backend Configuration:
- [ ] Connection string set in App Service
  ```powershell
  az webapp config connection-string list `
    --resource-group RegistrationApp-RG `
    --name registrationapp-api
  ```

- [ ] Environment variables set
  - ASPNETCORE_ENVIRONMENT: Production
  - WEBSITES_ENABLE_APP_SERVICE_STORAGE: true

- [ ] CORS policy updated
  ```csharp
  .WithOrigins("https://registrationapp-frontend.azurewebsites.net")
  ```

### Frontend Configuration:
- [ ] API base URL updated (if using environment config)
- [ ] `staticwebapp.config.json` deployed
- [ ] Routing configured for SPA

### Security:
- [ ] SQL Admin password changed (not default)
- [ ] Firewall rules configured
  ```powershell
  az sql server firewall-rule list `
    --resource-group RegistrationApp-RG `
    --server registrationapp-sqlserver
  ```

- [ ] Key Vault secrets protected
- [ ] HTTPS enforced (automatic with Azure)
- [ ] Security headers configured in frontend

---

## Phase 9: Monitoring & Alerts ✅

- [ ] Application Insights configured
  ```powershell
  az monitor app-insights component show `
    --app registrationapp-insights `
    --resource-group RegistrationApp-RG
  ```

- [ ] Alerts created for:
  - [ ] HTTP 5xx errors > 5 in 5 minutes
  - [ ] Response time > 2 seconds
  - [ ] CPU usage > 80% for 10 minutes
  - [ ] Database connection failures

- [ ] Dashboard created for monitoring
- [ ] Log Analytics workspace configured

```powershell
# View logs in real-time
az webapp log tail `
  --resource-group RegistrationApp-RG `
  --name registrationapp-api
```

---

## Phase 10: Backup & Disaster Recovery ✅

- [ ] SQL Database backup configured
  ```powershell
  az sql db backup show `
    --resource-group RegistrationApp-RG `
    --server registrationapp-sqlserver `
    --database RegistrationAppDb
  ```

- [ ] Backup retention policy set (minimum 7 days)
- [ ] Geo-replication enabled (optional for DR)
- [ ] Disaster recovery runbook documented

---

## Phase 11: Continuous Deployment ✅

- [ ] Pipeline triggers on main branch push
- [ ] Automated tests run before deploy
- [ ] Manual approval gates configured (if needed)
- [ ] Rollback procedure tested

### Test the Pipeline:
```powershell
# 1. Make a small change
code .\backend\Controllers\ItemsController.cs

# 2. Commit and push
git add .
git commit -m "Test pipeline trigger"
git push origin main

# 3. Monitor pipeline at:
# https://dev.azure.com/YOUR_ORG/RegistrationApp/_build

# 4. Verify deployment completed
curl "https://registrationapp-api.azurewebsites.net/api/items"
```

---

## Phase 12: Documentation & Knowledge Transfer ✅

- [ ] Azure Deployment Guide completed (`AZURE_DEPLOYMENT_GUIDE.md`)
- [ ] Architecture diagram created
- [ ] Runbooks documented:
  - [ ] How to deploy
  - [ ] How to rollback
  - [ ] How to scale
  - [ ] How to troubleshoot
  - [ ] How to backup/restore

- [ ] Team trained on deployment process
- [ ] Documentation stored in shared location

---

## Final Verification Checklist ✅

- [ ] All Azure resources running and healthy
- [ ] CI/CD pipeline working automatically
- [ ] Application accessible and functional
- [ ] Database persisting data correctly
- [ ] Monitoring and alerts in place
- [ ] Security best practices implemented
- [ ] Backup and DR procedures tested
- [ ] Documentation complete
- [ ] Team trained and ready

---

## Important URLs

After deployment, you'll have these URLs:

| Component | URL | Access |
|-----------|-----|--------|
| **Backend API** | `https://registrationapp-api.azurewebsites.net` | Public |
| **Swagger Docs** | `https://registrationapp-api.azurewebsites.net/swagger/index.html` | Public |
| **Frontend** | `https://registrationapp-frontend.azurewebsites.net` | Public |
| **Azure Portal** | `https://portal.azure.com` | Your account |
| **DevOps Pipelines** | `https://dev.azure.com/YOUR_ORG/RegistrationApp/_build` | Your account |
| **Application Insights** | `https://portal.azure.com` → App Insights | Your account |
| **SQL Database** | `registrationapp-sqlserver.database.windows.net` | Secure access only |

---

## Quick Commands Reference

```powershell
# Login to Azure
az login

# View all resources
az resource list --resource-group RegistrationApp-RG --output table

# View App Service status
az webapp show --resource-group RegistrationApp-RG --name registrationapp-api

# View logs
az webapp log tail --resource-group RegistrationApp-RG --name registrationapp-api

# Restart app service
az webapp restart --resource-group RegistrationApp-RG --name registrationapp-api

# View deployment history
az webapp deployment list --resource-group RegistrationApp-RG --name registrationapp-api

# View Key Vault secrets
az keyvault secret list --vault-name registrationappkv-XXXXX

# Monitor costs
az cost management query create --timeframe TheLastMonth

# View alerts
az monitor alert list --resource-group RegistrationApp-RG
```

---

**Status: Ready for Production Deployment! 🚀**

Next step: Follow Phase 1 to Phase 12 above to complete your deployment.
