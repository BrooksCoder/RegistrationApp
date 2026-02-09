# Production Deployment Guide

## Current Status

✅ **Code Fixes Applied**
- Fixed ApplicationInsightsService dependency injection issue
- API endpoints tested and working locally
- All changes committed to develop branch

## Next Steps: Build & Deploy New Image

### Option 1: Build Locally with Docker (Recommended)

**Prerequisites:**
- Docker Desktop installed and running
- Azure CLI logged in (`az login`)

**Steps:**

```powershell
# 1. Start Docker Desktop
#    Open Docker Desktop application

# 2. Wait 2-3 minutes for Docker daemon to start
#    Then verify: docker ps

# 3. Run the full rebuild and deploy
cd c:\Users\Admin\source\repos\RegistrationApp
powershell -ExecutionPolicy Bypass -File rebuild-and-deploy.ps1
```

**What it does:**
- Builds Docker image locally
- Pushes to Azure Container Registry
- Deletes old container
- Deploys new container with fixed code

---

### Option 2: Build via Azure Pipeline (No Docker Desktop)

**If you don't have Docker Desktop:**

1. Enable ACR Tasks on your registry (requires Azure support request)
   - OR use Azure DevOps Pipelines for CI/CD

2. Once enabled, run:
```powershell
powershell -ExecutionPolicy Bypass -File acr-build-deploy.ps1
```

---

## Verification After Deployment

**Check Container Status:**
```powershell
az container show --resource-group rg-registration-app --name registration-api-prod --query "containers[0].instanceView.currentState"
```

**View Logs:**
```powershell
az container logs --resource-group rg-registration-app --name registration-api-prod
```

**Test API:**
```powershell
# Get the FQDN
$fqdn = az container show --resource-group rg-registration-app --name registration-api-prod --query "ipAddress.fqdn" -o tsv

# Test endpoint
curl "http://$fqdn/api/items"
```

---

## Expected Results

When deployment is successful:

1. **Container State:** `Running`
2. **API Response:** Returns JSON list of items
3. **No Crashes:** Container won't restart

### Troubleshooting

| Issue | Solution |
|-------|----------|
| CrashLoopBackOff | Old image is running - rebuild and push new image |
| Connection timeout | Container still starting - wait 2-3 minutes |
| Database error | Check connection string in environment variables |

---

## Database Configuration

**Current Connection String:**
```
Server=tcp:regsql2807.database.windows.net,1433;Initial Catalog=RegistrationAppDb;User ID=sqladmin;Password=YourSecurePassword123!@#
```

**To update (if needed):**
1. Edit `deploy-to-azure.ps1` or `rebuild-and-deploy.ps1`
2. Change the `$connString` variable
3. Rerun deployment

---

## Quick Commands

```powershell
# View deployment progress
Get-Terminal Output -id <terminal_id>

# Delete container and redeploy
az container delete --resource-group rg-registration-app --name registration-api-prod --yes

# Restart container (if stuck)
az container restart --resource-group rg-registration-app --name registration-api-prod
```

---

## API Endpoints

After successful deployment, test these endpoints:

```
GET  http://registration-api-prod.centralindia.azurecontainer.io/api/items
GET  http://registration-api-prod.centralindia.azurecontainer.io/api/analytics
GET  http://registration-api-prod.centralindia.azurecontainer.io/api/approvals/stats
```

---

## Important Notes

⚠️ **The new image needs to be built and pushed to ACR before deployment will work properly**

The old image (currently in Azure) has a bug that causes the container to crash. The fixed code is ready but needs to be:
1. Compiled into a Docker image
2. Pushed to Azure Container Registry
3. Container redeployed from new image

**Start Docker Desktop and run:** `rebuild-and-deploy.ps1`

