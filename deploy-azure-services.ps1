#!/usr/bin/env pwsh
# Azure Functions & Logic Apps Interactive Deployment Script
# Usage: .\deploy-azure-services.ps1

param(
    [switch]$SkipFunctions,
    [switch]$SkipLogicApps,
    [switch]$OnlyFunctions,
    [switch]$OnlyLogicApps
)

# Color functions
function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║ $Text" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Section {
    param([string]$Text)
    Write-Host ""
    Write-Host "━━━ $Text ━━━" -ForegroundColor Yellow
}

function Write-Step {
    param([string]$Text, [int]$Step = 0)
    if ($Step -gt 0) {
        Write-Host "[$Step] " -ForegroundColor Cyan -NoNewline
    }
    Write-Host $Text -ForegroundColor White
}

function Write-Success {
    param([string]$Text)
    Write-Host "✅ " -ForegroundColor Green -NoNewline
    Write-Host $Text -ForegroundColor Green
}

function Write-Error {
    param([string]$Text)
    Write-Host "❌ " -ForegroundColor Red -NoNewline
    Write-Host $Text -ForegroundColor Red
}

function Write-Info {
    param([string]$Text)
    Write-Host "ℹ️  " -ForegroundColor Blue -NoNewline
    Write-Host $Text -ForegroundColor Blue
}

# Initialize variables
$resourceGroup = "rg-registration-app"
$subscriptionId = "af300fa3-a715-4320-8558-efe8a549457e"
$keyVaultName = "kv-registrationapp"
$location = "eastus"
$functionAppName = "func-registrationapp"
$functionStorageName = "stregistrationappfunc"
$logicAppName = "logic-item-approval-workflow"
$logicStorageName = "stlogicappstorage"

Write-Header "AZURE FUNCTIONS & LOGIC APPS DEPLOYMENT"

# Determine what to deploy
$deployFunctions = -not $SkipFunctions -and -not $OnlyLogicApps
$deployLogicApps = -not $SkipLogicApps -and -not $OnlyFunctions

if (-not $deployFunctions -and -not $deployLogicApps) {
    Write-Error "No services selected for deployment. Use -OnlyFunctions or -OnlyLogicApps"
    exit 1
}

Write-Step "Deployment Options:"
Write-Info "Functions: $(if ($deployFunctions) { 'YES ✅' } else { 'NO ⏭️' })"
Write-Info "Logic Apps: $(if ($deployLogicApps) { 'YES ✅' } else { 'NO ⏭️' })"

# Set subscription
Write-Section "Setting Azure Context"
Write-Step "Setting subscription context..." 1
try {
    az account set --subscription $subscriptionId | Out-Null
    Write-Success "Subscription context set"
} catch {
    Write-Error "Failed to set subscription: $_"
    exit 1
}

# Get connection strings from Key Vault
Write-Section "Retrieving Connection Strings from Key Vault"
Write-Step "Fetching connection strings..." 1
try {
    $sbConnStr = az keyvault secret show --vault-name $keyVaultName --name "ServiceBusConnectionString" --query value -o tsv 2>$null
    $cosmosConnStr = az keyvault secret show --vault-name $keyVaultName --name "CosmosDbConnectionString" --query value -o tsv 2>$null
    $storageConnStr = az keyvault secret show --vault-name $keyVaultName --name "StorageAccountConnectionString" --query value -o tsv 2>$null
    
    if ($sbConnStr -and $cosmosConnStr -and $storageConnStr) {
        Write-Success "All connection strings retrieved"
    } else {
        Write-Error "Some connection strings are missing"
        exit 1
    }
} catch {
    Write-Error "Failed to retrieve connection strings: $_"
    exit 1
}

# Deploy Azure Functions
if ($deployFunctions) {
    Write-Header "DEPLOYING AZURE FUNCTIONS"
    
    # Step 1: Create Storage Account
    Write-Section "Step 1: Storage Account Setup"
    Write-Step "Creating storage account: $functionStorageName" 1
    try {
        $storageCheck = az storage account show --name $functionStorageName --resource-group $resourceGroup 2>$null
        if ($storageCheck) {
            Write-Info "Storage account already exists"
        } else {
            az storage account create `
              --name $functionStorageName `
              --resource-group $resourceGroup `
              --location $location `
              --sku Standard_LRS `
              --kind StorageV2 | Out-Null
            Write-Success "Storage account created"
        }
    } catch {
        Write-Error "Failed to create storage account: $_"
    }
    
    # Step 2: Create Function App
    Write-Section "Step 2: Function App Creation"
    Write-Step "Creating Function App: $functionAppName" 1
    try {
        $functionCheck = az functionapp show --name $functionAppName --resource-group $resourceGroup 2>$null
        if ($functionCheck) {
            Write-Info "Function App already exists"
        } else {
            az functionapp create `
              --resource-group $resourceGroup `
              --consumption-plan-location $location `
              --runtime dotnet-isolated `
              --runtime-version 8.0 `
              --functions-version 4 `
              --name $functionAppName `
              --storage-account $functionStorageName `
              --os-type Windows | Out-Null
            Write-Success "Function App created"
            Start-Sleep -Seconds 5
        }
    } catch {
        Write-Error "Failed to create Function App: $_"
    }
    
    # Step 3: Configure App Settings
    Write-Section "Step 3: Function App Configuration"
    Write-Step "Configuring app settings..." 1
    try {
        az functionapp config appsettings set `
          --name $functionAppName `
          --resource-group $resourceGroup `
          --settings `
            AzureWebJobsServiceBusConnectionString=$sbConnStr `
            CosmosDbConnectionString=$cosmosConnStr `
            StorageAccountConnectionString=$storageConnStr `
            FUNCTIONS_WORKER_RUNTIME=dotnet-isolated `
            ASPNETCORE_ENVIRONMENT=Production | Out-Null
        Write-Success "App settings configured"
    } catch {
        Write-Error "Failed to configure app settings: $_"
    }
    
    # Display Function App info
    Write-Section "Function App Deployment Summary"
    $funcInfo = az functionapp show `
      --name $functionAppName `
      --resource-group $resourceGroup `
      --query "{name:name, state:state, location:location, runtime:'dotnet-isolated'}" 2>$null
    
    if ($funcInfo) {
        Write-Host $funcInfo | ConvertFrom-Json | Format-Table -AutoSize
        Write-Success "Function App ready for functions"
    }
}

# Deploy Azure Logic Apps
if ($deployLogicApps) {
    Write-Header "DEPLOYING AZURE LOGIC APPS"
    
    # Step 1: Create Storage Account
    Write-Section "Step 1: Storage Account Setup"
    Write-Step "Creating storage account: $logicStorageName" 1
    try {
        $storageCheck = az storage account show --name $logicStorageName --resource-group $resourceGroup 2>$null
        if ($storageCheck) {
            Write-Info "Storage account already exists"
        } else {
            az storage account create `
              --name $logicStorageName `
              --resource-group $resourceGroup `
              --location $location `
              --sku Standard_LRS `
              --kind StorageV2 | Out-Null
            Write-Success "Storage account created"
        }
    } catch {
        Write-Error "Failed to create storage account: $_"
    }
    
    # Step 2: Create Logic App
    Write-Section "Step 2: Logic App Creation"
    Write-Step "Creating Logic App: $logicAppName" 1
    try {
        $logicCheck = az logic workflow show --name $logicAppName --resource-group $resourceGroup 2>$null
        if ($logicCheck) {
            Write-Info "Logic App already exists"
        } else {
            az logic workflow create `
              --resource-group $resourceGroup `
              --location $location `
              --name $logicAppName | Out-Null
            Write-Success "Logic App created"
        }
    } catch {
        Write-Error "Failed to create Logic App: $_"
    }
    
    # Display Logic App info
    Write-Section "Logic App Deployment Summary"
    $logicInfo = az logic workflow show `
      --name $logicAppName `
      --resource-group $resourceGroup `
      --query "{name:name, state:properties.state, location:location}" 2>$null
    
    if ($logicInfo) {
        Write-Host $logicInfo | ConvertFrom-Json | Format-Table -AutoSize
        Write-Success "Logic App created - Ready for configuration in Azure Portal"
    }
}

# Final Summary
Write-Header "DEPLOYMENT COMPLETE"

Write-Section "Portal Links"
Write-Info "Subscription ID: $subscriptionId"
Write-Info "Resource Group: $resourceGroup"
Write-Info "Location: $location"
Write-Host ""

if ($deployFunctions) {
    Write-Host "📘 Function App:" -ForegroundColor Yellow
    Write-Host "https://portal.azure.com/#resource/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Web/sites/$functionAppName" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Next Steps for Functions:" -ForegroundColor White
    Write-Host "  1. Create function locally: func new --name SendEmailNotification --template 'Service Bus Queue trigger'" -ForegroundColor Gray
    Write-Host "  2. Update function code to handle notifications" -ForegroundColor Gray
    Write-Host "  3. Deploy: func azure functionapp publish $functionAppName" -ForegroundColor Gray
    Write-Host ""
}

if ($deployLogicApps) {
    Write-Host "📗 Logic App:" -ForegroundColor Yellow
    Write-Host "https://portal.azure.com/#resource/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Logic/workflows/$logicAppName" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Next Steps for Logic Apps:" -ForegroundColor White
    Write-Host "  1. Open Logic App Designer in Azure Portal" -ForegroundColor Gray
    Write-Host "  2. Add SQL trigger: When a row is inserted in Items table" -ForegroundColor Gray
    Write-Host "  3. Add actions: Send emails, create blobs, log to Cosmos" -ForegroundColor Gray
    Write-Host "  4. Test with sample data" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "📊 All Resources:" -ForegroundColor Yellow
Write-Host "https://portal.azure.com/#resource/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/overview" -ForegroundColor Cyan
Write-Host ""

Write-Section "Commands for Testing"
Write-Host "# Test Function App:" -ForegroundColor White
Write-Host "az functionapp function list --name $functionAppName --resource-group $resourceGroup" -ForegroundColor Gray
Write-Host ""
Write-Host "# Test Logic App:" -ForegroundColor White
Write-Host "az logic workflow show --name $logicAppName --resource-group $resourceGroup --query 'properties.state'" -ForegroundColor Gray
Write-Host ""

Write-Success "All services deployed successfully!"
