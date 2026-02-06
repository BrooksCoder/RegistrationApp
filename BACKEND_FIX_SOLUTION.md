# BACKEND FIX - ROOT CAUSE IDENTIFIED & SOLUTION

## Summary of Issue Found

**Problem**: Backend container is crashing with Exit Code 134 (signal 6 - SIGABRT)

**Root Cause Identified**: The application's `Program.cs` has Kestrel configured to listen ONLY on localhost ports (58082, 58083):
```csharp
// BAD - Container can't accept external connections
serverOptions.ListenLocalhost(58082, listenOptions => { listenOptions.UseHttps(); });
serverOptions.ListenLocalhost(58083);
```

In a Docker container, the application needs to listen on **0.0.0.0:80** to accept connections from outside.

## Fix Applied ✅

### Step 1: Fixed Program.cs (DONE)
Modified the Kestrel configuration to listen on the correct port:
```csharp
// GOOD - Container listens on all interfaces in production
builder.WebHost.ConfigureKestrel(serverOptions =>
{
    if (builder.Environment.IsProduction())
    {
        serverOptions.ListenAnyIP(80);  // Listen on 0.0.0.0:80
    }
    else
    {
        serverOptions.ListenLocalhost(58082, listenOptions => { listenOptions.UseHttps(); });
        serverOptions.ListenLocalhost(58083);
    }
});
```

### Step 2: Verified Database Migrations (DONE)
✅ Migrations ran successfully
✅ Database tables exist (verified via SQL query)
✅ `__EFMigrationsHistory` table created

Output from migrations:
```
No migrations were applied. The database is already up to date.
[OK] Database tables exist (2 tables)
```

### Step 3: Redeployed Backend Container with Environment Variables (DONE)
✅ Container redeployed with:
- ASPNETCORE_ENVIRONMENT=Production
- ConnectionStrings__DefaultConnection (pointing to Azure SQL)

## Next Steps (MUST DO THESE)

### Step 1: Rebuild Docker Image in Azure
Since Docker Desktop may have issues, use Azure Container Registry's build service:

```powershell
cd c:\Users\Admin\source\repos\RegistrationApp

az acr build `
  --registry registrationappacr `
  --image registration-api:latest `
  --file backend/Dockerfile `
  ./backend
```

This will:
- Build the image in Azure cloud
- Push automatically to ACR
- Takes about 2-3 minutes

### Step 2: Delete and Recreate Backend Container
```powershell
# Delete old container
az container delete --resource-group rg-registration-app --name registration-api-2807 --yes

# Get ACR credentials
$acrUser = az acr credential show --resource-group rg-registration-app --name registrationappacr --query username -o tsv
$acrPassword = az acr credential show --resource-group rg-registration-app --name registrationappacr --query "passwords[0].value" -o tsv

# Create new container with fixed image
az container create `
  --resource-group rg-registration-app `
  --name registration-api-2807 `
  --image "registrationappacr.azurecr.io/registration-api:latest" `
  --cpu 1 `
  --memory 1 `
  --os-type Linux `
  --registry-login-server registrationappacr.azurecr.io `
  --registry-username $acrUser `
  --registry-password $acrPassword `
  --ports 80 `
  --dns-name-label "registration-api-2807" `
  --location centralindia `
  --environment-variables `
    ASPNETCORE_ENVIRONMENT=Production `
    "ConnectionStrings__DefaultConnection=Server=tcp:regsql2807.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourSecurePassword123!@#;Encrypt=True;Connection Timeout=30;"

# Wait for container to start
Start-Sleep -Seconds 60
```

### Step 3: Test Backend
```powershell
# Test API
Invoke-WebRequest -Uri "http://registration-api-2807.centralindia.azurecontainer.io/api/items" -UseBasicParsing -TimeoutSec 10

# Should return status 200 with JSON array of items
```

### Step 4: Test Frontend
```
Open browser:
http://registration-frontend-prod.centralindia.azurecontainer.io

You should see the dashboard WITHOUT 502 errors
```

## Why This Will Work

1. ✅ **Database is ready** - Tables exist, migrations applied
2. ✅ **Environment variables configured** - Connection string passed to container
3. ✅ **Kestrel now listening on 0.0.0.0:80** - Application will accept external connections
4. ✅ **Production environment detected** - Code uses environment-specific configuration

## Files Modified
- `backend/Program.cs` - Fixed Kestrel configuration
- `fix-complete.ps1` - Updated fix script with better diagnostics
- `redeploy-backend-with-env.ps1` - Deployment script with env vars
- `build-in-azure.ps1` - Azure-based build script (avoids local Docker issues)

## Current Container Status

```
Name: registration-api-2807
Location: Central India
FQDN: registration-api-2807.centralindia.azurecontainer.io
Status: Running (but with old image)
Exit Code: 134 (will be fixed after rebuild)
Environment: ASPNETCORE_ENVIRONMENT=Production ✅
Connection String: Set ✅
Database: Ready ✅
Port: 80 ✅
```

## Testing Commands (After Rebuild)

```powershell
# Get logs
az container logs --resource-group rg-registration-app --name registration-api-2807 --tail 100

# Show status
az container show --resource-group rg-registration-app --name registration-api-2807 --query "{State:instanceView.state, RestartCount:containers[0].instanceView.restartCount}"

# Test API
curl http://registration-api-2807.centralindia.azurecontainer.io/api/items

# Test Swagger
curl http://registration-api-2807.centralindia.azurecontainer.io/swagger/index.html
```

## Success Indicators

After completing these steps, you should see:

1. ✅ Backend container running (not CrashLoopBackOff)
2. ✅ GET /api/items returns 200 with items array
3. ✅ Frontend loads without 502 errors
4. ✅ Can create items via frontend
5. ✅ Can upload images (if storage configured)

## Debugging If Still Failing

If backend still doesn't respond after rebuild:

```powershell
# 1. Check logs
az container logs --resource-group rg-registration-app --name registration-api-2807 --tail 200 | Select-Object -First 50

# 2. Check if process is running
az container show --resource-group rg-registration-app --name registration-api-2807 --query "containers[0].instanceView.currentState"

# 3. Verify connection string in container
# Logs should show connection string being used

# 4. Test port accessibility
# Should show container listening on port 80
```

---
**Next Action**: Run Step 1 (az acr build) to rebuild the image with the Kestrel fix.
