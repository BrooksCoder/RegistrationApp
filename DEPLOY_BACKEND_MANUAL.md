# Manual Backend Deployment Guide

## Problem
The backend container isn't responding to the frontend because it lacks database connection credentials.

## Solution
Deploy the backend container with the SQL connection string to Azure Container Instances.

---

## Step 1: Push Backend Image to Azure Container Registry

```powershell
# Authenticate with ACR
az acr login --name registrationappacr

# Push the image
docker push registrationappacr.azurecr.io/registration-api:latest
```

**Status**: ✅ Image already built locally

---

## Step 2: Deploy Backend Container to Azure

### Option A: Using Azure CLI (Recommended)

```powershell
# Set variables
$resourceGroup = "rg-registration-app"
$containerName = "registration-api-2807"
$imageName = "registrationappacr.azurecr.io/registration-api:latest"

# Delete old container
az container delete --resource-group $resourceGroup --name $containerName --yes

# Create new container with SQL connection string
az container create `
  --resource-group $resourceGroup `
  --name $containerName `
  --image $imageName `
  --cpu 1 `
  --memory 1.5 `
  --environment-variables `
    ASPNETCORE_ENVIRONMENT="Production" `
    ASPNETCORE_URLS="http://+:80" `
    ConnectionStrings__DefaultConnection="Server=tcp:regsql2807.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourSecurePassword123!@#;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;" `
  --ports 80 `
  --restart-policy OnFailure `
  --dns-name-label registration-api-2807
```

### Option B: Using Azure Portal

1. Go to **Azure Portal** → **Container Instances**
2. Click **Create container instance**
3. Fill in:
   - **Resource group**: `rg-registration-app`
   - **Container name**: `registration-api-2807`
   - **Image source**: `registrationappacr.azurecr.io/registration-api:latest`
   - **CPU**: `1`
   - **Memory**: `1.5`
   - **Port**: `80`
   - **DNS name label**: `registration-api-2807`
4. Go to **Environment variables** tab
5. Add environment variables:
   ```
   Name: ASPNETCORE_ENVIRONMENT
   Value: Production

   Name: ASPNETCORE_URLS
   Value: http://+:80

   Name: ConnectionStrings__DefaultConnection
   Value: Server=tcp:regsql2807.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourSecurePassword123!@#;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;
   ```
6. Click **Create**

---

## Step 3: Verify Backend is Running

```powershell
# Check container status
az container show --resource-group rg-registration-app --name registration-api-2807 --query "instanceView.state"

# Test API endpoint
curl http://registration-api-2807.centralindia.azurecontainer.io/api/items
```

---

## Step 4: Update Frontend (if needed)

The frontend is already configured to use:
```
BACKEND_URL=http://registration-api-2807.centralindia.azurecontainer.io
```

So no changes needed!

---

## Troubleshooting

### Backend container not starting?
- Check logs: `az container logs --resource-group rg-registration-app --name registration-api-2807 --tail 50`
- Verify connection string is correct
- Check SQL firewall allows Azure services

### Frontend still showing "Failed to load items"?
1. Open browser console (F12)
2. Check Network tab for API calls
3. Verify CORS is enabled in backend
4. Check if backend is responding to requests

---

## Connection String Breakdown

```
Server=tcp:regsql2807.database.windows.net,1433;
  → Azure SQL Server endpoint

Initial Catalog=RegistrationAppDb;
  → Database name

User ID=sqladmin;
Password=YourSecurePassword123!@#;
  → Credentials

Encrypt=True;
TrustServerCertificate=False;
  → Secure connection required
```

---

## Next Steps

Once backend is deployed:
1. ✅ Frontend will automatically connect
2. ✅ Items will load from the database
3. ✅ Image uploads will work
4. ✅ Audit logs will be recorded

**Expected URL**: `http://registration-api-2807.centralindia.azurecontainer.io`
