# Production Deployment - Step by Step Commands

## Prerequisites Check

Run these to verify everything is ready:

```powershell
# Check Docker is running
docker ps

# Check Azure CLI is logged in
az account show

# Check backend directory exists
Test-Path .\backend
```

Expected output:
- Docker: Shows container list (even if empty)
- Azure: Shows your subscription name
- Path: `True`

---

## Step 1: Build Docker Image

Navigate to project root and build:

```powershell
cd c:\Users\Admin\source\repos\RegistrationApp

docker build -t registrationappacr.azurecr.io/registration-api:latest -f backend/Dockerfile backend/
```

**Expected time:** 2-3 minutes

**Expected output ends with:**
```
Successfully built <hash>
Successfully tagged registrationappacr.azurecr.io/registration-api:latest
```

---

## Step 2: Login to Azure Container Registry

Get ACR credentials and login:

```powershell
# Get ACR username
az acr credential show --resource-group rg-registration-app --name registrationappacr --query "username" -o tsv

# Get ACR password
az acr credential show --resource-group rg-registration-app --name registrationappacr --query "passwords[0].value" -o tsv

# Login to Docker (replace <USERNAME> and <PASSWORD> with values from above)
docker login registrationappacr.azurecr.io -u <USERNAME> -p <PASSWORD>
```

**Expected output:**
```
Login Succeeded
```

---

## Step 3: Push Image to Azure Container Registry

```powershell
docker push registrationappacr.azurecr.io/registration-api:latest
```

**Expected time:** 1-2 minutes

**Expected output ends with:**
```
latest: digest: sha256:... size: ...
```

---

## Step 4: Delete Old Container (if exists)

```powershell
# Check if container exists
az container show --resource-group rg-registration-app --name registration-api-prod

# If it exists, delete it
az container delete --resource-group rg-registration-app --name registration-api-prod --yes

# Wait 10 seconds
Start-Sleep -Seconds 10
```

---

## Step 5: Deploy New Container

Get credentials first:

```powershell
$AcrUsername = az acr credential show --resource-group rg-registration-app --name registrationappacr --query "username" -o tsv

$AcrPassword = az acr credential show --resource-group rg-registration-app --name registrationappacr --query "passwords[0].value" -o tsv

echo "Username: $AcrUsername"
echo "Password: $AcrPassword"
```

Then create the container:

```powershell
az container create `
    --resource-group rg-registration-app `
    --name registration-api-prod `
    --image registrationappacr.azurecr.io/registration-api:latest `
    --cpu 1 `
    --memory 1 `
    --location centralindia `
    --os-type Linux `
    --registry-login-server registrationappacr.azurecr.io `
    --registry-username <PASTE_USERNAME_HERE> `
    --registry-password <PASTE_PASSWORD_HERE> `
    --ports 80 `
    --dns-name-label registration-api-prod `
    --environment-variables ASPNETCORE_ENVIRONMENT="Production" ConnectionStrings__DefaultConnection="Server=tcp:regsql2807.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourSecurePassword123!@#;Encrypt=True;Connection Timeout=30;" `
    --restart-policy OnFailure
```

**Expected output:** JSON response with container details

---

## Step 6: Get Container Information

```powershell
az container show --resource-group rg-registration-app --name registration-api-prod --query "ipAddress"
```

**Expected output:**
```json
{
  "dnsNameLabel": "registration-api-prod",
  "fqdn": "registration-api-prod.centralindia.azurecontainer.io",
  "ip": "4.187.xxx.xxx",
  "ports": [
    {
      "port": 80,
      "protocol": "TCP"
    }
  ],
  "type": "Public"
}
```

**Copy the FQDN:** `registration-api-prod.centralindia.azurecontainer.io`

---

## Step 7: Wait for Container to Start

Container takes 1-2 minutes to start. Wait:

```powershell
Start-Sleep -Seconds 90
```

---

## Step 8: Verify Container is Running

Check the status:

```powershell
az container show --resource-group rg-registration-app --name registration-api-prod --query "containers[0].instanceView.currentState"
```

**Expected output:**
```json
{
  "detailStatus": "Running",
  "exitCode": null,
  "finishTime": null,
  "startTime": "2026-02-09T15:30:00.000000+00:00",
  "state": "Running"
}
```

If state is `Waiting` or `CrashLoopBackOff`, check logs:

```powershell
az container logs --resource-group rg-registration-app --name registration-api-prod
```

---

## Step 9: Test the API

```powershell
# Test Items endpoint
curl "http://registration-api-prod.centralindia.azurecontainer.io/api/items"

# Should return JSON array like:
# [{"id":1,"name":"Item1","description":"...","createdAt":"..."}]
```

Or use PowerShell:

```powershell
$response = Invoke-WebRequest -Uri "http://registration-api-prod.centralindia.azurecontainer.io/api/items"
$response.Content | ConvertFrom-Json | Format-Table
```

---

## Test All Endpoints

If Step 9 works, test all endpoints:

```powershell
# Items
curl "http://registration-api-prod.centralindia.azurecontainer.io/api/items"

# Analytics
curl "http://registration-api-prod.centralindia.azurecontainer.io/api/analytics"

# Approvals Stats
curl "http://registration-api-prod.centralindia.azurecontainer.io/api/approvals/stats"

# Audit Logs
curl "http://registration-api-prod.centralindia.azurecontainer.io/api/audit"

# Notifications Stats
curl "http://registration-api-prod.centralindia.azurecontainer.io/api/notifications/stats"

# Health Check
curl "http://registration-api-prod.centralindia.azurecontainer.io/health"
```

All should return `200 OK` with JSON response.

---

## Troubleshooting

### If Container Shows "CrashLoopBackOff"

This means the container is crashing. Check logs:

```powershell
az container logs --resource-group rg-registration-app --name registration-api-prod
```

**Common issues:**
- Database connection string wrong
- ApplicationInsightsService errors (should be fixed now)

### If Connection Timeout

Container is still starting, wait another 1-2 minutes:

```powershell
Start-Sleep -Seconds 120

# Then check status again
az container show --resource-group rg-registration-app --name registration-api-prod --query "containers[0].instanceView.currentState.state" -o tsv
```

### If Database Connection Fails

Verify SQL credentials:

```powershell
sqlcmd -S regsql2807.database.windows.net -d RegistrationAppDb -U sqladmin -P "YourSecurePassword123!@#" -Q "SELECT 1"
```

Should return `1` without errors.

### View Live Logs

```powershell
az container logs --resource-group rg-registration-app --name registration-api-prod --follow
```

Press `Ctrl+C` to stop following logs.

---

## Success Criteria

✅ Deployment is successful when:

1. Container state is `Running` (Step 8)
2. API endpoint returns JSON (Step 9)
3. All endpoints respond with 200 OK (Test All Endpoints)
4. No crash loops or error messages in logs

---

## Quick Reference - All Commands in One Block

```powershell
# 1. Build
cd c:\Users\Admin\source\repos\RegistrationApp
docker build -t registrationappacr.azurecr.io/registration-api:latest -f backend/Dockerfile backend/

# 2. Get credentials
$AcrUsername = az acr credential show --resource-group rg-registration-app --name registrationappacr --query "username" -o tsv
$AcrPassword = az acr credential show --resource-group rg-registration-app --name registrationappacr --query "passwords[0].value" -o tsv

# 3. Login and push
docker login registrationappacr.azurecr.io -u $AcrUsername -p $AcrPassword
docker push registrationappacr.azurecr.io/registration-api:latest

# 4. Deploy
az container create --resource-group rg-registration-app --name registration-api-prod --image registrationappacr.azurecr.io/registration-api:latest --cpu 1 --memory 1 --location centralindia --os-type Linux --registry-login-server registrationappacr.azurecr.io --registry-username $AcrUsername --registry-password $AcrPassword --ports 80 --dns-name-label registration-api-prod --environment-variables ASPNETCORE_ENVIRONMENT="Production" ConnectionStrings__DefaultConnection="Server=tcp:regsql2807.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourSecurePassword123!@#;Encrypt=True;Connection Timeout=30;" --restart-policy OnFailure

# 5. Wait
Start-Sleep -Seconds 90

# 6. Verify
az container show --resource-group rg-registration-app --name registration-api-prod --query "containers[0].instanceView.currentState"

# 7. Test
curl "http://registration-api-prod.centralindia.azurecontainer.io/api/items"
```

---

## After Successful Deployment

Your API is now live at:
```
http://registration-api-prod.centralindia.azurecontainer.io
```

Document this URL and share with your frontend team for integration.

---

**Next Steps:**
1. Execute the commands above
2. Let me know the results (especially Step 8 and Step 9 output)
3. If there are any errors, share the error message and I'll help debug

