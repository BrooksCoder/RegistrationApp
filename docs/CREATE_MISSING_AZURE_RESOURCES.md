# Create Missing Azure Resources

Your resource group has:
✅ Key Vault: `regsql-kv-2807`
✅ Container Registry: `registrationappacr`

❌ Missing:
- App Service Plan
- App Service (Backend API)
- Static Web App (Frontend)
- SQL Server & Database
- App Service for database migrations

---

## Create All Missing Resources

Run this PowerShell script to create everything:

```powershell
# Set variables
$resourceGroup = "rg-registration-app"
$location = "eastus"
$suffix = "2807"

Write-Host "Creating missing Azure resources..." -ForegroundColor Green

# 1. Create App Service Plan
Write-Host "`n1. Creating App Service Plan..." -ForegroundColor Cyan
az appservice plan create `
  --name "registration-api-plan-$suffix" `
  --resource-group $resourceGroup `
  --location $location `
  --sku B2 `
  --is-linux

Write-Host "✅ App Service Plan created" -ForegroundColor Green

# 2. Create App Service for Backend
Write-Host "`n2. Creating App Service for Backend..." -ForegroundColor Cyan
az webapp create `
  --name "registration-api-$suffix" `
  --resource-group $resourceGroup `
  --plan "registration-api-plan-$suffix" `
  --runtime "DOTNET|8.0" `
  --deployment-local-git

Write-Host "✅ App Service created: registration-api-$suffix" -ForegroundColor Green

# 3. Create Static Web App for Frontend
Write-Host "`n3. Creating Static Web App for Frontend..." -ForegroundColor Cyan
az staticwebapp create `
  --name "registration-frontend-$suffix" `
  --resource-group $resourceGroup `
  --location $location `
  --sku Free

Write-Host "✅ Static Web App created: registration-frontend-$suffix" -ForegroundColor Green

# 4. Create SQL Server
Write-Host "`n4. Creating SQL Server..." -ForegroundColor Cyan
az sql server create `
  --name "regsql$suffix" `
  --resource-group $resourceGroup `
  --location $location `
  --admin-user "sqladmin" `
  --admin-password "YourSecurePassword123!@#"

Write-Host "✅ SQL Server created: regsql$suffix" -ForegroundColor Green

# 5. Create SQL Database
Write-Host "`n5. Creating SQL Database..." -ForegroundColor Cyan
az sql db create `
  --name "RegistrationAppDb" `
  --server "regsql$suffix" `
  --resource-group $resourceGroup `
  --sku Basic

Write-Host "✅ SQL Database created: RegistrationAppDb" -ForegroundColor Green

# 6. Configure SQL Server Firewall
Write-Host "`n6. Configuring SQL Server Firewall..." -ForegroundColor Cyan
az sql server firewall-rule create `
  --resource-group $resourceGroup `
  --server "regsql$suffix" `
  --name "AllowAzureServices" `
  --start-ip-address 0.0.0.0 `
  --end-ip-address 0.0.0.0

Write-Host "✅ Firewall rule created for Azure services" -ForegroundColor Green

# 7. Configure App Service settings
Write-Host "`n7. Configuring App Service..." -ForegroundColor Cyan
$connectionString = "Server=tcp:regsql$suffix.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourSecurePassword123!@#;MultipleActiveResultSets=False;Encrypt=True;Connection Timeout=30;"

az webapp config appsettings set `
  --resource-group $resourceGroup `
  --name "registration-api-$suffix" `
  --settings `
    ConnectionStrings__DefaultConnection="$connectionString" `
    ASPNETCORE_ENVIRONMENT="Production"

Write-Host "✅ App Service configured" -ForegroundColor Green

# 8. Enable Container Registry access
Write-Host "`n8. Enabling Container Registry access..." -ForegroundColor Cyan
$acrUrl = az acr show --resource-group $resourceGroup --name registrationappacr --query loginServer -o tsv
$acrUser = az acr credential show --resource-group $resourceGroup --name registrationappacr --query username -o tsv
$acrPassword = az acr credential show --resource-group $resourceGroup --name registrationappacr --query "passwords[0].value" -o tsv

az webapp config container set `
  --name "registration-api-$suffix" `
  --resource-group $resourceGroup `
  --docker-custom-image-name "$acrUrl/registration-api:latest" `
  --docker-registry-server-url "https://$acrUrl" `
  --docker-registry-server-user $acrUser `
  --docker-registry-server-password $acrPassword

Write-Host "✅ Container Registry configured" -ForegroundColor Green

Write-Host "`n=== All Resources Created Successfully ===" -ForegroundColor Green
Write-Host "`nYour Resources:" -ForegroundColor Yellow
Write-Host "  Backend App Service: registration-api-$suffix"
Write-Host "  Frontend Static Web App: registration-frontend-$suffix"
Write-Host "  SQL Server: regsql$suffix.database.windows.net"
Write-Host "  SQL Database: RegistrationAppDb"
Write-Host "  Container Registry: $acrUrl"
```

---

## Step-by-Step: Run the Script

### Option 1: Copy & Paste into PowerShell

1. Open PowerShell
2. Run: `az login` (if not already logged in)
3. Copy the entire script above
4. Paste into PowerShell
5. Press Enter and wait for completion

### Option 2: Save as Script File

```powershell
# Create script file
@"
# Set variables
`$resourceGroup = "rg-registration-app"
`$location = "eastus"
`$suffix = "2807"

Write-Host "Creating missing Azure resources..." -ForegroundColor Green

# 1. Create App Service Plan
Write-Host "`n1. Creating App Service Plan..." -ForegroundColor Cyan
az appservice plan create `
  --name "registration-api-plan-`$suffix" `
  --resource-group `$resourceGroup `
  --location `$location `
  --sku B2 `
  --is-linux

Write-Host "✅ App Service Plan created" -ForegroundColor Green

# ... rest of script
"@ | Set-Content create-resources.ps1

# Run the script
.\create-resources.ps1
```

---

## What Gets Created

```
Resource Group: rg-registration-app
├── App Service Plan: registration-api-plan-2807
├── App Service: registration-api-2807
│   └── Runtime: .NET 8
│   └── Plan: Linux B2
├── Static Web App: registration-frontend-2807
├── SQL Server: regsql2807.database.windows.net
│   └── Database: RegistrationAppDb
├── Container Registry: registrationappacr.azurecr.io (already exists)
└── Key Vault: regsql-kv-2807 (already exists)
```

---

## Expected Output

```
Creating missing Azure resources...

1. Creating App Service Plan...
✅ App Service Plan created

2. Creating App Service for Backend...
✅ App Service created: registration-api-2807

3. Creating Static Web App for Frontend...
✅ Static Web App created: registration-frontend-2807

4. Creating SQL Server...
✅ SQL Server created: regsql2807

5. Creating SQL Database...
✅ SQL Database created: RegistrationAppDb

6. Configuring SQL Server Firewall...
✅ Firewall rule created for Azure services

7. Configuring App Service...
✅ App Service configured

8. Enabling Container Registry access...
✅ Container Registry configured

=== All Resources Created Successfully ===

Your Resources:
  Backend App Service: registration-api-2807
  Frontend Static Web App: registration-frontend-2807
  SQL Server: regsql2807.database.windows.net
  SQL Database: RegistrationAppDb
  Container Registry: registrationappacr.azurecr.io
```

---

## After Script Completes

Verify everything was created:

```powershell
# List all resources
az resource list --resource-group rg-registration-app --output table

# Test getting App Service name
az webapp list --resource-group rg-registration-app --query "[].name" -o tsv

# Test getting Static Web App
az staticwebapp list --resource-group rg-registration-app --query "[].name" -o tsv

# Test getting SQL Server
az sql server list --resource-group rg-registration-app --query "[].name" -o tsv
```

---

## Then Update Your Pipeline Variables

Once created, get the exact names:

```powershell
$appServiceName = az webapp list --resource-group rg-registration-app --query "[0].name" -o tsv
$staticWebAppName = az staticwebapp list --resource-group rg-registration-app --query "[0].name" -o tsv
$sqlServerName = az sql server list --resource-group rg-registration-app --query "[0].name" -o tsv
$acrName = az acr list --resource-group rg-registration-app --query "[0].name" -o tsv

Write-Host "appServiceName: $appServiceName"
Write-Host "staticWebAppName: $staticWebAppName"
Write-Host "sqlServerName: $sqlServerName"
Write-Host "acrName: $acrName"
```

Copy these values into `azure-pipelines.yml`.

---

## Troubleshooting

### Error: "The subscription is not registered to use namespace"
```powershell
# Register required providers
az provider register --namespace Microsoft.Web
az provider register --namespace Microsoft.Sql
az provider register --namespace Microsoft.App
```

### Error: "Invalid location"
```powershell
# List valid locations
az account list-locations --query "[].name" -o table

# Use a valid one (e.g., eastus, westus2, etc.)
```

### Error: "Resource already exists"
```powershell
# It's fine! Skip that resource and continue
# Or delete the resource first:
az webapp delete --name registration-api-2807 --resource-group rg-registration-app
```

---

## Next Steps

1. ✅ Run the script to create resources
2. ✅ Verify resources created
3. ✅ Get exact resource names
4. ✅ Update `azure-pipelines.yml` variables
5. ✅ Push to repo
6. ✅ Pipeline runs automatically 🚀
