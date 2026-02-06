# Backend Container Not Responding - Final Solution

## Problem Summary

- ✅ Frontend container: **Running** and accessible
- ❌ Backend container: **Exists but not responding** to API requests
- ❌ Result: **502 Bad Gateway** when accessing `/api/items`

---

## Root Cause

The backend application inside the Docker container is **crashing immediately after startup** because:

### **Most Likely: Database Connection Failure**

The .NET Core application tries to:
1. Load configuration
2. Connect to SQL Database
3. Run EF Core migrations
4. Start Kestrel HTTP server

**It's failing at step 2 or 3**, causing the application to crash.

---

## Solution: Run EF Core Migrations

The database schema needs to be initialized before the backend container can start successfully.

### **Step 1: Deploy Database Schema from Local Machine**

Run this command on your local machine (where you have the RegistrationApp source code):

```powershell
cd c:\Users\Admin\source\repos\RegistrationApp\backend

# Run Entity Framework migrations against Azure SQL
dotnet ef database update `
  --connection "Server=tcp:regsql2807.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourSecurePassword123!@#;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

Write-Host "Database schema deployed successfully" -ForegroundColor Green
```

**What this does:**
- Connects to your Azure SQL Database
- Creates the `Items` table
- Creates the `AuditLogs` table (if using Cosmos DB)
- Creates all required indexes
- Applies any pending migrations

### **Step 2: Restart Backend Container**

Once migrations complete, restart the backend container:

```powershell
az container restart --resource-group rg-registration-app --name registration-api-2807

Write-Host "Backend container restarted" -ForegroundColor Green
Write-Host "Waiting 30 seconds for startup..." -ForegroundColor Yellow
Start-Sleep -Seconds 30
```

### **Step 3: Test Backend API**

Test if the backend is now responding:

```powershell
Write-Host "Testing backend API..." -ForegroundColor Cyan
try {
    $response = Invoke-WebRequest `
      -Uri "http://registration-api-2807.centralindia.azurecontainer.io/api/items" `
      -UseBasicParsing `
      -TimeoutSec 10 `
      -ErrorAction Stop
    
    Write-Host "✅ SUCCESS! Backend is responding!" -ForegroundColor Green
    Write-Host "Status: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "Response: $($response.Content)" -ForegroundColor Green
} catch {
    Write-Host "❌ Still not responding: $($_.Exception.Message)" -ForegroundColor Red
}
```

### **Step 4: Refresh Frontend**

Once backend is responding:

```
http://registration-frontend-prod.centralindia.azurecontainer.io
```

**Hard refresh the page:**
- Windows: `Ctrl+Shift+R`
- Mac: `Cmd+Shift+R`

---

## Complete Solution Script

Copy and paste this entire script:

```powershell
Write-Host "╔════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  RegistrationApp Backend Fix - Complete Solution  ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Step 1: Deploy database schema
Write-Host "Step 1: Deploying database schema..." -ForegroundColor Yellow
cd c:\Users\Admin\source\repos\RegistrationApp\backend

$connectionString = "Server=tcp:regsql2807.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourSecurePassword123!@#;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

Write-Host "Running Entity Framework migrations..." -ForegroundColor Cyan
dotnet ef database update --connection $connectionString

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Database schema deployed successfully" -ForegroundColor Green
} else {
    Write-Host "❌ Migration failed. Check if dotnet ef is installed:" -ForegroundColor Red
    Write-Host "   dotnet tool install --global dotnet-ef" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Step 2: Restarting backend container..." -ForegroundColor Yellow
az container restart --resource-group rg-registration-app --name registration-api-2807
Write-Host "✅ Restart command sent" -ForegroundColor Green

Write-Host ""
Write-Host "Step 3: Waiting 40 seconds for backend to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 40

Write-Host ""
Write-Host "Step 4: Testing backend API..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest `
      -Uri "http://registration-api-2807.centralindia.azurecontainer.io/api/items" `
      -UseBasicParsing `
      -TimeoutSec 10 `
      -ErrorAction Stop
    
    Write-Host "✅ SUCCESS! Backend is now responding!" -ForegroundColor Green
    Write-Host "   Status Code: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "   Items: $($response.Content)" -ForegroundColor Green
    Write-Host ""
    Write-Host "Now refresh the frontend in your browser:" -ForegroundColor Cyan
    Write-Host "http://registration-frontend-prod.centralindia.azurecontainer.io" -ForegroundColor Cyan
} catch {
    Write-Host "❌ Backend is still not responding" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Try these troubleshooting steps:" -ForegroundColor Yellow
    Write-Host "1. Check backend logs: az container logs --resource-group rg-registration-app --name registration-api-2807" -ForegroundColor Yellow
    Write-Host "2. Check SQL firewall: az sql server firewall-rule list --resource-group rg-registration-app --server regsql2807" -ForegroundColor Yellow
    Write-Host "3. Verify database exists: SELECT * FROM sys.databases WHERE name = 'RegistrationAppDb'" -ForegroundColor Yellow
}
```

---

## If EF Core Migrations Fail

If you get an error like "Entity Framework Core tools not found":

```powershell
# Install dotnet-ef globally
dotnet tool install --global dotnet-ef

# Then try migrations again
cd c:\Users\Admin\source\repos\RegistrationApp\backend
dotnet ef database update --connection "Server=tcp:regsql2807.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourSecurePassword123!@#;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
```

---

## If Backend Still Won't Start

Check the application logs by checking Docker output. The backend Dockerfile should show startup errors. Alternative approach - check the container's actual startup command:

```powershell
# See what's inside the backend container
az container show --resource-group rg-registration-app --name registration-api-2807 --query "containers[0]" -o json
```

---

## Expected Result After Fix

**Frontend Dashboard:**
```
✅ Loads without errors
✅ Shows "Items" section
✅ Empty items table (or with existing data)
✅ Can create new items
✅ Can upload images
✅ Can view details
```

**API Responses:**
```
GET /api/items → 200 OK with JSON array []
POST /api/items → 201 Created with new item
GET /api/items/{id} → 200 OK with item details
```

---

## Summary of Changes Made

1. ✅ Frontend Docker image: Built and deployed
2. ✅ Frontend container: Running in Central India
3. ✅ Backend Docker image: Built and pushed to ACR
4. ✅ Backend container: Deployed in Central India
5. ⏳ **Database schema: Need to run migrations (THIS IS THE FIX)**
6. ⏳ **Backend application: Will start after schema exists**
7. ⏳ **Full integration: Will work after both above steps**

---

## Files Updated

- `BACKEND_DEEP_DIAGNOSTICS.md` - Deep analysis of the issue
- `FIX_502_BAD_GATEWAY.md` - Step-by-step fixes
- `DEPLOYMENT_DIAGNOSTICS.md` - Full diagnostic guide
- This file - Final solution

