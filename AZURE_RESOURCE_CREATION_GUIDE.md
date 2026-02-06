# Quick Start: Create Missing Azure Resources

**Your Resource Group**: `rg-registration-app`
**Your Subscription**: Use `az account set --subscription "YOUR_SUBSCRIPTION_ID"`

---

## 📋 What You Need to Create

You have **12 existing resources**. You need to create **8 more** to complete the Azure integration:

1. ✅ kv-registrationapp (Key Vault)
2. ✅ regsql-kv-2807 (Key Vault)
3. ✅ registrationappacr (Container Registry)
4. ✅ regsql2807 (SQL Server)
5. ✅ RegistrationAppDb (SQL Database)
6. ✅ registration-api-2807 (Container)
7. ✅ registration-api-prod (Container)
8. ✅ registration-frontend-2807 (Container)
9. ✅ registration-frontend-prod (Container)
10. ⏳ **stregistrationapp2807** (Storage Account) - TO CREATE
11. ⏳ **sb-registrationapp-eastus** (Service Bus) - TO CREATE
12. ⏳ **cosmos-registrationapp-india** (Cosmos DB) - TO CREATE
13. ⏳ **insights-registration-app** (App Insights) - TO CREATE
14. ⏳ **func-registrationapp** (Functions) - TO CREATE
15. ⏳ **logic-item-approval** (Logic Apps) - TO CREATE

---

## 🚀 Step 1: Prepare Your Environment (2 minutes)

```powershell
# Open PowerShell as Administrator
# Navigate to your project
cd C:\Users\Admin\source\repos\RegistrationApp

# Login to Azure
az login

# Set your subscription
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Verify your resource group exists
az group show --name rg-registration-app

# Set as default to avoid typing it repeatedly
az configure --defaults group=rg-registration-app
```

---

## 🔐 Step 2: Create Storage Account (5 minutes)

```powershell
# Variables
$storageName = "stregistrationapp2807"
$location = "eastus"
$resourceGroup = "rg-registration-app"

# Create Storage Account
Write-Host "Creating Storage Account: $storageName" -ForegroundColor Green
az storage account create `
  --name $storageName `
  --resource-group $resourceGroup `
  --location $location `
  --sku Standard_LRS `
  --kind StorageV2

# Wait for creation
Start-Sleep -Seconds 5

# Get Connection String
$storageConnStr = az storage account show-connection-string `
  --name $storageName `
  --resource-group $resourceGroup `
  --query "connectionString" -o tsv

Write-Host "Storage Connection String:" -ForegroundColor Cyan
Write-Host $storageConnStr

# Create blob containers
Write-Host "Creating Blob Containers..." -ForegroundColor Green
az storage container create `
  --account-name $storageName `
  --name "uploads"

az storage container create `
  --account-name $storageName `
  --name "item-images"

Write-Host "✅ Storage Account Created!" -ForegroundColor Green

# Save to Key Vault
Write-Host "Adding to Key Vault..." -ForegroundColor Yellow
az keyvault secret set `
  --vault-name "kv-registrationapp" `
  --name "StorageAccountConnectionString" `
  --value $storageConnStr

Write-Host "✅ Saved to Key Vault!" -ForegroundColor Green
```

---

## 📬 Step 3: Create Service Bus (5 minutes)

```powershell
# Variables
$serviceBusName = "sb-registrationapp-eastus"
$sbLocation = "eastus"
$resourceGroup = "rg-registration-app"

# Create Service Bus Namespace
Write-Host "Creating Service Bus: $serviceBusName" -ForegroundColor Green
az servicebus namespace create `
  --resource-group $resourceGroup `
  --name $serviceBusName `
  --location $sbLocation `
  --sku Standard

# Wait for creation
Start-Sleep -Seconds 10

# Create Queues
Write-Host "Creating Queues..." -ForegroundColor Yellow
az servicebus queue create `
  --resource-group $resourceGroup `
  --namespace-name $serviceBusName `
  --name "item-created-queue"

az servicebus queue create `
  --resource-group $resourceGroup `
  --namespace-name $serviceBusName `
  --name "email-notifications-queue"

Write-Host "✅ Queues Created!" -ForegroundColor Green

# Get Connection String
Write-Host "Retrieving Connection String..." -ForegroundColor Yellow
$sbConnStr = az servicebus namespace authorization-rule keys list `
  --resource-group $resourceGroup `
  --namespace-name $serviceBusName `
  --name RootManageSharedAccessKey `
  --query "primaryConnectionString" -o tsv

Write-Host "Service Bus Connection String:" -ForegroundColor Cyan
Write-Host $sbConnStr

# Save to Key Vault
Write-Host "Adding to Key Vault..." -ForegroundColor Yellow
az keyvault secret set `
  --vault-name "kv-registrationapp" `
  --name "ServiceBusConnectionString" `
  --value $sbConnStr

Write-Host "✅ Service Bus Created & Saved to Key Vault!" -ForegroundColor Green
```

---

## 🗄️ Step 4: Create Cosmos DB (10 minutes)

```powershell
# Variables
$cosmosName = "cosmos-registrationapp-india"
$cosmosLocation = "centralindia"
$resourceGroup = "rg-registration-app"

# Create Cosmos DB Account
Write-Host "Creating Cosmos DB Account: $cosmosName (this takes ~2-3 minutes)" -ForegroundColor Green
az cosmosdb create `
  --resource-group $resourceGroup `
  --name $cosmosName `
  --kind GlobalDocumentDB `
  --default-consistency-level "Session" `
  --locations regionName=$cosmosLocation failoverPriority=0

Write-Host "✅ Cosmos DB Account Created!" -ForegroundColor Green

# Wait for account to be fully ready
Write-Host "Waiting for Cosmos DB to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Create Database
Write-Host "Creating Database..." -ForegroundColor Yellow
az cosmosdb sql database create `
  --account-name $cosmosName `
  --resource-group $resourceGroup `
  --name "RegistrationAppDb"

# Create Container
Write-Host "Creating Container..." -ForegroundColor Yellow
az cosmosdb sql container create `
  --account-name $cosmosName `
  --database-name "RegistrationAppDb" `
  --resource-group $resourceGroup `
  --name "AuditLogs" `
  --partition-key-path "/partition" `
  --throughput 400

Write-Host "✅ Database & Container Created!" -ForegroundColor Green

# Get Connection String
Write-Host "Retrieving Connection String..." -ForegroundColor Yellow
$cosmosConnStr = az cosmosdb keys list `
  --resource-group $resourceGroup `
  --name $cosmosName `
  --type connection-strings `
  --query "connectionStrings[0].connectionString" -o tsv

Write-Host "Cosmos DB Connection String:" -ForegroundColor Cyan
Write-Host $cosmosConnStr

# Save to Key Vault
Write-Host "Adding to Key Vault..." -ForegroundColor Yellow
az keyvault secret set `
  --vault-name "kv-registrationapp" `
  --name "CosmosDbConnectionString" `
  --value $cosmosConnStr

Write-Host "✅ Cosmos DB Created & Saved to Key Vault!" -ForegroundColor Green
```

---

## 📊 Step 5: Create Application Insights (3 minutes)

```powershell
# Variables
$appInsightsName = "insights-registration-app"
$location = "eastus"
$resourceGroup = "rg-registration-app"

# Create Application Insights
Write-Host "Creating Application Insights: $appInsightsName" -ForegroundColor Green
az monitor app-insights component create `
  --app $appInsightsName `
  --location $location `
  --resource-group $resourceGroup `
  --application-type web

Write-Host "✅ Application Insights Created!" -ForegroundColor Green

# Get Instrumentation Key
Write-Host "Retrieving Instrumentation Key..." -ForegroundColor Yellow
$appInsightsKey = az monitor app-insights component show `
  --app $appInsightsName `
  --resource-group $resourceGroup `
  --query "instrumentationKey" -o tsv

Write-Host "Instrumentation Key:" -ForegroundColor Cyan
Write-Host $appInsightsKey

# Save to Key Vault
Write-Host "Adding to Key Vault..." -ForegroundColor Yellow
az keyvault secret set `
  --vault-name "kv-registrationapp" `
  --name "ApplicationInsightsInstrumentationKey" `
  --value $appInsightsKey

Write-Host "✅ Application Insights Created & Saved to Key Vault!" -ForegroundColor Green
```

---

## ⚡ Step 6: Create Azure Functions (5 minutes)

```powershell
# Variables
$functionAppName = "func-registrationapp"
$functionStorageName = "stregistrationappfunc"
$functionLocation = "eastus"
$resourceGroup = "rg-registration-app"

# Create Storage Account for Functions
Write-Host "Creating Storage Account for Functions: $functionStorageName" -ForegroundColor Green
az storage account create `
  --name $functionStorageName `
  --resource-group $resourceGroup `
  --location $functionLocation `
  --sku Standard_LRS

Write-Host "✅ Storage Account Created!" -ForegroundColor Green

# Create Function App
Write-Host "Creating Function App: $functionAppName" -ForegroundColor Green
az functionapp create `
  --resource-group $resourceGroup `
  --consumption-plan-location $functionLocation `
  --runtime dotnet-isolated `
  --runtime-version 8.0 `
  --functions-version 4 `
  --name $functionAppName `
  --storage-account $functionStorageName `
  --os-type Windows

Write-Host "✅ Function App Created!" -ForegroundColor Green

# Get previous values from Key Vault (for function app configuration)
Write-Host "Retrieving secrets from Key Vault..." -ForegroundColor Yellow
$sbConnStr = az keyvault secret show --vault-name "kv-registrationapp" --name "ServiceBusConnectionString" --query value -o tsv
$cosmosConnStr = az keyvault secret show --vault-name "kv-registrationapp" --name "CosmosDbConnectionString" --query value -o tsv
$storageConnStr = az keyvault secret show --vault-name "kv-registrationapp" --name "StorageAccountConnectionString" --query value -o tsv

# Configure Function App Settings
Write-Host "Configuring Function App Settings..." -ForegroundColor Yellow
az functionapp config appsettings set `
  --name $functionAppName `
  --resource-group $resourceGroup `
  --settings `
    AzureWebJobsServiceBusConnectionString=$sbConnStr `
    CosmosDbConnectionString=$cosmosConnStr `
    StorageAccountConnectionString=$storageConnStr

Write-Host "✅ Function App Configured!" -ForegroundColor Green
```

---

## 🔄 Step 7: Create Logic App (5 minutes)

```powershell
# Variables
$logicAppName = "logic-item-approval"
$location = "eastus"
$resourceGroup = "rg-registration-app"

# Create Logic App
Write-Host "Creating Logic App: $logicAppName" -ForegroundColor Green
az logic workflow create `
  --resource-group $resourceGroup `
  --location $location `
  --name $logicAppName `
  --definition '{
    "triggers": {
      "manual": {
        "type": "Request",
        "kind": "Http",
        "inputs": {
          "schema": {
            "type": "object",
            "properties": {
              "itemId": {"type": "string"},
              "itemName": {"type": "string"}
            }
          }
        }
      }
    },
    "actions": {}
  }'

Write-Host "✅ Logic App Created!" -ForegroundColor Green
Write-Host "Configure your workflow in the Azure Portal:" -ForegroundColor Cyan
Write-Host "https://portal.azure.com/#resource/subscriptions/YOUR_SUB_ID/resourceGroups/rg-registration-app/providers/Microsoft.Logic/workflows/$logicAppName"
```

---

## ✅ Step 8: Verify All Resources

```powershell
# List all resources in your group
Write-Host "All Resources in rg-registration-app:" -ForegroundColor Cyan
az resource list --resource-group rg-registration-app `
  --query "[].{Name:name, Type:type, Location:location}" `
  -o table

# You should now have ~20 resources (12 existing + 8 new)
```

---

## 🔑 Step 9: Update Your Application Configuration

Now that all resources are created, update your application's `appsettings.json`:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=regsql2807.database.windows.net;Database=RegistrationAppDb;User ID=sqladmin;Password=YOUR_PASSWORD;Encrypt=true;",
    "AzureStorageAccount": "DefaultEndpointsProtocol=https;AccountName=stregistrationapp2807;AccountKey=YOUR_KEY;EndpointSuffix=core.windows.net",
    "AzureServiceBus": "Endpoint=sb://sb-registrationapp-eastus.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=YOUR_KEY",
    "AzureCosmosDb": "AccountEndpoint=https://cosmos-registrationapp-india.documents.azure.com:443/;AccountKey=YOUR_KEY;Database=RegistrationAppDb"
  },
  "AzureKeyVault": {
    "VaultUri": "https://kv-registrationapp.vault.azure.net/"
  },
  "AzureCosmosDb": {
    "DatabaseName": "RegistrationAppDb",
    "ContainerName": "AuditLogs"
  },
  "ApplicationInsights": {
    "InstrumentationKey": "YOUR_INSTRUMENTATION_KEY"
  }
}
```

**How to get values:**
```powershell
# Get secrets from Key Vault
az keyvault secret show --vault-name kv-registrationapp --name "StorageAccountConnectionString" --query value -o tsv
az keyvault secret show --vault-name kv-registrationapp --name "ServiceBusConnectionString" --query value -o tsv
az keyvault secret show --vault-name kv-registrationapp --name "CosmosDbConnectionString" --query value -o tsv
az keyvault secret show --vault-name kv-registrationapp --name "ApplicationInsightsInstrumentationKey" --query value -o tsv
```

---

## 🧪 Step 10: Test Your Setup

```powershell
# 1. Build your project
cd C:\Users\Admin\source\repos\RegistrationApp\backend
dotnet build

# 2. Test Application Insights
# Should show "Connection successful" in logs
dotnet run

# 3. In another terminal, test API
$response = Invoke-RestMethod -Uri "http://localhost:5000/api/items" -Method Get
Write-Host "Items: $($response.Count)"

# 4. Verify in Azure Portal:
# - Check Application Insights for events
# - Check Cosmos DB for audit logs
# - Check Storage for files
# - Check Service Bus queue depth
```

---

## 🎉 You're Done!

All 8 new Azure resources are now created and configured:

✅ Storage Account (File uploads)
✅ Service Bus (Messaging)
✅ Cosmos DB (Audit logs)
✅ Application Insights (Monitoring)
✅ Azure Functions (Processing)
✅ Logic Apps (Automation)
✅ All connection strings saved to Key Vault
✅ Application ready to deploy

---

## 📚 Next Steps

1. **Deploy to Container Instances** with updated image
2. **Monitor with Application Insights** dashboard
3. **Implement Azure Functions** (see AZURE_INTEGRATION_GUIDE.md Phase 4)
4. **Create Logic App workflows** (see AZURE_INTEGRATION_GUIDE.md Phase 5)
5. **Set up automated backups** for databases

---

## 💡 Pro Tips

**If a resource fails to create:**
```powershell
# Delete and try again
az resource delete --ids /subscriptions/SUB_ID/resourceGroups/rg-registration-app/providers/Microsoft.Storage/storageAccounts/stregistrationapp2807
```

**To see real-time logs:**
```powershell
az container logs --name registration-api-prod --resource-group rg-registration-app --follow
```

**To update a secret:**
```powershell
az keyvault secret set --vault-name kv-registrationapp --name "SecretName" --value "new_value"
```

---

**Status**: Ready to create resources
**Estimated Time**: 30-40 minutes total
**Difficulty**: Beginner (just copy-paste commands)
**Cost**: ~$38-42/month for new resources

Good luck! 🚀

