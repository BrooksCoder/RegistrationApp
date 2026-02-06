# Quick Reference: Azure Functions & Logic Apps Deployment Commands

## Variables to Set First

```powershell
$resourceGroup = "rg-registration-app"
$subscriptionId = "af300fa3-a715-4320-8558-efe8a549457e"
$keyVaultName = "kv-registrationapp"
$location = "eastus"

# Set subscription context
az account set --subscription $subscriptionId
```

---

## AZURE FUNCTIONS - QUICK DEPLOY

### 1. One-Line Function App Creation

```powershell
$functionAppName = "func-registrationapp"
$functionStorageName = "stregistrationappfunc"

# Create storage account
az storage account create `
  --name $functionStorageName `
  --resource-group $resourceGroup `
  --location $location `
  --sku Standard_LRS `
  --kind StorageV2

# Create Function App
az functionapp create `
  --resource-group $resourceGroup `
  --consumption-plan-location $location `
  --runtime dotnet-isolated `
  --runtime-version 8.0 `
  --functions-version 4 `
  --name $functionAppName `
  --storage-account $functionStorageName `
  --os-type Windows
```

### 2. Configure App Settings (Connection Strings)

```powershell
$functionAppName = "func-registrationapp"

# Get connection strings from Key Vault
$sbConnStr = az keyvault secret show --vault-name $keyVaultName --name "ServiceBusConnectionString" --query value -o tsv
$cosmosConnStr = az keyvault secret show --vault-name $keyVaultName --name "CosmosDbConnectionString" --query value -o tsv
$storageConnStr = az keyvault secret show --vault-name $keyVaultName --name "StorageAccountConnectionString" --query value -o tsv

# Set app settings
az functionapp config appsettings set `
  --name $functionAppName `
  --resource-group $resourceGroup `
  --settings `
    AzureWebJobsServiceBusConnectionString=$sbConnStr `
    CosmosDbConnectionString=$cosmosConnStr `
    StorageAccountConnectionString=$storageConnStr `
    FUNCTIONS_WORKER_RUNTIME=dotnet-isolated `
    ASPNETCORE_ENVIRONMENT=Production
```

### 3. Create Function Locally

```powershell
# Create project directory
$projectPath = "C:\Users\Admin\source\repos\RegistrationApp\azure-functions"
New-Item -ItemType Directory -Path $projectPath -Force | Out-Null
Set-Location $projectPath

# Initialize project
func init . --dotnet --worker-runtime dotnet-isolated

# Create Service Bus triggered function
func new --name SendEmailNotification --template "Service Bus Queue trigger"

# Build
dotnet build

# Test locally
func start
```

### 4. Deploy Function to Azure

```powershell
$functionAppName = "func-registrationapp"

Set-Location "C:\Users\Admin\source\repos\RegistrationApp\azure-functions"

# Publish
func azure functionapp publish $functionAppName

# Verify
az functionapp function show `
  --name $functionAppName `
  --resource-group $resourceGroup `
  --function-name SendEmailNotification
```

### 5. Test Function

```powershell
$serviceBusName = "sb-registrationapp-eastus"

# Send test message to Service Bus
az servicebus queue send `
  --resource-group $resourceGroup `
  --namespace-name $serviceBusName `
  --queue-name "email-notifications-queue" `
  --message-body '{
    "itemId": "1",
    "itemName": "Test Item",
    "action": "Created",
    "timestamp": "'$(Get-Date -Format 'o')'"
  }'

# View logs
az webapp log tail `
  --name $functionAppName `
  --resource-group $resourceGroup
```

### 6. Monitor Function

```powershell
$functionAppName = "func-registrationapp"

# List all runs
az functionapp function show `
  --name $functionAppName `
  --resource-group $resourceGroup

# View all function apps
az functionapp list --resource-group $resourceGroup -o table

# Check function app status
az functionapp show `
  --name $functionAppName `
  --resource-group $resourceGroup `
  --query "{name:name, state:state, location:location}"
```

---

## AZURE LOGIC APPS - QUICK DEPLOY

### 1. Create Storage Account for Logic Apps

```powershell
$logicStorageName = "stlogicappstorage"

az storage account create `
  --name $logicStorageName `
  --resource-group $resourceGroup `
  --location $location `
  --sku Standard_LRS `
  --kind StorageV2
```

### 2. Create Logic App Workflow

```powershell
$logicAppName = "logic-item-approval-workflow"

az logic workflow create `
  --resource-group $resourceGroup `
  --location $location `
  --name $logicAppName
```

### 3. Get Logic App Details

```powershell
$logicAppName = "logic-item-approval-workflow"

# Show basic info
az logic workflow show `
  --name $logicAppName `
  --resource-group $resourceGroup `
  --query "{name:name, state:properties.state, location:location}"

# Show full definition
az logic workflow show `
  --name $logicAppName `
  --resource-group $resourceGroup `
  --query "properties.definition"
```

### 4. Update Logic App Definition

```powershell
$logicAppName = "logic-item-approval-workflow"
$definitionFile = "C:\path\to\logic-app-definition.json"

# Update the workflow
az logic workflow update `
  --resource-group $resourceGroup `
  --name $logicAppName `
  --definition $definitionFile
```

### 5. Enable/Disable Logic App

```powershell
$logicAppName = "logic-item-approval-workflow"

# Enable
az logic workflow update `
  --name $logicAppName `
  --resource-group $resourceGroup `
  --set "properties.state=Enabled"

# Disable
az logic workflow update `
  --name $logicAppName `
  --resource-group $resourceGroup `
  --set "properties.state=Disabled"

# Check state
az logic workflow show `
  --name $logicAppName `
  --resource-group $resourceGroup `
  --query "properties.state"
```

### 6. View Logic App Runs

```powershell
$logicAppName = "logic-item-approval-workflow"

# List all runs
az logic workflow run list `
  --name $logicAppName `
  --resource-group $resourceGroup `
  --query "[].{name:name, status:properties.status, startTime:properties.startTime}" `
  -o table

# Get latest run details
$latestRun = az logic workflow run list `
  --name $logicAppName `
  --resource-group $resourceGroup `
  --query "[0].name" -o tsv

az logic workflow run show `
  --name $logicAppName `
  --resource-group $resourceGroup `
  --run-name $latestRun
```

### 7. List All Connections

```powershell
# All connections in resource group
az connection list --resource-group $resourceGroup -o table

# Specific connection details
az connection show `
  --name "sql" `
  --resource-group $resourceGroup
```

### 8. Delete Logic App (if needed)

```powershell
$logicAppName = "logic-item-approval-workflow"

az logic workflow delete `
  --name $logicAppName `
  --resource-group $resourceGroup

# Confirm deletion
az logic workflow list --resource-group $resourceGroup -o table
```

---

## COMPLETE ONE-COMMAND DEPLOYMENT

### Deploy Everything

```powershell
# Set all variables
$resourceGroup = "rg-registration-app"
$subscriptionId = "af300fa3-a715-4320-8558-efe8a549457e"
$keyVaultName = "kv-registrationapp"
$location = "eastus"
$functionAppName = "func-registrationapp"
$functionStorageName = "stregistrationappfunc"
$logicAppName = "logic-item-approval-workflow"
$logicStorageName = "stlogicappstorage"

# Set subscription
az account set --subscription $subscriptionId

# Create storages
az storage account create --name $functionStorageName --resource-group $resourceGroup --location $location --sku Standard_LRS --kind StorageV2 2>$null
az storage account create --name $logicStorageName --resource-group $resourceGroup --location $location --sku Standard_LRS --kind StorageV2 2>$null

# Get connection strings
$sbConnStr = az keyvault secret show --vault-name $keyVaultName --name "ServiceBusConnectionString" --query value -o tsv
$cosmosConnStr = az keyvault secret show --vault-name $keyVaultName --name "CosmosDbConnectionString" --query value -o tsv
$storageConnStr = az keyvault secret show --vault-name $keyVaultName --name "StorageAccountConnectionString" --query value -o tsv

# Create Function App
az functionapp create --resource-group $resourceGroup --consumption-plan-location $location --runtime dotnet-isolated --runtime-version 8.0 --functions-version 4 --name $functionAppName --storage-account $functionStorageName --os-type Windows 2>$null

# Configure Function App
az functionapp config appsettings set --name $functionAppName --resource-group $resourceGroup --settings AzureWebJobsServiceBusConnectionString=$sbConnStr CosmosDbConnectionString=$cosmosConnStr StorageAccountConnectionString=$storageConnStr FUNCTIONS_WORKER_RUNTIME=dotnet-isolated ASPNETCORE_ENVIRONMENT=Production

# Create Logic App
az logic workflow create --resource-group $resourceGroup --location $location --name $logicAppName 2>$null

Write-Host "✅ Functions and Logic Apps deployment complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Function App: $functionAppName" -ForegroundColor Cyan
Write-Host "Portal: https://portal.azure.com/#resource/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Web/sites/$functionAppName" -ForegroundColor Cyan
Write-Host ""
Write-Host "Logic App: $logicAppName" -ForegroundColor Cyan
Write-Host "Portal: https://portal.azure.com/#resource/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Logic/workflows/$logicAppName" -ForegroundColor Cyan
```

---

## TESTING COMMANDS

### Test Service Bus Queue

```powershell
$serviceBusName = "sb-registrationapp-eastus"

# Send message
az servicebus queue send `
  --resource-group $resourceGroup `
  --namespace-name $serviceBusName `
  --queue-name "email-notifications-queue" `
  --message-body '{"itemId":"1","itemName":"Test","action":"Created"}'

# Check queue status
az servicebus queue show-runtime-properties `
  --resource-group $resourceGroup `
  --namespace-name $serviceBusName `
  --name "email-notifications-queue"

# Check dead-letter queue
az servicebus queue show-runtime-properties `
  --resource-group $resourceGroup `
  --namespace-name $serviceBusName `
  --name "email-notifications-queue$DeadLetterQueue"
```

### Test Cosmos DB Connection

```powershell
# Verify Cosmos DB connection string
$cosmosConnStr = az keyvault secret show --vault-name $keyVaultName --name "CosmosDbConnectionString" --query value -o tsv
Write-Host "Cosmos Connection: $cosmosConnStr"

# Check database
az cosmosdb sql database show `
  --account-name "cosmos-registrationapp-india" `
  --resource-group $resourceGroup `
  --name "RegistrationAppDb"

# Check container
az cosmosdb sql container show `
  --account-name "cosmos-registrationapp-india" `
  --database-name "RegistrationAppDb" `
  --resource-group $resourceGroup `
  --name "AuditLogs"
```

### View Azure Portal Links

```powershell
$subscriptionId = "af300fa3-a715-4320-8558-efe8a549457e"
$resourceGroup = "rg-registration-app"
$functionAppName = "func-registrationapp"
$logicAppName = "logic-item-approval-workflow"

Write-Host "Quick Portal Links:" -ForegroundColor Cyan
Write-Host ""
Write-Host "Function App:" -ForegroundColor Yellow
Write-Host "https://portal.azure.com/#resource/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Web/sites/$functionAppName" -ForegroundColor Blue
Write-Host ""
Write-Host "Logic App:" -ForegroundColor Yellow
Write-Host "https://portal.azure.com/#resource/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Logic/workflows/$logicAppName" -ForegroundColor Blue
Write-Host ""
Write-Host "Resource Group:" -ForegroundColor Yellow
Write-Host "https://portal.azure.com/#resource/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/overview" -ForegroundColor Blue
```

---

## CLEANUP COMMANDS

### Delete Function App

```powershell
$functionAppName = "func-registrationapp"

az functionapp delete `
  --name $functionAppName `
  --resource-group $resourceGroup

# Confirm deletion
az functionapp list --resource-group $resourceGroup -o table
```

### Delete Logic App

```powershell
$logicAppName = "logic-item-approval-workflow"

az logic workflow delete `
  --name $logicAppName `
  --resource-group $resourceGroup

# Confirm deletion
az logic workflow list --resource-group $resourceGroup -o table
```

### Delete Storage Accounts

```powershell
$functionStorageName = "stregistrationappfunc"
$logicStorageName = "stlogicappstorage"

az storage account delete `
  --name $functionStorageName `
  --resource-group $resourceGroup `
  --yes

az storage account delete `
  --name $logicStorageName `
  --resource-group $resourceGroup `
  --yes
```

---

## TROUBLESHOOTING

### Check all Azure resources in resource group

```powershell
az resource list --resource-group $resourceGroup -o table
```

### Check Function App logs

```powershell
$functionAppName = "func-registrationapp"

# Stream logs
az webapp log tail --name $functionAppName --resource-group $resourceGroup

# Download logs
az webapp log download --name $functionAppName --resource-group $resourceGroup --log-file mylog.zip
```

### Check Logic App status

```powershell
$logicAppName = "logic-item-approval-workflow"

# Check if enabled
az logic workflow show --name $logicAppName --resource-group $resourceGroup --query "properties.state"

# Enable if disabled
az logic workflow update --name $logicAppName --resource-group $resourceGroup --set "properties.state=Enabled"
```

### Reset Function App

```powershell
$functionAppName = "func-registrationapp"

# Stop
az functionapp stop --name $functionAppName --resource-group $resourceGroup

# Start
az functionapp start --name $functionAppName --resource-group $resourceGroup

# Restart
az functionapp restart --name $functionAppName --resource-group $resourceGroup
```

---

**Quick Reference Created**: February 5, 2026
