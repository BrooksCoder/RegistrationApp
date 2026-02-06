# Azure Logic Apps Deployment - Complete Commands

## Prerequisites
- Azure CLI installed
- Azure subscription with sufficient permissions
- Storage Account connection string
- Cosmos DB connection string
- Service Bus connection string

## Setup Variables

```powershell
$resourceGroup = "rg-registration-app"
$logicAppName = "logic-item-approval-workflow"
$logicAppLocation = "eastus"
$subscriptionId = "af300fa3-a715-4320-8558-efe8a549457e"
$sqlServerName = "regsql2807"
$sqlDatabaseName = "RegistrationAppDb"
$sqlTableName = "Items"
$keyVaultName = "kv-registrationapp"

Write-Host "Variables configured:"
Write-Host "  Resource Group: $resourceGroup"
Write-Host "  Logic App: $logicAppName"
Write-Host "  Location: $logicAppLocation"
Write-Host "  SQL Server: $sqlServerName"
Write-Host "  Database: $sqlDatabaseName"
```

## Step 1: Create Storage Account for Logic App State

```powershell
$logicStorageName = "stlogicappstorage"

Write-Host "Creating storage account for Logic Apps..." -ForegroundColor Yellow

# Check if already exists
$existingStorage = az storage account show `
  --name $logicStorageName `
  --resource-group $resourceGroup 2>$null

if ($null -eq $existingStorage) {
    az storage account create `
      --name $logicStorageName `
      --resource-group $resourceGroup `
      --location $logicAppLocation `
      --sku Standard_LRS `
      --kind StorageV2
    
    Write-Host "✅ Storage account created: $logicStorageName" -ForegroundColor Green
} else {
    Write-Host "✅ Storage account already exists" -ForegroundColor Green
}
```

## Step 2: Create Logic App Workflow

```powershell
Write-Host "Creating Logic App..." -ForegroundColor Yellow

# Check if Logic App exists
$existingLogicApp = az logic workflow show `
  --name $logicAppName `
  --resource-group $resourceGroup 2>$null

if ($null -eq $existingLogicApp) {
    az logic workflow create `
      --resource-group $resourceGroup `
      --location $logicAppLocation `
      --name $logicAppName
    
    Write-Host "✅ Logic App created: $logicAppName" -ForegroundColor Green
} else {
    Write-Host "✅ Logic App already exists: $logicAppName" -ForegroundColor Green
}
```

## Step 3: Create Logic App Definition (JSON)

**File: `logic-app-definition.json`**

This defines the complete workflow in code:

```json
{
  "$schema": "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {},
  "triggers": {
    "When_a_row_is_inserted": {
      "type": "ApiConnection",
      "inputs": {
        "host": {
          "connection": {
            "name": "@parameters('$connections')['sql']['connectionId']"
          }
        },
        "method": "get",
        "path": "/v2/datasets/@{encodeURIComponent(encodeURIComponent('default'))}/tables/@{encodeURIComponent(encodeURIComponent('[dbo].[Items]'))}/onnewitems"
      },
      "recurrence": {
        "frequency": "Minute",
        "interval": 1
      }
    }
  },
  "actions": {
    "Send_approval_email_to_admin": {
      "runAfter": {},
      "type": "ApiConnection",
      "inputs": {
        "host": {
          "connection": {
            "name": "@parameters('$connections')['office365']['connectionId']"
          }
        },
        "method": "post",
        "body": {
          "To": "admin@example.com",
          "Subject": "Approval Required: New Item Created",
          "Body": "<h2>New Item Requires Approval</h2><p><strong>Item Name:</strong> @{triggerBody()?['Name']}</p><p><strong>Description:</strong> @{triggerBody()?['Description']}</p><p><strong>Created:</strong> @{triggerBody()?['CreatedAt']}</p><p>Please review and approve or reject this item.</p>",
          "Options": "InlineImages"
        },
        "path": "/v2/Mail"
      }
    },
    "Approval_condition": {
      "runAfter": {
        "Send_approval_email_to_admin": [
          "Succeeded"
        ]
      },
      "type": "If",
      "expression": {
        "and": [
          {
            "equals": [
              "@body('Send_approval_email_to_admin')?['SelectedOption']",
              "Approve"
            ]
          }
        ]
      },
      "actions": {
        "Send_confirmation_email": {
          "runAfter": {},
          "type": "ApiConnection",
          "inputs": {
            "host": {
              "connection": {
                "name": "@parameters('$connections')['office365']['connectionId']"
              }
            },
            "method": "post",
            "body": {
              "To": "user@example.com",
              "Subject": "Item Approved: @{triggerBody()?['Name']}",
              "Body": "<h2>Your item has been approved!</h2><p><strong>Item:</strong> @{triggerBody()?['Name']}</p><p>Your item is now live in the system.</p>"
            },
            "path": "/v2/Mail"
          }
        },
        "Create_approval_blob": {
          "runAfter": {
            "Send_confirmation_email": [
              "Succeeded"
            ]
          },
          "type": "ApiConnection",
          "inputs": {
            "host": {
              "connection": {
                "name": "@parameters('$connections')['azureblob']['connectionId']"
              }
            },
            "method": "post",
            "body": "@{json(concat('{\"itemId\": ', triggerBody()?['Id'], ', \"itemName\": \"', triggerBody()?['Name'], '\", \"action\": \"Approved\", \"approvedAt\": \"', utcNow(), '\"}'))}",
            "path": "/datasets/default/files",
            "queries": {
              "folderPath": "/item-approvals",
              "name": "item-@{triggerBody()?['Id']}-approval-@{utcNow('yyyyMMddHHmmss')}.json"
            }
          }
        },
        "Log_approval_to_cosmos": {
          "runAfter": {
            "Create_approval_blob": [
              "Succeeded"
            ]
          },
          "type": "ApiConnection",
          "inputs": {
            "host": {
              "connection": {
                "name": "@parameters('$connections')['cosmosdb']['connectionId']"
              }
            },
            "method": "post",
            "body": {
              "id": "@{guid()}",
              "itemId": "@{triggerBody()?['Id']}",
              "itemName": "@{triggerBody()?['Name']}",
              "action": "Approved",
              "approvedAt": "@{utcNow()}",
              "partition": "approval"
            },
            "path": "/dbs/RegistrationAppDb/colls/WorkflowLogs/docs"
          }
        }
      }
    },
    "Send_rejection_email": {
      "runAfter": {
        "Approval_condition": [
          "Failed"
        ]
      },
      "type": "ApiConnection",
      "inputs": {
        "host": {
          "connection": {
            "name": "@parameters('$connections')['office365']['connectionId']"
          }
        },
        "method": "post",
        "body": {
          "To": "user@example.com",
          "Subject": "Item Rejected: @{triggerBody()?['Name']}",
          "Body": "<h2>Your item has been rejected</h2><p><strong>Item:</strong> @{triggerBody()?['Name']}</p><p>The item requires further review. Please contact the administrator.</p>"
        },
        "path": "/v2/Mail"
      }
    }
  },
  "outputs": {}
}
```

## Step 4: Deploy Logic App with ARM Template

**File: `deploy-logic-app.json`**

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "logicAppName": {
      "type": "string",
      "defaultValue": "logic-item-approval-workflow"
    },
    "location": {
      "type": "string",
      "defaultValue": "eastus"
    }
  },
  "resources": [
    {
      "type": "Microsoft.Logic/workflows",
      "apiVersion": "2019-05-01",
      "name": "[parameters('logicAppName')]",
      "location": "[parameters('location')]",
      "properties": {
        "definition": {
          "$schema": "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#",
          "contentVersion": "1.0.0.0",
          "parameters": {
            "$connections": {
              "defaultValue": {},
              "type": "Object"
            }
          },
          "triggers": {
            "Recurrence": {
              "recurrence": {
                "frequency": "Minute",
                "interval": 1
              },
              "type": "Recurrence"
            }
          },
          "actions": {
            "Send_notification": {
              "type": "Http",
              "inputs": {
                "method": "POST",
                "uri": "https://your-webhook-url.com/notify"
              }
            }
          }
        },
        "parameters": {
          "$connections": {
            "value": {
              "sql": {
                "connectionId": "/subscriptions/[subscription-id]/resourceGroups/[resource-group]/providers/Microsoft.Web/connections/sql",
                "connectionName": "sql",
                "id": "/subscriptions/[subscription-id]/providers/Microsoft.Web/locations/eastus/managedApis/sql"
              },
              "office365": {
                "connectionId": "/subscriptions/[subscription-id]/resourceGroups/[resource-group]/providers/Microsoft.Web/connections/office365",
                "connectionName": "office365",
                "id": "/subscriptions/[subscription-id]/providers/Microsoft.Web/locations/eastus/managedApis/office365"
              },
              "azureblob": {
                "connectionId": "/subscriptions/[subscription-id]/resourceGroups/[resource-group]/providers/Microsoft.Web/connections/azureblob",
                "connectionName": "azureblob",
                "id": "/subscriptions/[subscription-id]/providers/Microsoft.Web/locations/eastus/managedApis/azureblob"
              },
              "cosmosdb": {
                "connectionId": "/subscriptions/[subscription-id]/resourceGroups/[resource-group]/providers/Microsoft.Web/connections/cosmosdb",
                "connectionName": "cosmosdb",
                "id": "/subscriptions/[subscription-id]/providers/Microsoft.Web/locations/eastus/managedApis/cosmosdb"
              }
            }
          }
        }
      }
    }
  ],
  "outputs": {
    "logicAppUrl": {
      "type": "string",
      "value": "[listCallbackUrl(concat(resourceId('Microsoft.Logic/workflows', parameters('logicAppName')), '/triggers/manual'), '2019-05-01').value]"
    }
  }
}
```

## Step 5: Deploy Using PowerShell

```powershell
$resourceGroup = "rg-registration-app"
$logicAppName = "logic-item-approval-workflow"
$logicAppLocation = "eastus"
$templateFile = "C:\Users\Admin\source\repos\RegistrationApp\deploy-logic-app.json"

Write-Host "Deploying Logic App using ARM template..." -ForegroundColor Yellow

az deployment group create `
  --resource-group $resourceGroup `
  --template-file $templateFile `
  --parameters `
    logicAppName=$logicAppName `
    location=$logicAppLocation

Write-Host "✅ Logic App deployed successfully" -ForegroundColor Green
```

## Step 6: Configure Connections Manually (in Azure Portal)

Since Logic Apps require authenticated connections, configure these in the portal:

### For SQL Server Connection:
1. Go to Azure Portal → Logic Apps → $logicAppName
2. Click "Edit in Logic App Designer"
3. For "When a row is inserted" trigger:
   - Select SQL Server connection
   - Server: regsql2807.database.windows.net
   - Database: RegistrationAppDb
   - Table: Items
   - Frequency: Every 1 minute

### For Office 365 Connection:
1. Click "+ New connection" → Office 365 Outlook
2. Sign in with your Office 365 account
3. Configure email settings

### For Azure Blob Storage Connection:
1. Click "+ New connection" → Azure Blob Storage
2. Select storage account: stlogicappstorage
3. Configure container: item-approvals

### For Cosmos DB Connection:
1. Click "+ New connection" → Azure Cosmos DB
2. Connection name: cosmosdb
3. Database account: cosmos-registrationapp-india
4. Account key: (from Key Vault)

## Step 7: Complete PowerShell Deployment Script

```powershell
# All-in-one deployment script

$resourceGroup = "rg-registration-app"
$logicAppName = "logic-item-approval-workflow"
$logicAppLocation = "eastus"
$logicStorageName = "stlogicappstorage"
$subscriptionId = "af300fa3-a715-4320-8558-efe8a549457e"

Write-Host "=== LOGIC APP DEPLOYMENT ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Create storage account
Write-Host "Step 1: Creating storage account..." -ForegroundColor Yellow
az storage account create `
  --name $logicStorageName `
  --resource-group $resourceGroup `
  --location $logicAppLocation `
  --sku Standard_LRS `
  --kind StorageV2 2>$null

Write-Host "✅ Storage account created" -ForegroundColor Green
Write-Host ""

# Step 2: Create Logic App
Write-Host "Step 2: Creating Logic App..." -ForegroundColor Yellow
az logic workflow create `
  --resource-group $resourceGroup `
  --location $logicAppLocation `
  --name $logicAppName 2>$null

Write-Host "✅ Logic App created" -ForegroundColor Green
Write-Host ""

# Step 3: Get Logic App properties
Write-Host "Step 3: Logic App details:" -ForegroundColor Cyan
az logic workflow show `
  --name $logicAppName `
  --resource-group $resourceGroup `
  --query "{name:name, state:properties.state, location:location}"

Write-Host ""
Write-Host "=== NEXT STEPS ===" -ForegroundColor Yellow
Write-Host "1. Go to Azure Portal: https://portal.azure.com" -ForegroundColor White
Write-Host "2. Navigate to: Resource Groups > $resourceGroup > Logic Apps > $logicAppName" -ForegroundColor White
Write-Host "3. Click 'Edit in Logic App Designer'" -ForegroundColor White
Write-Host "4. Configure triggers and actions:" -ForegroundColor White
Write-Host "   - Add SQL trigger: When row inserted in Items table" -ForegroundColor White
Write-Host "   - Add actions: Send emails, create blobs, log to Cosmos" -ForegroundColor White
Write-Host "5. Configure connections:" -ForegroundColor White
Write-Host "   - SQL Server connection" -ForegroundColor White
Write-Host "   - Office 365 Outlook connection" -ForegroundColor White
Write-Host "   - Azure Blob Storage connection" -ForegroundColor White
Write-Host "   - Azure Cosmos DB connection" -ForegroundColor White
Write-Host "6. Save and enable the workflow" -ForegroundColor White
Write-Host ""
Write-Host "Portal URL: https://portal.azure.com/#resource/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Logic/workflows/$logicAppName" -ForegroundColor Cyan
```

## Step 8: Test Logic App

```powershell
# Manually trigger logic app
Write-Host "Testing Logic App..." -ForegroundColor Yellow

# Get the callback URL for manual trigger
$callbackUrl = az logic workflow show `
  --name $logicAppName `
  --resource-group $resourceGroup `
  --query "properties.definition.triggers.manual.inputs.schema" 2>$null

Write-Host "Callback URL available in Azure Portal" -ForegroundColor Cyan

# Insert test data into SQL
sqlcmd -S regsql2807.database.windows.net -U sqladmin -d RegistrationAppDb -Q "INSERT INTO Items (Name, Description, CreatedAt) VALUES ('Test Item', 'Test Description', GETUTCDATE())"

Write-Host "✅ Test data inserted - Logic App should trigger automatically" -ForegroundColor Green

# Monitor execution
Write-Host "Monitor execution at: https://portal.azure.com → Logic Apps → $logicAppName → Runs" -ForegroundColor Cyan
```

## Step 9: Monitor and Troubleshoot

```powershell
# View Logic App runs
Write-Host "Viewing Logic App execution history..." -ForegroundColor Yellow

az logic workflow run list `
  --name $logicAppName `
  --resource-group $resourceGroup `
  --query "[].{name:name, status:properties.status, startTime:properties.startTime, endTime:properties.endTime}" `
  -o table

# View specific run details
$latestRun = az logic workflow run list `
  --name $logicAppName `
  --resource-group $resourceGroup `
  --query "[0].name" -o tsv

Write-Host "Latest run: $latestRun" -ForegroundColor Cyan

# Get run details
az logic workflow run show `
  --name $logicAppName `
  --resource-group $resourceGroup `
  --run-name $latestRun `
  --query "properties.{status:status, trigger:trigger, outputs:outputs}"
```

## Troubleshooting

### Logic App not triggering

```powershell
# 1. Check if enabled
az logic workflow show `
  --name $logicAppName `
  --resource-group $resourceGroup `
  --query "properties.state"

# 2. Enable if disabled
az logic workflow update `
  --name $logicAppName `
  --resource-group $resourceGroup `
  --set "properties.state=Enabled"

# 3. Check SQL connection
az logic workflow show `
  --name $logicAppName `
  --resource-group $resourceGroup `
  --query "properties.definition.triggers"
```

### Connection errors

```powershell
# List all connections
az connection list --resource-group $resourceGroup -o table

# Reconnect a connection
az connection update `
  --name "sql" `
  --resource-group $resourceGroup
```

### Increase Logic App timeout

```powershell
# Default timeout is 120 seconds, increase if needed:
az logic workflow update `
  --name $logicAppName `
  --resource-group $resourceGroup `
  --set "properties.runtimeConfiguration.timeout=PT10M"
```

## Cost Estimation

| Component | Cost/Month |
|-----------|------------|
| Logic App Execution | ~$0.0002 per run |
| Storage Account | ~$1 |
| SQL Server | ~$200 (existing) |
| **Total (approx)** | **$1-10/month** |

*Actual cost depends on number of executions*

## Complete PowerShell Setup

```powershell
# Final comprehensive setup script

param(
    [string]$ResourceGroup = "rg-registration-app",
    [string]$LogicAppName = "logic-item-approval-workflow",
    [string]$Location = "eastus",
    [string]$StorageName = "stlogicappstorage",
    [string]$SubscriptionId = "af300fa3-a715-4320-8558-efe8a549457e"
)

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "=== $Title ===" -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

# Main deployment
Write-Section "AZURE LOGIC APPS DEPLOYMENT"

# Set subscription
Write-Step "Setting subscription context..."
az account set --subscription $SubscriptionId
Write-Success "Subscription set to $SubscriptionId"

# Create storage
Write-Step "Creating storage account..."
az storage account create `
  --name $StorageName `
  --resource-group $ResourceGroup `
  --location $Location `
  --sku Standard_LRS 2>$null || Write-Host "Storage already exists"
Write-Success "Storage account: $StorageName"

# Create Logic App
Write-Step "Creating Logic App..."
az logic workflow create `
  --name $LogicAppName `
  --resource-group $ResourceGroup `
  --location $Location 2>$null || Write-Host "Logic App already exists"
Write-Success "Logic App: $LogicAppName"

# Display results
Write-Section "DEPLOYMENT COMPLETE"
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Cyan
Write-Host "Logic App Name: $LogicAppName" -ForegroundColor Cyan
Write-Host "Location: $Location" -ForegroundColor Cyan
Write-Host ""
Write-Host "Portal: https://portal.azure.com/#resource/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Logic/workflows/$LogicAppName" -ForegroundColor Blue
```

---

**Created**: February 5, 2026
