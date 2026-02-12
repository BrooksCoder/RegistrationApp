# 🔧 COMPLETE STEP-BY-STEP FIX FOR CONTAINER INSTANCES

**Your Actual Architecture:** Container Instances + Function App + Key Vault

---

## Step 1️⃣: Create Service Principal

A Service Principal is like a "bot account" that your container can use to authenticate.

```powershell
# First, get your subscription ID
$subscriptionId = az account show --query id -o tsv
Write-Host "Your Subscription ID: $subscriptionId"

# Create the Service Principal
$sp = az ad sp create-for-rbac `
  --name "RegistrationAppContainerPrincipal" `
  --role "Key Vault Secrets Officer" `
  --scopes "/subscriptions/$subscriptionId/resourceGroups/rg-registration-app"

# Extract the important values
$clientId = $sp.appId
$clientSecret = $sp.password
$tenantId = $sp.tenant

Write-Host ""
Write-Host "========== SERVICE PRINCIPAL CREATED ==========" -ForegroundColor Green
Write-Host "Client ID: $clientId"
Write-Host "Client Secret: $clientSecret"
Write-Host "Tenant ID: $tenantId"
Write-Host "=============================================="
Write-Host "SAVE THESE VALUES! You'll need them."
```

**❌ DON'T LOSE THESE VALUES** - You need them in the next steps!

---

## Step 2️⃣: Grant Key Vault Permissions

The Service Principal needs permission to read secrets from Key Vault.

```powershell
# Grant the Service Principal access to Key Vault
az keyvault set-policy `
  --name kv-registrationapp `
  --spn $clientId `
  --secret-permissions get list

Write-Host "Service Principal granted Key Vault access" -ForegroundColor Green
```

---

## Step 3️⃣: Store Service Principal Credentials in Key Vault

Store the credentials securely so you don't hardcode them.

```powershell
# Store Client ID
az keyvault secret set `
  --vault-name kv-registrationapp `
  --name "ServicePrincipalClientId" `
  --value $clientId

Write-Host "✓ Stored ServicePrincipalClientId"

# Store Client Secret
az keyvault secret set `
  --vault-name kv-registrationapp `
  --name "ServicePrincipalClientSecret" `
  --value $clientSecret

Write-Host "✓ Stored ServicePrincipalClientSecret"

# Store Tenant ID
az keyvault secret set `
  --vault-name kv-registrationapp `
  --name "ServicePrincipalTenantId" `
  --value $tenantId

Write-Host "✓ Stored ServicePrincipalTenantId"
```

---

## Step 4️⃣: Ensure All Required Secrets Are in Key Vault

```powershell
# Check if all required secrets exist
$requiredSecrets = @(
    "SqlPassword",
    "ServiceBusConnectionString",
    "CosmosDbConnectionString",
    "ApplicationInsightsKey",
    "SendGridApiKey"
)

Write-Host "Checking Key Vault secrets..."
foreach ($secret in $requiredSecrets) {
    try {
        $value = az keyvault secret show --vault-name kv-registrationapp --name $secret --query value -o tsv
        if ($value) {
            Write-Host "✓ $secret exists" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "✗ $secret MISSING - You need to add this!" -ForegroundColor Red
    }
}
```

**If any secret is missing, add it:**

```powershell
# Example: Adding SQL Password
az keyvault secret set `
  --vault-name kv-registrationapp `
  --name "SqlPassword" `
  --value "your_actual_sql_password"

# Example: Adding Service Bus Connection String
az keyvault secret set `
  --vault-name kv-registrationapp `
  --name "ServiceBusConnectionString" `
  --value "Endpoint=sb://sb-registrationapp-eastus.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=YOUR_KEY"
```

---

## Step 5️⃣: Update Program.cs to Use Service Principal

Change your authentication method in the backend code.

**File:** `backend/Program.cs`

Replace this code (around line 16-32):

```csharp
// OLD - Uses DefaultAzureCredential (doesn't work in Container Instances)
if (!builder.Environment.IsDevelopment())
{
    var keyVaultUrl = builder.Configuration["AzureKeyVault:VaultUri"];
    if (!string.IsNullOrEmpty(keyVaultUrl) && !keyVaultUrl.StartsWith("<"))
    {
        try
        {
            var credential = new DefaultAzureCredential();
            builder.Configuration.AddAzureKeyVault(
                new Uri(keyVaultUrl),
                credential);
            Console.WriteLine("✓ Azure Key Vault configured successfully");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"⚠ Failed to connect to Key Vault: {ex.Message}.");
        }
    }
}
```

With this code:

```csharp
// NEW - Uses Service Principal (works in Container Instances)
if (!builder.Environment.IsDevelopment())
{
    var clientId = Environment.GetEnvironmentVariable("AZURE_CLIENT_ID");
    var clientSecret = Environment.GetEnvironmentVariable("AZURE_CLIENT_SECRET");
    var tenantId = Environment.GetEnvironmentVariable("AZURE_TENANT_ID");
    var keyVaultUrl = builder.Configuration["AzureKeyVault:VaultUri"];

    if (!string.IsNullOrEmpty(clientId) && !string.IsNullOrEmpty(clientSecret) && !string.IsNullOrEmpty(keyVaultUrl))
    {
        try
        {
            // Use Service Principal credentials instead of DefaultAzureCredential
            var credential = new ClientSecretCredential(tenantId, clientId, clientSecret);
            builder.Configuration.AddAzureKeyVault(
                new Uri(keyVaultUrl),
                credential);
            Console.WriteLine("✓ Azure Key Vault configured with Service Principal");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"✗ Failed to connect to Key Vault: {ex.Message}");
            throw;  // Fail fast in production
        }
    }
    else
    {
        throw new InvalidOperationException(
            "Service Principal credentials missing. " +
            "Set AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, AZURE_TENANT_ID environment variables.");
    }
}
```

**Make sure these are at the top of Program.cs:**

```csharp
using Azure.Identity;  // Add this if not there
```

---

## Step 6️⃣: Rebuild and Push Docker Image

```powershell
# Navigate to backend directory
cd c:\Users\Admin\source\repos\RegistrationApp\backend

# Build the Docker image with the code changes
docker build -t registrationappacr.azurecr.io/registration-api-prod:latest .

Write-Host "Docker image built successfully" -ForegroundColor Green

# Login to Azure Container Registry
$acrPassword = az acr credential show `
  --resource-group rg-registration-app `
  --name registrationappacr `
  --query "passwords[0].value" -o tsv

docker login registrationappacr.azurecr.io -u registrationappacr -p $acrPassword

Write-Host "Logged in to ACR" -ForegroundColor Green

# Push the image to ACR
docker push registrationappacr.azurecr.io/registration-api-prod:latest

Write-Host "Docker image pushed to ACR" -ForegroundColor Green
```

---

## Step 7️⃣: Prepare Environment Variables

Get all the values you need to pass to the container.

```powershell
# Get Service Principal credentials
$clientId = az keyvault secret show --vault-name kv-registrationapp `
  --name "ServicePrincipalClientId" --query value -o tsv

$clientSecret = az keyvault secret show --vault-name kv-registrationapp `
  --name "ServicePrincipalClientSecret" --query value -o tsv

$tenantId = az keyvault secret show --vault-name kv-registrationapp `
  --name "ServicePrincipalTenantId" --query value -o tsv

# Get database password
$sqlPassword = az keyvault secret show --vault-name kv-registrationapp `
  --name "SqlPassword" --query value -o tsv

# Get other connection strings
$serviceBusConnStr = az keyvault secret show --vault-name kv-registrationapp `
  --name "ServiceBusConnectionString" --query value -o tsv

$cosmosConnStr = az keyvault secret show --vault-name kv-registrationapp `
  --name "CosmosDbConnectionString" --query value -o tsv

$appInsightsKey = az keyvault secret show --vault-name kv-registrationapp `
  --name "ApplicationInsightsKey" --query value -o tsv

# Build SQL connection string
$sqlConnectionString = "Server=tcp:regsql2807.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=$sqlPassword;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

Write-Host "All environment variables prepared" -ForegroundColor Green
```

---

## Step 8️⃣: Delete Old Container

```powershell
# Delete the old container instance
az container delete `
  --resource-group rg-registration-app `
  --name registration-api-prod `
  --yes

Write-Host "Old container deleted" -ForegroundColor Green

# Wait a moment for the deletion to complete
Start-Sleep -Seconds 5
```

---

## Step 9️⃣: Create New Container with Correct Environment Variables

```powershell
# Get ACR credentials
$acrPassword = az acr credential show `
  --resource-group rg-registration-app `
  --name registrationappacr `
  --query "passwords[0].value" -o tsv

# Create the new container with all environment variables
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
  --cpu 1 `
  --memory 1 `
  --ports 80 `
  --dns-name-label registration-api-prod `
  --restart-policy OnFailure

Write-Host "Container created successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "API will be available at:" -ForegroundColor Cyan
Write-Host "http://registration-api-prod.centralindia.azurecontainer.io"
```

---

## Step 🔟: Enable Function App (It Uses App Service Plan)

For the Function App, use the standard Managed Identity approach:

```powershell
# Get Function App identity (it already has one because it's on an App Service Plan)
$funcIdentity = az functionapp identity show `
  --resource-group rg-registration-app `
  --name func-registrationapp `
  --query principalId -o tsv

# Grant Key Vault access
az keyvault set-policy `
  --name kv-registrationapp `
  --object-id $funcIdentity `
  --secret-permissions get list

Write-Host "Function App Managed Identity configured" -ForegroundColor Green

# Store SendGrid key in Key Vault if not already there
$sendGridKey = "SG.YOUR_SENDGRID_KEY"  # Replace with your actual key

az keyvault secret set `
  --vault-name kv-registrationapp `
  --name "SendGridApiKey" `
  --value $sendGridKey

# Configure Function App with Key Vault references
az functionapp config appsettings set `
  --resource-group rg-registration-app `
  --name func-registrationapp `
  --settings `
    "AzureWebJobsServiceBusConnectionString=@Microsoft.KeyVault(SecretUri=https://kv-registrationapp.vault.azure.net/secrets/ServiceBusConnectionString/)" `
    "SendGridApiKey=@Microsoft.KeyVault(SecretUri=https://kv-registrationapp.vault.azure.net/secrets/SendGridApiKey/)"

Write-Host "Function App configured" -ForegroundColor Green
```

---

## ✅ Step 11️⃣: Verify Everything Works

```powershell
# 1. Check container is running
Write-Host "Checking container status..." -ForegroundColor Cyan
$containerStatus = az container show `
  --resource-group rg-registration-app `
  --name registration-api-prod `
  --query "instanceView.state"

Write-Host "Container State: $containerStatus"

# 2. Check container logs
Write-Host ""
Write-Host "Container Logs (last 50 lines):" -ForegroundColor Cyan
az container logs `
  --resource-group rg-registration-app `
  --name registration-api-prod `
  | Select-Object -Last 50

# 3. Test health endpoint
Write-Host ""
Write-Host "Testing health endpoint..." -ForegroundColor Cyan
try {
    $health = curl -Uri "http://registration-api-prod.centralindia.azurecontainer.io/health" -ErrorAction Stop
    Write-Host "✓ API is responding!" -ForegroundColor Green
    Write-Host "Response: $health"
}
catch {
    Write-Host "✗ API not responding yet (container might still be starting)" -ForegroundColor Yellow
}

# 4. Check Function App
Write-Host ""
Write-Host "Function App Status:" -ForegroundColor Cyan
az functionapp show `
  --resource-group rg-registration-app `
  --name func-registrationapp `
  --query state

Write-Host ""
Write-Host "✓ Setup Complete!" -ForegroundColor Green
```

---

## 🎯 What to Do If It Still Doesn't Work

### If container keeps restarting:

```powershell
# Check the error in logs
az container logs `
  --resource-group rg-registration-app `
  --name registration-api-prod

# Look for:
# - "DefaultAzureCredential failed" → Service Principal auth failed
# - "SqlException" → Database connection failed
# - "Key Vault access denied" → Permissions missing
```

### If you see "DefaultAzureCredential failed":

```powershell
# Make sure Program.cs is updated to use ClientSecretCredential
# Rebuild and push the Docker image:
cd backend
docker build -t registrationappacr.azurecr.io/registration-api-prod:latest .
docker push registrationappacr.azurecr.io/registration-api-prod:latest

# Then redeploy the container (Step 8 & 9)
```

### If you see "SqlException: Login failed":

```powershell
# The SQL password is wrong
# Get the correct password:
az keyvault secret show --vault-name kv-registrationapp --name "SqlPassword" --query value -o tsv

# Update the container with the correct password
# (Run Step 7 & 9 again with the correct password)
```

---

## 📋 Checklist

After you complete all steps, verify:

- [ ] Service Principal created
- [ ] Key Vault permissions granted
- [ ] All secrets in Key Vault
- [ ] Program.cs updated with ClientSecretCredential
- [ ] Docker image rebuilt and pushed
- [ ] Old container deleted
- [ ] New container created with environment variables
- [ ] Container is running (not restarting)
- [ ] Health endpoint returns 200 OK
- [ ] No errors in container logs about authentication
- [ ] Function App configured with Key Vault references
- [ ] Can create items via API
- [ ] Emails are being sent

**When all boxes are checked, your deployment is complete!** 🎉

