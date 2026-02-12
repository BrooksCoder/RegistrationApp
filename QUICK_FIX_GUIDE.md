# 🚀 QUICK FIX GUIDE - Production Deployment (Container Instances)

## ⚠️ IMPORTANT: Your Deployment Type

You're using **Azure Container Instances**, NOT App Service. This guide is corrected for that.

---

## ⚡ 5-Minute Quick Start

If you're in a hurry, follow these 7 critical steps:

### 1. **Remove Hardcoded Secrets (SECURITY)**

```bash
# Remove local files from git history
git rm --cached ItemNotificationFunction/local.settings.json
git rm --cached backend/appsettings.Production.json
git commit -m "Remove hardcoded secrets from production config"

# Add to .gitignore
echo "local.settings.json" >> ItemNotificationFunction/.gitignore
echo "appsettings.Production.json" >> backend/.gitignore
git add .gitignore
git commit -m "Add local.settings.json and appsettings files to gitignore"

# Force push to remove from history (CAREFUL - only if repo is private)
git filter-branch --tree-filter 'rm -f ItemNotificationFunction/local.settings.json' -- --all
git push origin --force --all
```

### 2. **Create Service Principal (For Container Authentication)**

Container Instances don't support Managed Identity like App Service does. Use a Service Principal instead:

```powershell
# Create Service Principal for your container
$sp = az ad sp create-for-rbac `
  --name "RegistrationAppContainerPrincipal" `
  --role "Key Vault Secrets Officer" `
  --scopes "/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/rg-registration-app"

# Extract credentials
$clientId = $sp.appId
$clientSecret = $sp.password
$tenantId = $sp.tenant

Write-Host "Service Principal Created:"
Write-Host "Client ID: $clientId"
Write-Host "Client Secret: $clientSecret"
Write-Host "Tenant ID: $tenantId"
```

### 3. **Grant Key Vault Access to Service Principal**

```powershell
# Grant Key Vault access
az keyvault set-policy `
  --name kv-registrationapp `
  --spn $clientId `
  --secret-permissions get list
```

### 4. **Store Service Principal Credentials in Key Vault**

```powershell
# Store credentials securely
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

### 5. **Get All Required Secrets from Key Vault**

```powershell
# Retrieve all secrets you need
$sqlPassword = az keyvault secret show `
  --vault-name kv-registrationapp `
  --name "SqlPassword" `
  --query value -o tsv

$serviceBusConnStr = az keyvault secret show `
  --vault-name kv-registrationapp `
  --name "ServiceBusConnectionString" `
  --query value -o tsv

$cosmosConnStr = az keyvault secret show `
  --vault-name kv-registrationapp `
  --name "CosmosDbConnectionString" `
  --query value -o tsv

$appInsightsKey = az keyvault secret show `
  --vault-name kv-registrationapp `
  --name "ApplicationInsightsKey" `
  --query value -o tsv
```

### 6. **Update and Deploy Backend Container**

```powershell
# Build Docker image
cd backend
docker build -t registrationappacr.azurecr.io/registration-api-prod:latest .

# Login to ACR
$acrPassword = az acr credential show `
  --resource-group rg-registration-app `
  --name registrationappacr `
  --query "passwords[0].value" -o tsv

docker login registrationappacr.azurecr.io -u registrationappacr -p $acrPassword

# Push image
docker push registrationappacr.azurecr.io/registration-api-prod:latest

# Delete old container
az container delete `
  --resource-group rg-registration-app `
  --name registration-api-prod `
  --yes

# Create new container with environment variables
$sqlConnectionString = "Server=tcp:regsql2807.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=$sqlPassword;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

az container create `
  --resource-group rg-registration-app `
  --name registration-api-prod `
  --image registrationappacr.azurecr.io/registration-api-prod:latest `
  --registry-login-server registrationappacr.azurecr.io `
  --registry-username registrationappacr `
  --registry-password $acrPassword `
  --environment-variables `
    ASPNETCORE_ENVIRONMENT=Production `
    AZURE_CLIENT_ID=$clientId `
    AZURE_CLIENT_SECRET=$clientSecret `
    AZURE_TENANT_ID=$tenantId `
    "ConnectionStrings__DefaultConnection=$sqlConnectionString" `
    "ConnectionStrings__AzureServiceBus=$serviceBusConnStr" `
    "ConnectionStrings__AzureCosmosDb=$cosmosConnStr" `
    "APPLICATIONINSIGHTS_CONNECTION_STRING=$appInsightsKey" `
    "AzureKeyVault__VaultUri=https://kv-registrationapp.vault.azure.net/" `
  --ports 80 `
  --dns-name-label registration-api-prod `
  --restart-policy OnFailure
```

### 7. **Enable Function App (Uses App Service Plan - THIS ONE HAS MANAGED IDENTITY)**

The Function App uses an actual App Service Plan, so it CAN use Managed Identity:

```powershell
# Function App identity (it's already using EastUSPlan App Service Plan)
$funcIdentity = az functionapp identity show `
  --resource-group rg-registration-app `
  --name func-registrationapp `
  --query principalId -o tsv

# Grant Key Vault access
az keyvault set-policy `
  --name kv-registrationapp `
  --object-id $funcIdentity `
  --secret-permissions get list

# Get SendGrid API Key
$sendGridApiKey = "SG.YOUR_ACTUAL_KEY"  # Get this from SendGrid

# Store in Key Vault
az keyvault secret set `
  --vault-name kv-registrationapp `
  --name "SendGridApiKey" `
  --value $sendGridApiKey

# Configure Function App
az functionapp config appsettings set `
  --resource-group rg-registration-app `
  --name func-registrationapp `
  --settings `
    "AzureWebJobsServiceBusConnectionString=$serviceBusConnStr" `
    "SendGridApiKey=$sendGridApiKey"
```

---

## 🔍 Verification Checklist

Run these commands to verify everything is working:

```bash
# 1. Health check (use Container Instance URL)
curl http://registration-api-prod.centralindia.azurecontainer.io/health

# 2. Test API endpoint
curl http://registration-api-prod.centralindia.azurecontainer.io/api/items

# 3. Check container logs for errors
az container logs \
  --resource-group rg-registration-app \
  --name registration-api-prod

# 4. Check container status
az container show \
  --resource-group rg-registration-app \
  --name registration-api-prod \
  --query "{State:instanceView.state, Restarts:instanceView.restartCount}"

# 5. Check function app logs
az functionapp log tail \
  --resource-group rg-registration-app \
  --name func-registrationapp \
  --tail

# 6. Check Key Vault access
az keyvault secret show \
  --vault-name kv-registrationapp \
  --name "ServiceBusConnectionString"
```

---

## 📝 What Each Issue Causes

| Issue | Effect | How to Know It's Broken |
|-------|--------|------------------------|
| **Missing SQL Password** | App won't start | `SqlException: Login failed` in logs |
| **No Managed Identity** | Can't access Key Vault | `DefaultAzureCredential() failed` in logs |
| **Missing Key Vault URL** | Secrets not retrieved | `AzureKeyVault:VaultUri not configured` warning |
| **Hardcoded in local.settings.json** | Credentials exposed | Check git history: `git log -p ItemNotificationFunction/local.settings.json` |
| **Service Bus not configured** | Emails not sent | Emails never arrive, no error messages |
| **Cosmos DB connection wrong** | Audit logs fail | Warnings in logs, but app still runs |

---

## 🔐 Security Checklist

- [ ] No plaintext passwords in any configuration files
- [ ] No API keys in code or git history
- [ ] local.settings.json is in .gitignore
- [ ] appsettings.Production.json is in .gitignore
- [ ] All secrets stored in Azure Key Vault
- [ ] Managed Identity enabled on App Service
- [ ] Managed Identity enabled on Function App
- [ ] Key Vault access policies restrict to App Services only
- [ ] Git history cleaned of exposed secrets (if repo was public)
- [ ] Secrets rotated after any exposure

---

## 🐛 Troubleshooting

### Problem: Container fails to start
```bash
# Check the container logs
az container logs \
  --resource-group rg-registration-app \
  --name registration-api-prod

# Look for errors related to:
# - "DefaultAzureCredential failed" → Service Principal not configured
# - "SqlException: Login failed" → Wrong SQL password
# - "Key Vault access denied" → Service Principal doesn't have permissions
```

### Problem: "DefaultAzureCredential() failed" in logs
```bash
# This means your container needs Service Principal credentials
# Check environment variables are set:
az container show \
  --resource-group rg-registration-app \
  --name registration-api-prod \
  --query containers[0].environmentVariables

# If AZURE_CLIENT_ID is missing, redeploy with environment variables
```

### Problem: "Login failed for user 'sqladmin'"
```bash
# Wrong password in connection string
# Get the correct password from Key Vault:
az keyvault secret show \
  --vault-name kv-registrationapp \
  --name "SqlPassword" \
  --query value -o tsv

# Redeploy the container with correct connection string
```

### Problem: "Key Vault access denied"
```bash
# Service Principal might not have Key Vault permissions
# Grant permissions again:
az keyvault set-policy `
  --name kv-registrationapp `
  --spn $clientId `
  --secret-permissions get list
```

### Problem: "Emails not being sent"
```bash
# Check if Service Bus connection is correct
az servicebus namespace authorization-rule keys list `
  --resource-group rg-registration-app `
  --namespace-name sb-registrationapp-eastus `
  --name RootManageSharedAccessKey `
  --query primaryConnectionString

# Check if Function App is running
az functionapp show --resource-group rg-registration-app --name func-registrationapp --query state

# Check if messages are in the queue
az servicebus queue show-runtime-properties `
  --resource-group rg-registration-app `
  --namespace-name sb-registrationapp-eastus `
  --name email-notifications-queue

# Check function logs
az functionapp log tail --resource-group rg-registration-app --name func-registrationapp
```

---

## 📚 Additional Resources

1. **Detailed Analysis:** See `PRODUCTION_ISSUES_ANALYSIS.md` for complete breakdown
2. **Full Fix Script:** Run `Fix-ProductionIssues.ps1` for automated fixes
3. **Azure Docs:**
   - [Managed Identity](https://docs.microsoft.com/azure/app-service/overview-managed-identity)
   - [Key Vault Integration](https://docs.microsoft.com/azure/app-service/app-service-key-vault-references)
   - [DefaultAzureCredential](https://docs.microsoft.com/dotnet/api/azure.identity.defaultazurecredential)

---

## ✅ Production Ready Checklist

- [ ] All secrets in Key Vault
- [ ] Managed Identity enabled and configured
- [ ] Connection strings using environment variables
- [ ] Application starts without errors
- [ ] Health endpoint returns 200 OK
- [ ] Database migrations successful
- [ ] Can create items
- [ ] Email notifications triggered
- [ ] Logs appear in Application Insights
- [ ] No warnings about missing configuration

Once all checks pass, you're ready for production! 🚀
