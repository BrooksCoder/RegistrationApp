# Diagnostic Script for RegistrationApp Deployment

## Current Situation

You're getting a **502 Bad Gateway** error when accessing:
```
http://registration-frontend-prod.centralindia.azurecontainer.io/api/items
```

This means the **frontend is running** but the **backend is not responding**.

---

## Step 1: Verify Backend Container Status (Run this in Azure Portal or Azure CLI)

### Option A: Using Azure Portal
1. Go to **portal.azure.com**
2. Search for **Container Instances**
3. Find `registration-api-2807`
4. Check:
   - Status: Should be **Running**
   - Location: Should be **Central India** (centralindia)
   - Restart count: Should be **0** or **1** (not many restarts)

### Option B: Using Azure CLI
```powershell
az container show --resource-group rg-registration-app --name registration-api-2807 --query "{State:instanceView.state, Location:location, RestartCount:instanceView.restartCount, FQDN:ipAddress.fqdn}"
```

**Expected Output:**
```
State         Location      RestartCount    FQDN
Running       centralindia  0-1             registration-api-2807.centralindia.azurecontainer.io
```

---

## Step 2: Check Backend Container Logs

If the container is **Waiting** or **CrashLoopBackOff**, check the logs:

```powershell
az container logs --resource-group rg-registration-app --name registration-api-2807 --tail 50
```

**If you see database connection errors:**
```
SqlException: Cannot connect to server
```

Then run:
```powershell
# Recreate the firewall rule
az sql server firewall-rule delete --resource-group rg-registration-app --server regsql2807 --name AllowAzureServices --yes

# Wait 15 seconds
Start-Sleep -Seconds 15

# Recreate it
az sql server firewall-rule create `
  --resource-group rg-registration-app `
  --server regsql2807 `
  --name "AllowAzureServices" `
  --start-ip-address "0.0.0.0" `
  --end-ip-address "0.0.0.0"

# Wait 30 seconds for it to take effect
Start-Sleep -Seconds 30

# Restart the backend container
az container restart --resource-group rg-registration-app --name registration-api-2807
```

---

## Step 3: Test Backend API Directly

Once backend is **Running**, test it directly:

```powershell
# Test API endpoint
$response = Invoke-WebRequest -Uri "http://registration-api-2807.centralindia.azurecontainer.io/api/items" -UseBasicParsing
Write-Host "Backend Status: $($response.StatusCode)"
Write-Host "Response: $($response.Content)"
```

**Expected Response:**
```json
[]
or
[
  { "id": 1, "name": "Item 1", "status": "Active", ... },
  { "id": 2, "name": "Item 2", "status": "Pending", ... }
]
```

---

## Step 4: Verify Frontend Configuration

The frontend should be configured to use the correct backend URL. Check:

```powershell
# Check frontend environment variables
az container show --resource-group rg-registration-app --name registration-frontend-prod --query "containers[0].environmentVariables" -o json
```

**Should include:**
```json
{
  "name": "BACKEND_URL",
  "value": "http://registration-api-2807.centralindia.azurecontainer.io"
}
```

If it's wrong, delete and recreate the frontend:

```powershell
# Get ACR credentials
$acrCreds = az acr credential show --resource-group rg-registration-app --name registrationappacr -o json | ConvertFrom-Json

# Delete old frontend
az container delete --resource-group rg-registration-app --name registration-frontend-prod --yes

# Wait 10 seconds
Start-Sleep -Seconds 10

# Recreate with correct backend URL
az container create `
  --resource-group rg-registration-app `
  --name registration-frontend-prod `
  --image registrationappacr.azurecr.io/registration-frontend-prod:latest `
  --location centralindia `
  --os-type Linux `
  --registry-login-server registrationappacr.azurecr.io `
  --registry-username $acrCreds.username `
  --registry-password $acrCreds.passwords[0].value `
  --cpu 1 `
  --memory 1 `
  --ports 80 `
  --dns-name-label registration-frontend-prod `
  --environment-variables BACKEND_URL="http://registration-api-2807.centralindia.azurecontainer.io"
```

---

## Step 5: Full Troubleshooting Flow

Run this complete script to diagnose all issues:

```powershell
Write-Host "RegistrationApp Deployment Diagnostics" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# 1. Check backend container
Write-Host "1. Backend Container Status:" -ForegroundColor Yellow
$backend = az container show --resource-group rg-registration-app --name registration-api-2807 --query "{State:instanceView.state, Location:location, IP:ipAddress.ip}" -o json | ConvertFrom-Json
Write-Host "   State: $($backend.State)" -ForegroundColor Cyan
Write-Host "   Location: $($backend.Location)" -ForegroundColor Cyan
Write-Host "   IP: $($backend.IP)" -ForegroundColor Cyan
Write-Host ""

# 2. Check frontend container
Write-Host "2. Frontend Container Status:" -ForegroundColor Yellow
$frontend = az container show --resource-group rg-registration-app --name registration-frontend-prod --query "{State:instanceView.state, Location:location, IP:ipAddress.ip}" -o json | ConvertFrom-Json
Write-Host "   State: $($frontend.State)" -ForegroundColor Cyan
Write-Host "   Location: $($frontend.Location)" -ForegroundColor Cyan
Write-Host "   IP: $($frontend.IP)" -ForegroundColor Cyan
Write-Host ""

# 3. Test backend API
Write-Host "3. Backend API Test:" -ForegroundColor Yellow
try {
    $apiResponse = Invoke-WebRequest -Uri "http://registration-api-2807.centralindia.azurecontainer.io/api/items" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    Write-Host "   ✅ Status: $($apiResponse.StatusCode)" -ForegroundColor Green
    Write-Host "   Content length: $($apiResponse.Content.Length)" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# 4. Test frontend
Write-Host "4. Frontend Test:" -ForegroundColor Yellow
try {
    $frontendResponse = Invoke-WebRequest -Uri "http://registration-frontend-prod.centralindia.azurecontainer.io" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    Write-Host "   ✅ Status: $($frontendResponse.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

Write-Host "Diagnostics Complete" -ForegroundColor Green
```

---

## Summary of What Should Be Running

| Component | Name | Region | Status | URL |
|-----------|------|--------|--------|-----|
| Frontend | registration-frontend-prod | centralindia | Running | http://registration-frontend-prod.centralindia.azurecontainer.io |
| Backend | registration-api-2807 | centralindia | Running | http://registration-api-2807.centralindia.azurecontainer.io/api/items |
| SQL Server | regsql2807 | N/A | Running | regsql2807.database.windows.net |
| SQL Database | RegistrationAppDb | N/A | Ready | - |

---

## Common Issues & Fixes

### Issue: "502 Bad Gateway" persists
**Cause**: Backend not responding
**Fix**: 
1. Check backend logs: `az container logs --resource-group rg-registration-app --name registration-api-2807`
2. If database connection error, recreate SQL firewall rule
3. Restart backend: `az container restart --resource-group rg-registration-app --name registration-api-2807`

### Issue: Backend shows "CrashLoopBackOff"
**Cause**: Application crash on startup
**Fix**:
1. Check logs for specific error
2. Common causes:
   - SQL connection string wrong
   - SQL firewall blocking connections
   - Database doesn't exist
   - Missing EF migrations

### Issue: Backend shows "Waiting" for a long time
**Cause**: Trying to start but failing repeatedly
**Fix**:
1. Check logs
2. Wait longer (sometimes takes 2-3 minutes to start)
3. If still waiting after 5 minutes, restart: `az container restart --resource-group rg-registration-app --name registration-api-2807`

---

## Next Steps

1. **Verify backend is running** (Step 1 above)
2. **If not running, check logs** (Step 2 above)
3. **Apply fixes as needed** (Step 5 above)
4. **Test API** (Step 3 above)
5. **Refresh frontend** and verify items load

Once all containers are running and responding:
- ✅ Frontend should load without errors
- ✅ Items should display on dashboard
- ✅ Image uploads should work
- ✅ Audit logs should record changes

