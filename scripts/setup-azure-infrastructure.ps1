# PowerShell script for Windows users
# Azure Infrastructure Setup for Registration Application

param(
    [string]$SubscriptionId = "your-subscription-id",
    [string]$ResourceGroup = "rg-registration-app",
    [string]$Location = "East US",
    [string]$SqlAdminPassword = "YourSecurePassword123!@#"
)

$ErrorActionPreference = "Stop"

Write-Host "===============================================" -ForegroundColor Green
Write-Host "Azure Infrastructure Setup" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""

# Timestamps for unique names
$timestamp = Get-Date -Format "yyyyMMddHHmmss"
$randomSuffix = Get-Random -Minimum 1000 -Maximum 9999

$sqlServerName = "regsql$randomSuffix"
$sqlDatabaseName = "RegistrationAppDb"
$sqlAdminUser = "sqladmin"
$appServicePlanName = "asp-registration-app"
$backendAppName = "registration-api-$randomSuffix"
$keyVaultName = "regsql-kv-$randomSuffix"

# Login to Azure
Write-Host "Logging in to Azure..." -ForegroundColor Yellow
az login
az account set --subscription $SubscriptionId

# Create Resource Group
Write-Host "Creating resource group: $ResourceGroup" -ForegroundColor Yellow
az group create --name $ResourceGroup --location "$Location"

# Create Key Vault
Write-Host "Creating Key Vault: $keyVaultName" -ForegroundColor Yellow
az keyvault create `
    --name $keyVaultName `
    --resource-group $ResourceGroup `
    --location "$Location"

# Create SQL Server
Write-Host "Creating SQL Server: $sqlServerName" -ForegroundColor Yellow
az sql server create `
    --resource-group $ResourceGroup `
    --name $sqlServerName `
    --location "$Location" `
    --admin-user $sqlAdminUser `
    --admin-password $SqlAdminPassword

# Configure Firewall
Write-Host "Configuring SQL Server firewall..." -ForegroundColor Yellow
az sql server firewall-rule create `
    --resource-group $ResourceGroup `
    --server $sqlServerName `
    --name "AllowAzureServices" `
    --start-ip-address 0.0.0.0 `
    --end-ip-address 0.0.0.0

# Create SQL Database
Write-Host "Creating SQL Database: $sqlDatabaseName" -ForegroundColor Yellow
az sql db create `
    --resource-group $ResourceGroup `
    --server $sqlServerName `
    --name $sqlDatabaseName `
    --edition Standard `
    --service-objective S0

# Store connection string in Key Vault
Write-Host "Storing connection string in Key Vault..." -ForegroundColor Yellow
$connectionString = "Server=tcp:${sqlServerName}.database.windows.net,1433;Initial Catalog=${sqlDatabaseName};Persist Security Info=False;User ID=${sqlAdminUser};Password=${SqlAdminPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

az keyvault secret set `
    --vault-name $keyVaultName `
    --name "DbConnectionString" `
    --value $connectionString

# Create App Service Plan
Write-Host "Creating App Service Plan: $appServicePlanName" -ForegroundColor Yellow
az appservice plan create `
    --name $appServicePlanName `
    --resource-group $ResourceGroup `
    --sku B1 `
    --is-linux

# Create Backend Web App
Write-Host "Creating Backend Web App: $backendAppName" -ForegroundColor Yellow
az webapp create `
    --resource-group $ResourceGroup `
    --plan $appServicePlanName `
    --name $backendAppName `
    --runtime "DOTNETCORE:8.0"

# Configure connection string
Write-Host "Configuring Backend connection string..." -ForegroundColor Yellow
az webapp config connection-string set `
    --name $backendAppName `
    --resource-group $ResourceGroup `
    --connection-string-type SQLAzure `
    --settings DefaultConnection=$connectionString

# Enable HTTPS only
az webapp update `
    --name $backendAppName `
    --resource-group $ResourceGroup `
    --https-only true

# Summary
Write-Host ""
Write-Host "===============================================" -ForegroundColor Green
Write-Host "Infrastructure Setup Complete!" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Resource Group: $ResourceGroup"
Write-Host "SQL Server: $sqlServerName.database.windows.net"
Write-Host "SQL Database: $sqlDatabaseName"
Write-Host "Backend App: https://${backendAppName}.azurewebsites.net"
Write-Host "Key Vault: $keyVaultName"
Write-Host ""
Write-Host "Save these values for future reference!" -ForegroundColor Yellow
