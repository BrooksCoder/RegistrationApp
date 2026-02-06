# Backend 502 Bad Gateway - Deep Dive Analysis

## Current Situation

**Status**: Backend container (`registration-api-2807`) is **NOT responding** to API requests  
**Error**: 502 Bad Gateway from frontend proxy  
**Attempted Fixes**: SQL firewall rule recreation, container restart  
**Result**: Still failing

---

## Likely Root Causes (In Order of Probability)

### **1. Backend Container Not Running (Most Likely)**

The container may be in a `CrashLoopBackOff` state, meaning:
- It starts
- Application crashes immediately  
- Docker restarts it
- It crashes again (loop)

**Why this happens:**
```
Application Startup → Load Configuration → 
  Connect to SQL Database → SQL Connection Fails → 
  Application Crashes with Exit Code 134
```

**Symptoms:**
- Container exists but shows `Waiting` state
- Restart count > 5
- No successful startup logs
- Database connection timeout

---

### **2. SQL Database Connection String Wrong**

The connection string passed to the container might have issues:

```
✅ CORRECT:
Server=tcp:regsql2807.database.windows.net,1433;
Initial Catalog=RegistrationAppDb;
User ID=sqladmin;
Password=YourSecurePassword123!@#;
Encrypt=True;

❌ WRONG (Missing Encrypt=True or wrong host)
```

**Check:** Review the exact connection string in the deployment command

---

### **3. SQL Database Not Initialized**

The database `RegistrationAppDb` might exist but has no schema/tables.

**Solution:**
```powershell
# Run migrations from local machine
cd c:\Users\Admin\source\repos\RegistrationApp\backend
dotnet ef database update --connection "Server=tcp:regsql2807.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourSecurePassword123!@#;Encrypt=True;"
```

---

### **4. Container Deployed in Wrong Region**

If the backend was deployed in `eastus` but frontend in `centralindia`, DNS resolution might fail.

**Check:** Backend FQDN should be:
```
registration-api-2807.centralindia.azurecontainer.io
(NOT registration-api-2807.eastus.azurecontainer.io)
```

---

### **5. Azure CLI or Deployment Command Syntax Error**

The container might not have been created properly if the deployment command had errors.

---

## Investigation Steps (Do These Manually)

### Step 1: Check Azure Portal Directly

1. Go to **https://portal.azure.com**
2. Search for **"Container Instances"**
3. Find **`registration-api-2807`**
4. Look at:
   - **Status icon**: Green (Running) or Red (Failed)?
   - **Location**: `Central India`?
   - **Restart count**: How many restarts?
   - **Logs**: Click "Logs" → See any error messages?

### Step 2: Check SQL Server Firewall

1. Go to **SQL servers** in Portal
2. Click **`regsql2807`**
3. Go to **Networking** (left sidebar)
4. Under **Firewall rules**, verify:
   - Rule name: `AllowAzureServices`
   - Start IP: `0.0.0.0`
   - End IP: `0.0.0.0`

If missing or wrong:
```powershell
# Delete old rule
az sql server firewall-rule delete `
  --resource-group rg-registration-app `
  --server regsql2807 `
  --name "AllowAzureServices" `
  --yes

# Create new rule
az sql server firewall-rule create `
  --resource-group rg-registration-app `
  --server regsql2807 `
  --name "AllowAzureServices" `
  --start-ip-address "0.0.0.0" `
  --end-ip-address "0.0.0.0"
```

### Step 3: Check Container Logs in Portal

1. Open the container **`registration-api-2807`**
2. Click **"Logs"** in left sidebar
3. Look for:
   - **Startup messages**: "Application started successfully"?
   - **Error messages**: Database connection errors?
   - **Application crashes**: Exit codes or stack traces?

### Step 4: Delete and Redeploy Backend

If all else fails, completely redeploy:

```powershell
Write-Host "Step 1: Get ACR credentials" -ForegroundColor Cyan
$acrCreds = az acr credential show --resource-group rg-registration-app --name registrationappacr -o json | ConvertFrom-Json

Write-Host "Step 2: Delete old backend" -ForegroundColor Cyan
az container delete --resource-group rg-registration-app --name registration-api-2807 --yes

Write-Host "Step 3: Wait 20 seconds" -ForegroundColor Cyan
Start-Sleep -Seconds 20

Write-Host "Step 4: Deploy new backend in Central India" -ForegroundColor Cyan
az container create `
  --resource-group rg-registration-app `
  --name registration-api-2807 `
  --image registrationappacr.azurecr.io/registration-api:latest `
  --location centralindia `
  --os-type Linux `
  --registry-login-server registrationappacr.azurecr.io `
  --registry-username $acrCreds.username `
  --registry-password $acrCreds.passwords[0].value `
  --cpu 1 `
  --memory 1.5 `
  --ports 80 `
  --restart-policy OnFailure `
  --dns-name-label registration-api-2807 `
  --environment-variables `
    ASPNETCORE_ENVIRONMENT="Production" `
    ASPNETCORE_URLS="http://+:80" `
    ConnectionStrings__DefaultConnection="Server=tcp:regsql2807.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourSecurePassword123!@#;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

Write-Host "Step 5: Wait 40 seconds for container to start" -ForegroundColor Cyan
Start-Sleep -Seconds 40

Write-Host "Step 6: Test backend" -ForegroundColor Cyan
try {
    $response = Invoke-WebRequest -Uri "http://registration-api-2807.centralindia.azurecontainer.io/api/items" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    Write-Host "✅ SUCCESS! Backend is responding with status $($response.StatusCode)" -ForegroundColor Green
    Write-Host "Response: $($response.Content)" -ForegroundColor Green
} catch {
    Write-Host "❌ Still not responding" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}
```

---

## Connection String Reference

**Current Connection String:**
```
Server=tcp:regsql2807.database.windows.net,1433;
Initial Catalog=RegistrationAppDb;
Persist Security Info=False;
User ID=sqladmin;
Password=YourSecurePassword123!@#;
MultipleActiveResultSets=False;
Encrypt=True;
TrustServerCertificate=False;
Connection Timeout=30;
```

**Components:**
- `regsql2807.database.windows.net:1433` = SQL Server address (Azure)
- `RegistrationAppDb` = Database name
- `sqladmin` = Admin username
- `YourSecurePassword123!@#` = Admin password
- `Encrypt=True` = Use TLS/SSL

**If any part is wrong, connection will fail and app will crash.**

---

## Expected Container Behavior Timeline

### ✅ Correct Startup (What Should Happen)

```
00:00 - Container starts
00:05 - Image downloaded
00:10 - Application begins startup
00:15 - Connection to SQL Server established
00:20 - Database schema verified
00:25 - Application fully started
00:30 - Ready to accept requests
Status: Running ✅
```

### ❌ Wrong Startup (What's Probably Happening)

```
00:00 - Container starts
00:05 - Image downloaded
00:10 - Application begins startup
00:15 - Tries to connect to SQL Server...
00:20 - Connection timeout! SQL unreachable
00:25 - Application crash (Exit Code 134)
00:30 - Docker restarts container
00:35 - Tries again... fails again
00:40 - Gives up after N retries
Status: CrashLoopBackOff ❌
Restart Count: 5+
```

---

## Next Actions

**Recommendation**: Check the Azure Portal container logs first. That will tell you exactly what's wrong.

**If logs show:**
- `Cannot connect to SQL Server` → Firewall issue
- `Database does not exist` → Run EF migrations
- `Application startup error` → Check configuration
- `No logs` → Container not starting

---

## Files with More Info

- `FIX_502_BAD_GATEWAY.md` - Step-by-step fixes
- `DEPLOYMENT_DIAGNOSTICS.md` - Full diagnostic guide
- `frontend/nginx.conf` - Frontend proxy config
- `backend/appsettings.json` - Backend configuration

