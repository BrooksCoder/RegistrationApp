# Backend Deployment Status & Next Steps

## 🔴 Current Issue

The backend container is crashing with **Exit Code 134** when it tries to connect to the Azure SQL database.

### Root Cause Analysis

**Exit Code 134 = Application Crash** (typically due to):
1. ✅ Connection string syntax is correct
2. ✅ SQL credentials verified (sqladmin / YourSecurePassword123!@#)
3. ❌ **SQL Firewall Rule Missing** - The SQL server may not allow connections from Azure Container Instances
4. ❌ **Database Not Initialized** - The database might not exist or hasn't been migrated yet

---

## ✅ What Was Successfully Deployed

### Frontend Container
- **Name**: `registration-frontend-prod`
- **Location**: `centralindia`
- **Status**: ✅ Running and accessible
- **URL**: `http://registration-frontend-prod.centralindia.azurecontainer.io`
- **Environment**: `BACKEND_URL=http://registration-api-2807.centralindia.azurecontainer.io`

### Backend Container (Partially)
- **Name**: `registration-api-2807`
- **Location**: `eastus` (created but wrong region)
- **Image**: `registrationappacr.azurecr.io/registration-api:latest`
- **Status**: ❌ CrashLoopBackOff (Exit Code 134)
- **Credentials Passed**: ✅ SQL connection string with sqladmin credentials

---

## 🔧 What Needs to Be Fixed

### Option 1: Fix SQL Firewall (Recommended)

Add Azure Services firewall rule to allow Container Instances to connect:

```powershell
az sql server firewall-rule create `
  --resource-group rg-registration-app `
  --server regsql2807 `
  --name "AllowAzureServices" `
  --start-ip-address "0.0.0.0" `
  --end-ip-address "0.0.0.0"
```

### Option 2: Initialize the Database

Ensure the database exists and has been migrated with the latest schema:

```powershell
# Run migrations from your local machine
cd "c:\Users\Admin\source\repos\RegistrationApp\backend"
dotnet ef database update --connection "Server=tcp:regsql2807.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourSecurePassword123!@#;Encrypt=True;"
```

### Option 3: Check Database Connectivity Directly

```powershell
# Test if you can connect to the SQL database
$connectionString = "Server=tcp:regsql2807.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourSecurePassword123!@#;Encrypt=True;"
sqlcmd -S "regsql2807.database.windows.net" -U "sqladmin" -P "YourSecurePassword123!@#" -d "RegistrationAppDb" -Q "SELECT * FROM INFORMATION_SCHEMA.TABLES"
```

---

## 📋 Complete Deployment Checklist

### Prerequisites
- [x] SQL Server created: `regsql2807`
- [x] SQL Database created: `RegistrationAppDb`
- [x] SQL Admin Username: `sqladmin`
- [x] SQL Admin Password: `YourSecurePassword123!@#`
- [x] Backend image built and in ACR
- [x] Frontend container deployed and running

### Remaining Tasks
- [ ] **Add SQL firewall rule** for Azure Services
- [ ] **Initialize database** with EF migrations
- [ ] **Redeploy backend** in centralindia region (to match frontend)
- [ ] **Test API connectivity** from frontend
- [ ] **Verify data flows** end-to-end

---

## 🚀 Quick Fix Commands

Run these commands to fix the deployment:

```powershell
# 1. Add firewall rule to allow Azure Services
az sql server firewall-rule create `
  --resource-group rg-registration-app `
  --server regsql2807 `
  --name "AllowAzureServices" `
  --start-ip-address "0.0.0.0" `
  --end-ip-address "0.0.0.0"

# 2. Wait 30 seconds
Start-Sleep -Seconds 30

# 3. Delete old backend container
az container delete --resource-group rg-registration-app --name registration-api-2807 --yes

# 4. Wait 10 seconds
Start-Sleep -Seconds 10

# 5. Recreate in Central India
$username = "registrationappacr"
$password = (az acr credential show --resource-group rg-registration-app --name registrationappacr -o json | ConvertFrom-Json).passwords[0].value

az container create `
  --resource-group rg-registration-app `
  --name registration-api-2807 `
  --image registrationappacr.azurecr.io/registration-api:latest `
  --location centralindia `
  --os-type Linux `
  --registry-username $username `
  --registry-password $password `
  --cpu 1 `
  --memory 1.5 `
  --ports 80 `
  --restart-policy OnFailure `
  --dns-name-label registration-api-2807 `
  --environment-variables `
    ASPNETCORE_ENVIRONMENT="Production" `
    ASPNETCORE_URLS="http://+:80" `
    ConnectionStrings__DefaultConnection="Server=tcp:regsql2807.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourSecurePassword123!@#;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

# 6. Wait 30 seconds and check status
Start-Sleep -Seconds 30
az container show --resource-group rg-registration-app --name registration-api-2807 --query "instanceView.state"
```

---

## 📊 Expected Final State

Once fixed:

```
Frontend: http://registration-frontend-prod.centralindia.azurecontainer.io
Backend:  http://registration-api-2807.centralindia.azurecontainer.io/api/items

Both in centralindia region
Both accessible and responding
Frontend can fetch items from backend
Database has items table with Status, ImageUrl, UpdatedAt columns
```

---

## 🆘 Troubleshooting

### If backend still doesn't start:
1. Check logs: `az container logs --resource-group rg-registration-app --name registration-api-2807 --tail 50`
2. Verify SQL connection: `sqlcmd -S regsql2807.database.windows.net -U sqladmin -P "YourSecurePassword123!@#" -d RegistrationAppDb -Q "SELECT 1"`
3. Check database exists: Query `SELECT * FROM sys.databases WHERE name = 'RegistrationAppDb'`

### If frontend can't reach backend:
1. Check backend is running: `curl http://registration-api-2807.centralindia.azurecontainer.io/api/items`
2. Check frontend logs in browser console (F12)
3. Verify BACKEND_URL environment variable is correct
4. Check nginx proxy configuration

---

## 💾 Connection String for Reference

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

