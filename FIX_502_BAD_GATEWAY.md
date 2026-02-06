# 502 Bad Gateway - Resolution Guide

## Current Status

**Frontend**: ✅ Running at `http://registration-frontend-prod.centralindia.azurecontainer.io`  
**Backend**: ❌ **Not responding** (502 Bad Gateway error)  
**Error**: Frontend cannot reach backend API

---

## Why You're Getting 502 Bad Gateway

```
Frontend (Angular) 
    ↓
  nginx (proxy)
    ↓
  Backend (.NET Core) ❌ NOT RESPONDING
```

The **nginx** reverse proxy in the frontend container is trying to connect to the backend but getting no response.

---

## Root Cause: Backend Container Issues

The backend container (`registration-api-2807`) is likely **not running** because:

1. ❌ **SQL Firewall blocking connections** (most likely)
   - Azure Container Instances IP not whitelisted
   - SQL Server rejecting connections from the container

2. ❌ **Container crashing on startup** (second most likely)
   - Application error during initialization
   - Database connection failure

3. ❌ **Container wrong region**
   - If in `eastus`, it needs to be in `centralindia`
   - DNS resolution might fail

4. ❌ **Container not deployed yet**
   - Deployment command still running
   - Azure resources taking time to initialize

---

## Solution Checklist

### ✅ Step 1: Verify Backend Container Exists and Region

**In Azure Portal:**
1. Go to **Container Instances** in the left sidebar
2. Look for `registration-api-2807`
3. Verify:
   - **Location**: `Central India` (not eastus or other region)
   - **Status**: Showing green "Running" indicator
   - **DNS Name Label**: `registration-api-2807`

**Or use CLI:**
```powershell
az container list --resource-group rg-registration-app --query "[].{Name:name, Location:location, State:instanceView.state}" -o table
```

**Expected:**
```
Name                        Location       State
--------------------------  --------  ------
registration-frontend-prod  centralindia  Running
registration-api-2807       centralindia  Running
```

### ✅ Step 2: Check Backend Container Logs

If backend is `Waiting` or showing restart issues:

```powershell
az container logs --resource-group rg-registration-app --name registration-api-2807 --tail 50
```

**Common errors:**

**Error A: SqlException - Cannot connect**
```
System.Data.SqlClient.SqlException: Cannot open server 'regsql2807.database.windows.net' 
requested by the login. Client with IP address '20.72.189.192' is not allowed to access 
the server.
```

**Fix:** Add firewall rule (see Step 3)

**Error B: Database does not exist**
```
Microsoft.Data.SqlClient.SqlException: Cannot open database 'RegistrationAppDb'
```

**Fix:** Database schema needs to be deployed (see Step 4)

### ✅ Step 3: Fix SQL Firewall (Most Common Fix)

The SQL Server firewall is likely blocking the container IP. Fix it:

```powershell
# Remove old rule if it exists
az sql server firewall-rule delete `
  --resource-group rg-registration-app `
  --server regsql2807 `
  --name "AllowAzureServices" `
  --yes

# Wait 15 seconds
Start-Sleep -Seconds 15

# Create new rule to allow Azure services
az sql server firewall-rule create `
  --resource-group rg-registration-app `
  --server regsql2807 `
  --name "AllowAzureServices" `
  --start-ip-address "0.0.0.0" `
  --end-ip-address "0.0.0.0"

Write-Host "Firewall rule updated. Waiting 30 seconds for changes to take effect..."
Start-Sleep -Seconds 30

# Restart the backend container to reconnect
az container restart --resource-group rg-registration-app --name registration-api-2807

Write-Host "Backend container restarted. Waiting 30 seconds for startup..."
Start-Sleep -Seconds 30

# Check new status
az container show `
  --resource-group rg-registration-app `
  --name registration-api-2807 `
  --query "instanceView.state"
```

### ✅ Step 4: Deploy Database Schema (If Needed)

If logs show "database does not exist" error:

```powershell
# Connect to the SQL database from your local machine
$connectionString = "Server=tcp:regsql2807.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourSecurePassword123!@#;Encrypt=True;TrustServerCertificate=False;"

# Run Entity Framework migrations
cd c:\Users\Admin\source\repos\RegistrationApp\backend
dotnet ef database update --connection $connectionString

Write-Host "Database schema deployed successfully"
```

### ✅ Step 5: Test Backend API

Once backend is running, test it:

```powershell
# Test the API endpoint
$response = Invoke-WebRequest `
  -Uri "http://registration-api-2807.centralindia.azurecontainer.io/api/items" `
  -UseBasicParsing `
  -TimeoutSec 10

Write-Host "Status: $($response.StatusCode)"
Write-Host "Response: $($response.Content)"
```

**Expected responses:**
- `200 OK` with JSON array (empty or with items)
- Not `502` or timeout

### ✅ Step 6: Refresh Frontend

Once backend is responding:

```powershell
# Hard refresh the frontend in browser
# Or clear cache and reload
```

Then navigate to:
```
http://registration-frontend-prod.centralindia.azurecontainer.io
```

**Expected:**
- Dashboard loads
- "Items" table shows (empty or with data)
- No "Failed to load items" error

---

## Quick Command to Fix Everything

Run this all-in-one command if you just want to fix it quickly:

```powershell
# 1. Fix firewall
az sql server firewall-rule delete --resource-group rg-registration-app --server regsql2807 --name "AllowAzureServices" --yes
Start-Sleep -Seconds 15
az sql server firewall-rule create --resource-group rg-registration-app --server regsql2807 --name "AllowAzureServices" --start-ip-address "0.0.0.0" --end-ip-address "0.0.0.0"
Start-Sleep -Seconds 30

# 2. Restart containers
az container restart --resource-group rg-registration-app --name registration-api-2807
Start-Sleep -Seconds 30

# 3. Test
Write-Host "`nTesting backend API..."
try {
    $response = Invoke-WebRequest -Uri "http://registration-api-2807.centralindia.azurecontainer.io/api/items" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    Write-Host "✅ Backend is now responding! Status: $($response.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "❌ Still not responding: $($_.Exception.Message)" -ForegroundColor Red
}
```

---

## Verification Checklist

After applying fixes:

- [ ] Backend container shows `Running` status
- [ ] Backend container is in `centralindia` region
- [ ] Backend logs don't show SQL connection errors
- [ ] `curl http://registration-api-2807.centralindia.azurecontainer.io/api/items` returns JSON
- [ ] Frontend loads without "Failed to load items" error
- [ ] Items table displays (empty or with data)
- [ ] Can create new items
- [ ] Image uploads work

---

## Alternative: Redeploy Everything

If fixing doesn't work, redeploy from scratch:

```powershell
# 1. Delete containers
az container delete --resource-group rg-registration-app --name registration-api-2807 --yes
az container delete --resource-group rg-registration-app --name registration-frontend-prod --yes

# 2. Wait
Start-Sleep -Seconds 30

# 3. Get ACR credentials
$acrCreds = az acr credential show --resource-group rg-registration-app --name registrationappacr -o json | ConvertFrom-Json
$username = $acrCreds.username
$password = $acrCreds.passwords[0].value

# 4. Deploy backend
az container create `
  --resource-group rg-registration-app `
  --name registration-api-2807 `
  --image registrationappacr.azurecr.io/registration-api:latest `
  --location centralindia `
  --os-type Linux `
  --registry-login-server registrationappacr.azurecr.io `
  --registry-username $username `
  --registry-password $password `
  --cpu 1 `
  --memory 1.5 `
  --ports 80 `
  --dns-name-label registration-api-2807 `
  --environment-variables `
    ASPNETCORE_ENVIRONMENT="Production" `
    ASPNETCORE_URLS="http://+:80" `
    ConnectionStrings__DefaultConnection="Server=tcp:regsql2807.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourSecurePassword123!@#;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

# 5. Deploy frontend
az container create `
  --resource-group rg-registration-app `
  --name registration-frontend-prod `
  --image registrationappacr.azurecr.io/registration-frontend-prod:latest `
  --location centralindia `
  --os-type Linux `
  --registry-login-server registrationappacr.azurecr.io `
  --registry-username $username `
  --registry-password $password `
  --cpu 1 `
  --memory 1 `
  --ports 80 `
  --dns-name-label registration-frontend-prod `
  --environment-variables BACKEND_URL="http://registration-api-2807.centralindia.azurecontainer.io"

# 6. Wait and test
Start-Sleep -Seconds 60
Write-Host "Testing..."
Invoke-WebRequest -Uri "http://registration-frontend-prod.centralindia.azurecontainer.io" -UseBasicParsing | Select-Object StatusCode
```

---

## Contact & Support

If issues persist:
1. Check **Azure Monitor** → Container Instances → Logs
2. Review **Application Insights** for backend errors
3. Verify SQL Server firewall rules in **Azure Portal** → SQL Servers → regsql2807 → Firewall
4. Check **Container Registry** image is correct and uploaded

---

## Files for Reference

- `DEPLOYMENT_DIAGNOSTICS.md` - Full diagnostics guide
- `quick-fix.ps1` - Automated diagnostic script
- `BACKEND_DEPLOYMENT_FIX.md` - Backend-specific fixes
- `frontend/nginx.conf` - Nginx proxy configuration
- `backend/appsettings.json` - Backend configuration

