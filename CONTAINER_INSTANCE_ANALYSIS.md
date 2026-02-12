# 🏗️ Your Azure Architecture Analysis & Deployment Issues

**Analysis Date:** February 12, 2026  
**Your Actual Deployment:** Container Instances (NOT App Service)

---

## 🎯 YOUR ACTUAL INFRASTRUCTURE

Based on your resource list, here's what you actually deployed:

```
Azure Resources You Have:
├─ 🐳 CONTAINER INSTANCES (How your API is deployed)
│  ├─ registration-api-prod (Backend - .NET 8.0)
│  └─ registration-frontend-prod (Frontend - Angular)
│
├─ 📊 DATABASES
│  ├─ Azure SQL Server (regsql2807) - SQL Server
│  └─ Cosmos DB (cosmos-registrationapp-india) - NoSQL
│
├─ 🔐 SECURITY & SECRETS
│  ├─ Key Vault (kv-registrationapp)
│  └─ Key Vault (regsql-kv-2807) - Backup
│
├─ 📨 MESSAGING
│  └─ Service Bus (sb-registrationapp-eastus)
│
├─ ☁️ STORAGE
│  ├─ Storage Account (stregistrationapp2807) - Blobs
│  └─ Storage Account (stregistrationappfunc) - Functions
│
├─ ⚡ SERVERLESS
│  ├─ Function App (func-registrationapp) - .NET 8.0
│  └─ App Insights (func-registrationapp)
│
├─ 🐳 CONTAINER REGISTRY
│  └─ ACR (registrationappacr) - Docker Images
│
├─ 📊 MONITORING
│  └─ App Insights (insights-registration-app)
│
└─ 💾 HOSTING
   └─ App Service Plan (EastUSPlan) - Only for Function App
```

---

## ⚠️ THE PROBLEM: Why Your Deployment Failed

### Issue 1: **WRONG QUICK_FIX_GUIDE**
Your guide references `az webapp identity assign` which is for **App Service**, but you deployed to **Container Instances**.

- **App Service** = Managed by Azure (PaaS)
- **Container Instances** = You manage the container (CaaS)
- **Your Setup** = Container Instances (need different commands)

### Issue 2: **MANAGED IDENTITY NOT WORKING WITH CONTAINERS**
Container Instances **DO NOT support Managed Identity** the same way App Services do.

**Solution:** You need to:
1. Create a **Service Principal** (not Managed Identity)
2. Grant it permissions to Key Vault
3. Pass credentials as **environment variables** to the container

### Issue 3: **ENVIRONMENT VARIABLES NOT BEING PASSED TO CONTAINERS**
Your `docker-compose.prod.yml` uses placeholders:
```yaml
ConnectionStrings__DefaultConnection: "${AZURE_SQL_CONNECTION_STRING}"
```

But the actual values are **never set** when deploying to Azure Container Instances.

### Issue 4: **NO DOCKERFILE FOR FRONTEND**
Your Angular frontend is deployed as a container, but there's no Dockerfile for it.

### Issue 5: **KEY VAULT ACCESS IN CONTAINERS**
The code tries to use `DefaultAzureCredential()` which:
- ✅ Works in App Service (has Managed Identity)
- ❌ Fails in Container Instances (no Managed Identity)
- ❌ Falls back to hardcoded values in config

---

## 📋 Step-by-Step Fix Plan

### **STEP 1: Create Service Principal for Container Access**

Instead of Managed Identity, use a Service Principal:

```powershell
# Create a Service Principal for your containers
$sp = az ad sp create-for-rbac `
  --name "RegistrationAppContainerPrincipal" `
  --role "Key Vault Secrets Officer" `
  --scopes "/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/rg-registration-app"

$clientId = $sp.appId
$clientSecret = $sp.password
$tenantId = $sp.tenant

Write-Host "Service Principal Created:"
Write-Host "Client ID: $clientId"
Write-Host "Client Secret: $clientSecret"
Write-Host "Tenant ID: $tenantId"

# Save these for later use!
```

---

### **STEP 2: Grant Key Vault Access to Service Principal**

```powershell
# Grant the Service Principal access to Key Vault
az keyvault set-policy `
  --name kv-registrationapp `
  --spn $clientId `
  --secret-permissions get list
```

---

### **STEP 3: Store Service Principal Credentials in Key Vault**

```powershell
# Store the credentials securely
az keyvault secret set `
  --vault-name kv-registrationapp `
  --name "ServicePrincipalClientId" `
  --value $clientId

az keyvault secret set `
  --vault-name kv-registrationapp `
  --name "ServicePrincipalClientSecret" `
  --value $clientSecret

az keyvault secret set `
  --vault-name kv-registrationapp `
  --name "ServicePrincipalTenantId" `
  --value $tenantId
```

---

### **STEP 4: Update Program.cs for Service Principal Authentication**

Instead of using `DefaultAzureCredential()`, use `ClientSecretCredential`:

```csharp
// In backend/Program.cs
if (!builder.Environment.IsDevelopment())
{
    var clientId = Environment.GetEnvironmentVariable("AZURE_CLIENT_ID");
    var clientSecret = Environment.GetEnvironmentVariable("AZURE_CLIENT_SECRET");
    var tenantId = Environment.GetEnvironmentVariable("AZURE_TENANT_ID");
    var keyVaultUrl = builder.Configuration["AzureKeyVault:VaultUri"];

    if (!string.IsNullOrEmpty(clientId) && !string.IsNullOrEmpty(clientSecret))
    {
        try
        {
            // Use Service Principal credentials instead of DefaultAzureCredential
            var credential = new ClientSecretCredential(tenantId, clientId, clientSecret);
            builder.Configuration.AddAzureKeyVault(
                new Uri(keyVaultUrl),
                credential);
            Console.WriteLine("✓ Key Vault configured with Service Principal");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"✗ Failed to connect to Key Vault: {ex.Message}");
            throw;
        }
    }
    else
    {
        throw new InvalidOperationException(
            "Service Principal credentials not found. " +
            "Set AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, and AZURE_TENANT_ID environment variables.");
    }
}
```

**Add this to your Program.cs at the top:**
```csharp
using Azure.Identity;  // Already there
```

---

### **STEP 5: Update docker-compose.prod.yml with Real Values**

Replace the placeholders with actual environment variables passed to the container:

```yaml
version: "3.9"

services:
  registration-api-prod:
    image: registrationappacr.azurecr.io/registration-api-prod:latest
    container_name: registrationapp-backend-prod
    environment:
      # ASP.NET Configuration
      ASPNETCORE_ENVIRONMENT: Production
      ASPNETCORE_URLS: http://+:80
      
      # Service Principal for Key Vault
      AZURE_CLIENT_ID: ${AZURE_CLIENT_ID}
      AZURE_CLIENT_SECRET: ${AZURE_CLIENT_SECRET}
      AZURE_TENANT_ID: ${AZURE_TENANT_ID}
      
      # Database Connection (from Key Vault)
      ConnectionStrings__DefaultConnection: ${AZURE_SQL_CONNECTION_STRING}
      
      # Key Vault Configuration
      AzureKeyVault__VaultUri: https://kv-registrationapp.vault.azure.net/
      
      # Application Insights
      APPLICATIONINSIGHTS_CONNECTION_STRING: ${APPLICATIONINSIGHTS_CONNECTION_STRING}
      
      # Logging
      Logging__LogLevel__Default: Information
      Logging__LogLevel__Microsoft: Warning
      
    ports:
      - "80:80"
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

---

### **STEP 6: Update Container Creation Script**

Your deployment script needs to pass environment variables:

**Current (BROKEN):**
```powershell
az container create `
  --resource-group rg-registration-app `
  --name registration-api-prod `
  --image registrationappacr.azurecr.io/registration-api-prod:latest `
  --ports 80
```

**Fixed:**
```powershell
# Get Service Principal credentials from Key Vault
$clientId = az keyvault secret show --vault-name kv-registrationapp `
  --name "ServicePrincipalClientId" --query value -o tsv
  
$clientSecret = az keyvault secret show --vault-name kv-registrationapp `
  --name "ServicePrincipalClientSecret" --query value -o tsv
  
$tenantId = az keyvault secret show --vault-name kv-registrationapp `
  --name "ServicePrincipalTenantId" --query value -o tsv

$sqlConnectionString = az keyvault secret show --vault-name kv-registrationapp `
  --name "SqlConnectionString" --query value -o tsv

# Get SQL password from Key Vault (if stored separately)
$sqlPassword = az keyvault secret show --vault-name kv-registrationapp `
  --name "SqlPassword" --query value -o tsv

# Build complete connection string
$connectionString = "Server=tcp:regsql2807.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=$sqlPassword;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

# Create the container with environment variables
az container create `
  --resource-group rg-registration-app `
  --name registration-api-prod `
  --image registrationappacr.azurecr.io/registration-api-prod:latest `
  --registry-login-server registrationappacr.azurecr.io `
  --registry-username <ACR_USERNAME> `
  --registry-password <ACR_PASSWORD> `
  --environment-variables `
    ASPNETCORE_ENVIRONMENT=Production `
    AZURE_CLIENT_ID=$clientId `
    AZURE_CLIENT_SECRET=$clientSecret `
    AZURE_TENANT_ID=$tenantId `
    "ConnectionStrings__DefaultConnection=$connectionString" `
    AzureKeyVault__VaultUri=https://kv-registrationapp.vault.azure.net/ `
  --ports 80 `
  --dns-name-label registration-api-prod `
  --restart-policy OnFailure
```

---

### **STEP 7: Fix Azure Service Bus Configuration**

For Service Bus, you also need the connection string:

```powershell
# Get Service Bus connection string
$serviceBusConnStr = az servicebus namespace authorization-rule keys list `
  --resource-group rg-registration-app `
  --namespace-name sb-registrationapp-eastus `
  --name RootManageSharedAccessKey `
  --query primaryConnectionString -o tsv

# Store in Key Vault
az keyvault secret set `
  --vault-name kv-registrationapp `
  --name "ServiceBusConnectionString" `
  --value $serviceBusConnStr
```

Then add to container environment variables in Step 6:
```powershell
ConnectionStrings__AzureServiceBus=$serviceBusConnStr
```

---

### **STEP 8: Fix Function App (Uses App Service Plan)**

For the Function App, it DOES use an App Service Plan, so use the original commands:

```powershell
# Get Function App identity
$funcIdentity = az functionapp identity show `
  --resource-group rg-registration-app `
  --name func-registrationapp `
  --query principalId -o tsv

# Grant Key Vault access
az keyvault set-policy `
  --name kv-registrationapp `
  --object-id $funcIdentity `
  --secret-permissions get list

# Set Function App environment variables
az functionapp config appsettings set `
  --resource-group rg-registration-app `
  --name func-registrationapp `
  --settings `
    "AzureWebJobsServiceBusConnectionString=$serviceBusConnStr" `
    "SendGridApiKey=$sendGridApiKey"
```

---

## 📝 Why Your Current Setup Fails

```
Container Instance tries to start
  ├─ Reads environment variables (empty placeholders)
  ├─ Program.cs calls DefaultAzureCredential()
  │   └─ Fails (no Managed Identity in Container Instance)
  ├─ Falls back to appsettings.json
  │   └─ Has hardcoded values (EXPOSED!)
  ├─ Tries to connect to SQL Server with wrong password
  │   └─ Connection fails
  ├─ Tries to read from Key Vault
  │   └─ No credentials, auth fails
  └─ App starts but services fail silently
```

---

## ✅ Correct Flow (After Fixes)

```
Container Instance starts
  ├─ Reads environment variables (REAL values injected)
  │   └─ AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, etc.
  ├─ Program.cs uses ClientSecretCredential
  │   └─ Service Principal authentication succeeds
  ├─ Connects to Key Vault successfully
  │   └─ Retrieves all secrets
  ├─ Connects to SQL Server with real password
  │   └─ Database connected!
  ├─ Publishes to Service Bus
  │   └─ Messages sent successfully
  └─ Container ready to serve requests ✓
```

---

## 📚 Summary of Required Changes

| Item | Current | Need to Fix |
|------|---------|------------|
| **Authentication** | DefaultAzureCredential | ClientSecretCredential |
| **Principal Type** | Managed Identity (doesn't work) | Service Principal |
| **Env Variables** | Placeholders ${VAR} | Real values from Key Vault |
| **Connection String** | Hardcoded in config | Passed as env var |
| **Program.cs** | Uses DefaultAzureCredential | Uses ClientSecretCredential |
| **Deployment Script** | No env variables | Passes all env variables |
| **Container Creation** | Missing credentials | Includes all secrets |

---

## 🚀 Corrected QUICK_FIX_GUIDE (For Container Instances)

I'll now update your QUICK_FIX_GUIDE to be correct for your actual Container Instance deployment.

