# Getting Azure Variables for Your Pipeline

## Commands to Retrieve Each Variable

### 1. azureSubscription
```powershell
# Get your service connection name (from Azure DevOps)
# This is the name YOU created earlier
# It should be: RegistrationApp-Azure

# If you need your subscription ID:
az account show --query id -o tsv
# Result: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

**Answer:** `RegistrationApp-Azure` (from your service connection setup)

---

### 2. containerRegistry (ACR Login Server)
```powershell
# Get the ACR login server
az acr show --resource-group rg-registration-app --name registrationappacr --query loginServer -o tsv

# Result: registrationappacr.azurecr.io
```

**Command to get it:**
```powershell
az acr show --resource-group rg-registration-app --name registrationappacr --query loginServer -o tsv
```

---

### 3. dockerRegistryServiceConnection
```powershell
# This is the name YOU created in Azure DevOps
# It should be: RegistrationApp-ACR
```

**Answer:** `RegistrationApp-ACR` (from your service connection setup)

---

### 4. imageRepository
```powershell
# This is what you want to name your Docker image
# Common values:
# - registration-api
# - backend
# - registrationapp

# You can choose any name you want
# Recommended: registration-api (for backend image)
```

**Answer:** `registration-api` (or any name you prefer)

---

### 5. acrName
```powershell
# Get the ACR name
az acr list --resource-group rg-registration-app --query "[0].name" -o tsv

# Result: registrationappacr
```

**Command to get it:**
```powershell
az acr list --resource-group rg-registration-app --query "[0].name" -o tsv
```

---

### 6. appServiceName
```powershell
# Get the App Service name for backend
az webapp list --resource-group rg-registration-app --query "[?contains(name, 'api')].name" -o tsv

# Or list all App Services to find your backend
az webapp list --resource-group rg-registration-app --query "[].name" -o tsv

# Result: registration-api-2807 (or similar)
```

**Command to get it:**
```powershell
az webapp list --resource-group rg-registration-app --query "[0].name" -o tsv
```

---

### 7. staticWebAppName
```powershell
# Get the Static Web App name for frontend
az staticwebapp list --resource-group rg-registration-app --query "[].name" -o tsv

# Result: registration-frontend-2807 (or similar)
```

**Command to get it:**
```powershell
az staticwebapp list --resource-group rg-registration-app --query "[].name" -o tsv
```

---

### 8. sqlServerName
```powershell
# Get the SQL Server name
az sql server list --resource-group rg-registration-app --query "[].name" -o tsv

# Result: regsql2807 (or similar)
```

**Command to get it:**
```powershell
az sql server list --resource-group rg-registration-app --query "[].name" -o tsv
```

---

## Quick Script to Get All Variables

Run this PowerShell script to get all variables at once:

```powershell
#!/usr/bin/pwsh

$resourceGroup = "rg-registration-app"

Write-Host "=== Getting All Pipeline Variables ===" -ForegroundColor Green
Write-Host ""

# 1. Service Connection Names (from DevOps, not from Azure)
Write-Host "1. azureSubscription: RegistrationApp-Azure" -ForegroundColor Cyan
Write-Host "   (Created in Azure DevOps Service Connections)"
Write-Host ""

# 2. Container Registry
Write-Host "2. containerRegistry:" -ForegroundColor Cyan
$containerRegistry = az acr show --resource-group $resourceGroup --name registrationappacr --query loginServer -o tsv
Write-Host "   $containerRegistry"
Write-Host ""

# 3. Docker Registry Service Connection Name (from DevOps)
Write-Host "3. dockerRegistryServiceConnection: RegistrationApp-ACR" -ForegroundColor Cyan
Write-Host "   (Created in Azure DevOps Service Connections)"
Write-Host ""

# 4. Image Repository (your choice)
Write-Host "4. imageRepository: registration-api" -ForegroundColor Cyan
Write-Host "   (You can choose any name for your Docker image)"
Write-Host ""

# 5. ACR Name
Write-Host "5. acrName:" -ForegroundColor Cyan
$acrName = az acr list --resource-group $resourceGroup --query "[0].name" -o tsv
Write-Host "   $acrName"
Write-Host ""

# 6. App Service Name
Write-Host "6. appServiceName:" -ForegroundColor Cyan
$appServiceName = az webapp list --resource-group $resourceGroup --query "[0].name" -o tsv
Write-Host "   $appServiceName"
Write-Host ""

# 7. Static Web App Name
Write-Host "7. staticWebAppName:" -ForegroundColor Cyan
$staticWebAppName = az staticwebapp list --resource-group $resourceGroup --query "[0].name" -o tsv
Write-Host "   $staticWebAppName"
Write-Host ""

# 8. SQL Server Name
Write-Host "8. sqlServerName:" -ForegroundColor Cyan
$sqlServerName = az sql server list --resource-group $resourceGroup --query "[0].name" -o tsv
Write-Host "   $sqlServerName"
Write-Host ""

Write-Host "=== Copy these to your azure-pipelines.yml ===" -ForegroundColor Green
Write-Host ""
Write-Host "variables:" -ForegroundColor Yellow
Write-Host "  azureSubscription: 'RegistrationApp-Azure'" 
Write-Host "  containerRegistry: '$containerRegistry'"
Write-Host "  dockerRegistryServiceConnection: 'RegistrationApp-ACR'"
Write-Host "  imageRepository: 'registration-api'"
Write-Host "  acrName: '$acrName'"
Write-Host "  appServiceName: '$appServiceName'"
Write-Host "  staticWebAppName: '$staticWebAppName'"
Write-Host "  sqlServerName: '$sqlServerName'"
```

---

## Example: What You'll See

```
=== Getting All Pipeline Variables ===

1. azureSubscription: RegistrationApp-Azure
   (Created in Azure DevOps Service Connections)

2. containerRegistry: 
   registrationappacr.azurecr.io

3. dockerRegistryServiceConnection: RegistrationApp-ACR
   (Created in Azure DevOps Service Connections)

4. imageRepository: registration-api
   (You can choose any name for your Docker image)

5. acrName: 
   registrationappacr

6. appServiceName: 
   registration-api-2807

7. staticWebAppName: 
   registration-frontend-2807

8. sqlServerName: 
   regsql2807

=== Copy these to your azure-pipelines.yml ===

variables:
  azureSubscription: 'RegistrationApp-Azure'
  containerRegistry: 'registrationappacr.azurecr.io'
  dockerRegistryServiceConnection: 'RegistrationApp-ACR'
  imageRepository: 'registration-api'
  acrName: 'registrationappacr'
  appServiceName: 'registration-api-2807'
  staticWebAppName: 'registration-frontend-2807'
  sqlServerName: 'regsql2807'
```

---

## Summary Table

| Variable | Source | How to Get | Example |
|----------|--------|-----------|---------|
| `azureSubscription` | Azure DevOps | Service Connection name | `RegistrationApp-Azure` |
| `containerRegistry` | Azure ACR | `az acr show --query loginServer` | `registrationappacr.azurecr.io` |
| `dockerRegistryServiceConnection` | Azure DevOps | Service Connection name | `RegistrationApp-ACR` |
| `imageRepository` | Your choice | Pick any name | `registration-api` |
| `acrName` | Azure ACR | `az acr list --query [0].name` | `registrationappacr` |
| `appServiceName` | Azure App Service | `az webapp list --query [0].name` | `registration-api-2807` |
| `staticWebAppName` | Azure Static Web App | `az staticwebapp list --query [0].name` | `registration-frontend-2807` |
| `sqlServerName` | Azure SQL Server | `az sql server list --query [0].name` | `regsql2807` |

---

## Next Step

Once you have all these variables, update your `azure-pipelines.yml` file with the correct values and the pipeline will be ready to run! 🚀
