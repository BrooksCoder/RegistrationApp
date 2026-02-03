# Get All Pipeline Variables - Complete Command

## One Command to Get Everything

Copy and paste this entire PowerShell script:

```powershell
#!/usr/bin/pwsh

$resourceGroup = "rg-registration-app"

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "AZURE PIPELINE VARIABLES" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-Host "variables:" -ForegroundColor Yellow
Write-Host "  buildConfiguration: 'Release'" 
Write-Host "  nodeVersion: '18.x'" 
Write-Host "  dotnetVersion: '8.x'" 
Write-Host ""

# From Azure DevOps (you already created these)
Write-Host "  # Service Connections (from Azure DevOps)" -ForegroundColor Cyan
Write-Host "  azureSubscription: 'RegistrationApp-Azure'"
Write-Host "  dockerRegistryServiceConnection: 'RegistrationApp-ACR'"
Write-Host ""

# From Azure Resources
Write-Host "  # Azure Resources" -ForegroundColor Cyan
Write-Host "  resourceGroupName: '$resourceGroup'"
Write-Host ""

# Get Container Registry
Write-Host "  # Getting Container Registry..." -ForegroundColor Gray
try {
  $containerRegistry = az acr show --resource-group $resourceGroup --name registrationappacr --query loginServer -o tsv
  Write-Host "  containerRegistry: '$containerRegistry'"
} catch {
  Write-Host "  containerRegistry: 'registrationappacr.azurecr.io' # (Get from ACR manually if command fails)"
}

# Get ACR Name
Write-Host ""
Write-Host "  # Getting ACR Name..." -ForegroundColor Gray
try {
  $acrName = az acr list --resource-group $resourceGroup --query "[0].name" -o tsv
  Write-Host "  acrName: '$acrName'"
} catch {
  Write-Host "  acrName: 'registrationappacr' # (Check manually)"
}

# Image Repository (user choice)
Write-Host ""
Write-Host "  # Image Repository (your choice)" -ForegroundColor Cyan
Write-Host "  imageRepository: 'registration-api'"
Write-Host ""

# Get App Service Name
Write-Host "  # Getting App Service Name..." -ForegroundColor Gray
try {
  $appServiceName = az webapp list --resource-group $resourceGroup --query "[0].name" -o tsv
  if (-not $appServiceName) {
    Write-Host "  appServiceName: 'registration-api-2807' # (Not found - create it first)"
  } else {
    Write-Host "  appServiceName: '$appServiceName'"
  }
} catch {
  Write-Host "  appServiceName: 'registration-api-2807' # (Error getting - check manually)"
}

# Get Static Web App Name
Write-Host ""
Write-Host "  # Getting Static Web App Name..." -ForegroundColor Gray
try {
  $staticWebAppName = az staticwebapp list --resource-group $resourceGroup --query "[0].name" -o tsv
  if (-not $staticWebAppName) {
    Write-Host "  staticWebAppName: 'registration-frontend-2807' # (Not found - create it first)"
  } else {
    Write-Host "  staticWebAppName: '$staticWebAppName'"
  }
} catch {
  Write-Host "  staticWebAppName: 'registration-frontend-2807' # (Error getting - check manually)"
}

# Get SQL Server Name
Write-Host ""
Write-Host "  # Getting SQL Server Name..." -ForegroundColor Gray
try {
  $sqlServerName = az sql server list --resource-group $resourceGroup --query "[0].name" -o tsv
  if (-not $sqlServerName) {
    Write-Host "  sqlServerName: 'regsql2807' # (Not found - create it first)"
  } else {
    Write-Host "  sqlServerName: '$sqlServerName'"
  }
} catch {
  Write-Host "  sqlServerName: 'regsql2807' # (Error getting - check manually)"
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Copy the output above to azure-pipelines.yml" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green
```

---

## How to Run It

### Step 1: Open PowerShell
```powershell
# Or PowerShell Core (pwsh)
pwsh
```

### Step 2: Make Sure You're Logged In
```powershell
az login
az account show
```

### Step 3: Copy & Paste the Script

Copy the entire script above and paste it into PowerShell.

### Step 4: Press Enter

The script will output all your variables in the correct format!

---

## Alternative: Simpler Individual Commands

If you want to get each value separately:

```powershell
# Container Registry URL
az acr show --resource-group rg-registration-app --name registrationappacr --query loginServer -o tsv

# ACR Name
az acr list --resource-group rg-registration-app --query "[0].name" -o tsv

# App Service Name
az webapp list --resource-group rg-registration-app --query "[0].name" -o tsv

# Static Web App Name
az staticwebapp list --resource-group rg-registration-app --query "[0].name" -o tsv

# SQL Server Name
az sql server list --resource-group rg-registration-app --query "[0].name" -o tsv
```

---

## Expected Output

When you run the script, you'll see:

```
========================================
AZURE PIPELINE VARIABLES
========================================

variables:
  buildConfiguration: 'Release'
  nodeVersion: '18.x'
  dotnetVersion: '8.x'

  # Service Connections (from Azure DevOps)
  azureSubscription: 'RegistrationApp-Azure'
  dockerRegistryServiceConnection: 'RegistrationApp-ACR'

  # Azure Resources
  resourceGroupName: 'rg-registration-app'

  # Getting Container Registry...
  containerRegistry: 'registrationappacr.azurecr.io'

  # Getting ACR Name...
  acrName: 'registrationappacr'

  # Image Repository (your choice)
  imageRepository: 'registration-api'

  # Getting App Service Name...
  appServiceName: 'registration-api-2807'

  # Getting Static Web App Name...
  staticWebAppName: 'registration-frontend-2807'

  # Getting SQL Server Name...
  sqlServerName: 'regsql2807'

========================================
Copy the output above to azure-pipelines.yml
========================================
```

---

## Then Copy to Your Pipeline

1. Copy the output above
2. Open `azure-pipelines.yml`
3. Replace the variables section with the output
4. Save and commit
5. Push to main
6. Pipeline runs automatically! 🚀

---

## If Resources Don't Exist

If you get "Not found" errors, create them first:

```powershell
# Create App Service Plan
az appservice plan create --name "registration-api-plan-2807" --resource-group rg-registration-app --location eastus --sku B2 --is-linux

# Create App Service
az webapp create --name "registration-api-2807" --resource-group rg-registration-app --plan "registration-api-plan-2807" --runtime "DOTNET|8.0"

# Create Static Web App
az staticwebapp create --name "registration-frontend-2807" --resource-group rg-registration-app --location eastus --sku Free

# Create SQL Server
az sql server create --name "regsql2807" --resource-group rg-registration-app --location eastus --admin-user "sqladmin" --admin-password "YourSecurePassword123!@#"

# Create SQL Database
az sql db create --name "RegistrationAppDb" --server "regsql2807" --resource-group rg-registration-app --sku Basic
```

Then run the variable script again!

---

## Troubleshooting

### Command not found
```powershell
# Make sure Azure CLI is installed
az --version

# If not installed:
# Windows: choco install azure-cli
# Or download: https://aka.ms/azcliinstall
```

### "The subscription is not registered"
```powershell
# Register required providers
az provider register --namespace Microsoft.Web
az provider register --namespace Microsoft.Sql
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.ContainerRegistry
```

### Still getting empty results
```powershell
# Verify you're in the right subscription
az account show --query "{Name:name, Id:id}"

# List all resources to see what exists
az resource list --resource-group rg-registration-app --output table
```

---

## Quick Copy-Paste Template

Once you have all values, here's the template:

```yaml
variables:
  buildConfiguration: 'Release'
  nodeVersion: '18.x'
  dotnetVersion: '8.x'
  azureSubscription: 'RegistrationApp-Azure'
  containerRegistry: 'registrationappacr.azurecr.io'  # ← Replace with your value
  dockerRegistryServiceConnection: 'RegistrationApp-ACR'
  imageRepository: 'registration-api'
  acrName: 'registrationappacr'  # ← Replace with your value
  appServiceName: 'registration-api-2807'  # ← Replace with your value
  staticWebAppName: 'registration-frontend-2807'  # ← Replace with your value
  sqlServerName: 'regsql2807'  # ← Replace with your value
  resourceGroupName: 'rg-registration-app'
```

Replace values marked with arrows and you're done! ✅
