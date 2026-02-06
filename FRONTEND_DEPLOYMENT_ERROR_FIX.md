# Frontend Deployment Error - "Failed to load items"

## Problem Analysis

❌ **Error:** "Failed to load items. Please try again later"  
🔗 **URL:** `http://registration-frontend-prod.centralindia.azurecontainer.io/`

### Root Cause

The frontend container is missing the `BACKEND_URL` environment variable, so it defaults to `http://localhost:5000`, which doesn't exist in production.

**Flow:**
```
Frontend Container
  ↓
Nginx looks for API at http://localhost:5000
  ↓
❌ Connection refused (backend not on localhost)
  ↓
Frontend shows "Failed to load items"
```

---

## Solution

You need to set the `BACKEND_URL` environment variable when deploying the frontend container.

### Option 1: Azure CLI (Recommended)

```powershell
# Get your backend URL first
# Format: https://registration-api-prod.centralindia.azurecontainer.io or your backend service URL

$BACKEND_URL = "https://registration-api-prod.centralindia.azurecontainer.io"  # Change this!

az container create `
  --resource-group <YOUR_RESOURCE_GROUP> `
  --name registration-frontend-prod `
  --image <YOUR_ACR>.azurecr.io/registration-frontend:latest `
  --cpu 1 --memory 1 `
  --ports 80 `
  --environment-variables BACKEND_URL=$BACKEND_URL `
  --registry-login-server <YOUR_ACR>.azurecr.io `
  --registry-username <YOUR_ACR_USERNAME> `
  --registry-password <YOUR_ACR_PASSWORD>
```

### Option 2: Azure Portal

1. Go to **Container Instances** → **registration-frontend-prod**
2. Click **Stop**
3. Edit the container and add environment variable:
   - **Name:** `BACKEND_URL`
   - **Value:** `https://registration-api-prod.centralindia.azurecontainer.io`
4. Click **Update**

### Option 3: Docker Compose (For local testing)

```yaml
registration-frontend:
  build:
    context: ./frontend
    dockerfile: Dockerfile
  environment:
    BACKEND_URL: "http://registration-api:80"  # ← Add this
  ports:
    - "80:80"
  depends_on:
    - registration-api
```

### Option 4: Docker Run Command

```powershell
docker run -e BACKEND_URL="https://your-backend-url.azurecontainer.io" `
           -p 80:80 `
           registration-frontend:latest
```

---

## What is BACKEND_URL?

This should be the **URL of your backend API** running in production.

**Examples:**
- `https://registration-api-prod.centralindia.azurecontainer.io` (Azure Container Instance)
- `https://registration-api.azurewebsites.net` (App Service)
- `https://api.yourdomain.com` (Custom domain)

---

## How It Works

1. **Container starts** → `docker-entrypoint.sh` runs
2. **Checks BACKEND_URL env var**
3. **Replaces `${BACKEND_URL}` in nginx.conf** with your value
4. **Nginx proxies API requests** to the backend URL
5. **Frontend calls** `/api/items` → Nginx forwards to `${BACKEND_URL}/api/items`

---

## Testing the Fix

### Step 1: Verify Environment Variable is Set

```powershell
# In your container, check:
echo $BACKEND_URL

# Should output: https://registration-api-prod.centralindia.azurecontainer.io
```

### Step 2: Check Nginx Config

```powershell
# Inside container:
cat /etc/nginx/conf.d/default.conf | grep proxy_pass

# Should show:
# proxy_pass https://registration-api-prod.centralindia.azurecontainer.io/api/;
```

### Step 3: Test Frontend

```
1. Open: http://registration-frontend-prod.centralindia.azurecontainer.io/
2. Check browser console (F12)
3. Should see successful API calls to backend
4. Items should load ✅
```

---

## Verification Checklist

After updating the environment variable:

- [ ] Frontend container restarted
- [ ] BACKEND_URL environment variable is set
- [ ] Backend service is running and accessible
- [ ] Nginx config contains correct proxy_pass URL
- [ ] Browser console shows no 404 errors for API calls
- [ ] Items load successfully on page

---

## Quick Fix Command

If your backend is at `registration-api-prod.centralindia.azurecontainer.io`:

```powershell
# PowerShell
az container create `
  --resource-group YourResourceGroup `
  --name registration-frontend-prod `
  --image registrationapp.azurecr.io/registration-frontend:latest `
  --cpu 1 --memory 1 `
  --ports 80 `
  --environment-variables BACKEND_URL="https://registration-api-prod.centralindia.azurecontainer.io" `
  --registry-login-server registrationapp.azurecr.io `
  --registry-username <USERNAME> `
  --registry-password <PASSWORD>
```

---

## Common Mistakes

❌ **Wrong:** Not setting BACKEND_URL at all  
✅ **Right:** `BACKEND_URL=https://backend-api.azurecontainer.io`

❌ **Wrong:** Using `http://localhost:5000`  
✅ **Right:** Using the actual production backend URL

❌ **Wrong:** Using old/wrong backend URL  
✅ **Right:** Matching the exact URL of your backend service

❌ **Wrong:** Forgetting `https://` protocol  
✅ **Right:** Including the full protocol

---

## File Locations

| File | Purpose |
|------|---------|
| `frontend/docker-entrypoint.sh` | Sets BACKEND_URL in Nginx config |
| `frontend/nginx.conf` | Uses `${BACKEND_URL}` for API proxy |
| `frontend/Dockerfile` | Builds container and copies files |

---

## Additional Notes

- The `docker-entrypoint.sh` script uses `envsubst` to replace variables
- Nginx proxies all `/api/` requests to your backend
- CORS headers are configured in the app
- Make sure backend allows requests from frontend domain

