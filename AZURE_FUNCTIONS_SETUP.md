# Azure Functions Deployment - Complete Commands

## Prerequisites
- Azure CLI installed
- Azure Functions Core Tools installed
- .NET 8.0 SDK installed
- PowerShell 5.1+

## Setup Variables

```powershell
$resourceGroup = "rg-registration-app"
$functionAppName = "func-registrationapp"
$functionStorageName = "stregistrationappfunc"
$functionLocation = "eastus"
$subscriptionId = "af300fa3-a715-4320-8558-efe8a549457e"
$keyVaultName = "kv-registrationapp"

# Get connection strings from Key Vault
$sbConnStr = az keyvault secret show --vault-name $keyVaultName --name "ServiceBusConnectionString" --query value -o tsv
$cosmosConnStr = az keyvault secret show --vault-name $keyVaultName --name "CosmosDbConnectionString" --query value -o tsv
$storageConnStr = az keyvault secret show --vault-name $keyVaultName --name "StorageAccountConnectionString" --query value -o tsv

Write-Host "Variables configured:"
Write-Host "  Resource Group: $resourceGroup"
Write-Host "  Function App: $functionAppName"
Write-Host "  Storage: $functionStorageName"
Write-Host "  Location: $functionLocation"
```

## Step 1: Create Storage Account for Functions Runtime

```powershell
Write-Host "Creating storage account for Functions..." -ForegroundColor Yellow

# Check if storage account exists
$existingStorage = az storage account show `
  --name $functionStorageName `
  --resource-group $resourceGroup 2>$null

if ($null -eq $existingStorage) {
    az storage account create `
      --name $functionStorageName `
      --resource-group $resourceGroup `
      --location $functionLocation `
      --sku Standard_LRS `
      --kind StorageV2
    
    Write-Host "✅ Storage account created: $functionStorageName" -ForegroundColor Green
} else {
    Write-Host "✅ Storage account already exists: $functionStorageName" -ForegroundColor Green
}
```

## Step 2: Create Function App

```powershell
Write-Host "Creating Function App..." -ForegroundColor Yellow

# Check if Function App exists
$existingFunctionApp = az functionapp show `
  --name $functionAppName `
  --resource-group $resourceGroup 2>$null

if ($null -eq $existingFunctionApp) {
    az functionapp create `
      --resource-group $resourceGroup `
      --consumption-plan-location $functionLocation `
      --runtime dotnet-isolated `
      --runtime-version 8.0 `
      --functions-version 4 `
      --name $functionAppName `
      --storage-account $functionStorageName `
      --os-type Windows
    
    Write-Host "✅ Function App created: $functionAppName" -ForegroundColor Green
} else {
    Write-Host "✅ Function App already exists: $functionAppName" -ForegroundColor Green
}

# Wait for app to be ready
Start-Sleep -Seconds 5
```

## Step 3: Configure Function App Settings

```powershell
Write-Host "Configuring Function App settings..." -ForegroundColor Yellow

# Get connection strings from Key Vault
$sbConnStr = az keyvault secret show --vault-name $keyVaultName --name "ServiceBusConnectionString" --query value -o tsv
$cosmosConnStr = az keyvault secret show --vault-name $keyVaultName --name "CosmosDbConnectionString" --query value -o tsv
$storageConnStr = az keyvault secret show --vault-name $keyVaultName --name "StorageAccountConnectionString" --query value -o tsv

# Configure app settings
az functionapp config appsettings set `
  --name $functionAppName `
  --resource-group $resourceGroup `
  --settings `
    AzureWebJobsServiceBusConnectionString=$sbConnStr `
    CosmosDbConnectionString=$cosmosConnStr `
    StorageAccountConnectionString=$storageConnStr `
    FUNCTIONS_WORKER_RUNTIME=dotnet-isolated `
    ASPNETCORE_ENVIRONMENT=Production

Write-Host "✅ App settings configured" -ForegroundColor Green
```

## Step 4: Create Local Function Project

```powershell
# Create project directory
$projectPath = "C:\Users\Admin\source\repos\RegistrationApp\azure-functions"
New-Item -ItemType Directory -Path $projectPath -Force | Out-Null
Set-Location $projectPath

Write-Host "Initializing Azure Functions project..." -ForegroundColor Yellow

# Initialize functions project
func init . --dotnet --worker-runtime dotnet-isolated

Write-Host "✅ Functions project initialized" -ForegroundColor Green

# Create function with Service Bus trigger
func new --name SendEmailNotification --template "Service Bus Queue trigger"

Write-Host "✅ SendEmailNotification function created" -ForegroundColor Green
```

## Step 5: Update Function Code

**File: `SendEmailNotification.cs`**

```csharp
using Azure.Messaging.ServiceBus;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using System.Text.Json;

namespace ItemNotificationFunction
{
    public class SendEmailNotification
    {
        private readonly ILogger<SendEmailNotification> _logger;

        public SendEmailNotification(ILogger<SendEmailNotification> logger)
        {
            _logger = logger;
        }

        [Function("SendEmailNotification")]
        public async Task Run(
            [ServiceBusTrigger("email-notifications-queue", Connection = "AzureWebJobsServiceBusConnectionString")]
            ServiceBusReceivedMessage message,
            FunctionContext context)
        {
            try
            {
                _logger.LogInformation($"Email notification message received at: {DateTime.Now}");
                
                // Parse message body
                string messageBody = message.Body.ToString();
                _logger.LogInformation($"Message details: {messageBody}");

                // Parse JSON
                using (JsonDocument doc = JsonDocument.Parse(messageBody))
                {
                    JsonElement root = doc.RootElement;
                    
                    string itemId = root.GetProperty("itemId").GetString();
                    string itemName = root.GetProperty("itemName").GetString();
                    string action = root.GetProperty("action").GetString();
                    
                    _logger.LogInformation($"Item {itemId} ({itemName}) - Action: {action}");
                    
                    // TODO: Integrate with SendGrid or another email service
                    // Example for future implementation:
                    /*
                    var client = new SendGridClient(sendGridApiKey);
                    var from = new EmailAddress("noreply@registrationapp.com", "Registration App");
                    var subject = $"Notification: {action} - {itemName}";
                    var to = new EmailAddress("admin@example.com", "Admin");
                    var plainTextContent = $"Item {itemId} has been {action.ToLower()}.";
                    var htmlContent = $"<strong>Notification</strong><p>Item {itemId} ({itemName}) has been {action.ToLower()}.</p>";
                    var msg = MailHelper.CreateSingleEmail(from, to, subject, plainTextContent, htmlContent);
                    
                    var response = await client.SendEmailAsync(msg);
                    _logger.LogInformation($"Email sent successfully. Status Code: {response.StatusCode}");
                    */
                    
                    _logger.LogInformation("Email notification processed successfully");
                }

                // Complete the message
                await message.CompleteMessageAsync(message);
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error processing email notification: {ex.Message}");
                throw;
            }
        }
    }
}
```

## Step 6: Update Function Configuration

**File: `local.settings.json`**

```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
    "AzureWebJobsServiceBusConnectionString": "Endpoint=sb://sb-registrationapp-eastus.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=YOUR_KEY",
    "CosmosDbConnectionString": "AccountEndpoint=https://cosmos-registrationapp-india.documents.azure.com:443/;AccountKey=YOUR_KEY;",
    "StorageAccountConnectionString": "DefaultEndpointsProtocol=https;AccountName=stregistrationapp2807;AccountKey=YOUR_KEY;EndpointSuffix=core.windows.net"
  }
}
```

## Step 7: Test Locally

```powershell
# Build the project
dotnet build

# Run functions locally
func start

# In another PowerShell window, test by sending a message:
$resourceGroup = "rg-registration-app"
$serviceBusName = "sb-registrationapp-eastus"

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

# Watch the function logs for processing
```

## Step 8: Deploy to Azure

```powershell
# Set location to functions project
Set-Location $projectPath

Write-Host "Publishing function to Azure..." -ForegroundColor Yellow

# Publish to Azure
func azure functionapp publish $functionAppName

Write-Host "✅ Function published to Azure" -ForegroundColor Green

# Verify deployment
az functionapp show `
  --name $functionAppName `
  --resource-group $resourceGroup `
  --query "{name:name, state:state, location:location}"
```

## Step 9: Monitor Function Execution

```powershell
# View function logs
az webapp log tail `
  --name $functionAppName `
  --resource-group $resourceGroup

# OR: View in Azure Portal
# https://portal.azure.com → Function Apps → func-registrationapp → Monitor

# Check function invocations
az functionapp function show `
  --name $functionAppName `
  --resource-group $resourceGroup `
  --function-name SendEmailNotification
```

## Testing Function End-to-End

```powershell
# 1. Send a test message to Service Bus
$resourceGroup = "rg-registration-app"
$serviceBusName = "sb-registrationapp-eastus"

Write-Host "Sending test message to Service Bus..." -ForegroundColor Yellow

az servicebus queue send `
  --resource-group $resourceGroup `
  --namespace-name $serviceBusName `
  --queue-name "email-notifications-queue" `
  --message-body '{
    "itemId": "123",
    "itemName": "iPhone 16 Pro",
    "action": "Created",
    "timestamp": "'$(Get-Date -Format 'o')'"
  }'

Write-Host "✅ Test message sent" -ForegroundColor Green

# 2. Monitor function logs
Write-Host "Monitor logs at: https://portal.azure.com → Function Apps → $functionAppName → Monitor" -ForegroundColor Cyan

# 3. Check Service Bus queue
az servicebus queue show-runtime-properties `
  --resource-group $resourceGroup `
  --namespace-name $serviceBusName `
  --name "email-notifications-queue"
```

## Integration with Backend Application

The backend should publish to Service Bus when items are created:

```csharp
// In ItemsController.cs
[HttpPost]
public async Task<IActionResult> CreateItem([FromBody] CreateItemRequest request)
{
    // Create item in database
    var item = new Item { Name = request.Name, Description = request.Description };
    _context.Items.Add(item);
    await _context.SaveChangesAsync();

    // Publish event to Service Bus
    try
    {
        var message = new
        {
            itemId = item.Id.ToString(),
            itemName = item.Name,
            action = "Created",
            timestamp = DateTime.UtcNow
        };

        var messageBody = JsonSerializer.Serialize(message);
        await _serviceBusService.SendMessageAsync("email-notifications-queue", messageBody);

        _logger.LogInformation($"Item created notification published: {item.Id}");
    }
    catch (Exception ex)
    {
        _logger.LogWarning($"Failed to publish notification: {ex.Message}");
        // Don't fail the request if notification fails
    }

    return CreatedAtAction(nameof(GetItem), new { id = item.Id }, item);
}
```

## Troubleshooting

### Function not triggering

```powershell
# 1. Check function is deployed
az functionapp function list `
  --name $functionAppName `
  --resource-group $resourceGroup

# 2. Check app settings
az functionapp config appsettings list `
  --name $functionAppName `
  --resource-group $resourceGroup

# 3. Check Service Bus queue
az servicebus queue show-runtime-properties `
  --resource-group $resourceGroup `
  --namespace-name "sb-registrationapp-eastus" `
  --name "email-notifications-queue"

# 4. View function logs
az webapp log tail `
  --name $functionAppName `
  --resource-group $resourceGroup

# 5. Check if messages are in dead-letter queue
az servicebus queue show-runtime-properties `
  --resource-group $resourceGroup `
  --namespace-name "sb-registrationapp-eastus" `
  --name "email-notifications-queue`$DeadLetterQueue"
```

### Function timeout

```powershell
# Increase function timeout (in host.json)
# {
#   "functionTimeout": "00:05:00"
# }

# Update in Azure
az functionapp config appsettings set `
  --name $functionAppName `
  --resource-group $resourceGroup `
  --settings functionTimeout="00:05:00"
```

### Out of memory

```powershell
# Check function app memory usage
az monitor metrics list `
  --resource /subscriptions/$subscriptionId/resourcegroups/$resourceGroup/providers/microsoft.web/sites/$functionAppName `
  --metric MemoryWorkingSet
```

## Complete Deployment Script

```powershell
# Run all commands in one script
$resourceGroup = "rg-registration-app"
$functionAppName = "func-registrationapp"
$functionStorageName = "stregistrationappfunc"
$functionLocation = "eastus"
$subscriptionId = "af300fa3-a715-4320-8558-efe8a549457e"
$keyVaultName = "kv-registrationapp"

# Step 1: Create storage account
Write-Host "Step 1: Creating storage account..." -ForegroundColor Yellow
az storage account create `
  --name $functionStorageName `
  --resource-group $resourceGroup `
  --location $functionLocation `
  --sku Standard_LRS `
  --kind StorageV2 2>$null

# Step 2: Create Function App
Write-Host "Step 2: Creating Function App..." -ForegroundColor Yellow
az functionapp create `
  --resource-group $resourceGroup `
  --consumption-plan-location $functionLocation `
  --runtime dotnet-isolated `
  --runtime-version 8.0 `
  --functions-version 4 `
  --name $functionAppName `
  --storage-account $functionStorageName `
  --os-type Windows 2>$null

Start-Sleep -Seconds 5

# Step 3: Configure settings
Write-Host "Step 3: Configuring settings..." -ForegroundColor Yellow
$sbConnStr = az keyvault secret show --vault-name $keyVaultName --name "ServiceBusConnectionString" --query value -o tsv
$cosmosConnStr = az keyvault secret show --vault-name $keyVaultName --name "CosmosDbConnectionString" --query value -o tsv
$storageConnStr = az keyvault secret show --vault-name $keyVaultName --name "StorageAccountConnectionString" --query value -o tsv

az functionapp config appsettings set `
  --name $functionAppName `
  --resource-group $resourceGroup `
  --settings `
    AzureWebJobsServiceBusConnectionString=$sbConnStr `
    CosmosDbConnectionString=$cosmosConnStr `
    StorageAccountConnectionString=$storageConnStr `
    FUNCTIONS_WORKER_RUNTIME=dotnet-isolated `
    ASPNETCORE_ENVIRONMENT=Production

Write-Host "✅ Function App deployment complete!" -ForegroundColor Green
Write-Host "Function App Name: $functionAppName" -ForegroundColor Cyan
Write-Host "Resource Group: $resourceGroup" -ForegroundColor Cyan
Write-Host "Next: Create function locally with 'func new' and deploy with 'func azure functionapp publish'" -ForegroundColor Cyan
```

---

**Created**: February 5, 2026
