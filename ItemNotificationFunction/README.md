# Item Notification Function - Azure Function App

This is an Azure Function that processes Service Bus messages and sends email notifications using SendGrid.

## Architecture

```
Service Bus Message (email-notifications-queue)
         ↓
Service Bus Trigger
         ↓
SendEmailNotification Function
         ↓
SendGrid Email API
         ↓
Email Sent to Recipient
```

## Prerequisites

- Azure Functions Core Tools v4+
- .NET 8.0 SDK
- Azure CLI
- SendGrid API Key (free tier available)

## Function Details

**Trigger**: Azure Service Bus Queue
- **Queue Name**: `email-notifications-queue`
- **Connection**: `AzureWebJobsServiceBusConnectionString`

**Output**: Email via SendGrid
- **API Key**: `SendGridApiKey`
- **From Email**: noreply@registrationapp.com

## Configuration

### 1. Local Development (local.settings.json)

```json
{
    "IsEncrypted": false,
    "Values": {
        "AzureWebJobsStorage": "UseDevelopmentStorage=true",
        "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
        "AzureWebJobsServiceBusConnectionString": "YOUR_SERVICE_BUS_CONNECTION_STRING",
        "SendGridApiKey": "YOUR_SENDGRID_API_KEY"
    }
}
```

### 2. Get Connection Strings from Key Vault

```powershell
$resourceGroup = "rg-registration-app"
$keyVaultName = "kv-registrationapp"

# Get Service Bus connection string
$sbConnStr = az keyvault secret show --vault-name $keyVaultName --name "ServiceBusConnectionString" --query value -o tsv
Write-Host "Service Bus: $sbConnStr"

# For SendGrid, you'll need to create a secret first
$sendGridKey = "YOUR_SENDGRID_API_KEY"
az keyvault secret set --vault-name $keyVaultName --name "SendGridApiKey" --value $sendGridKey
```

### 3. Update local.settings.json

Replace the placeholders with actual values:

```powershell
$sbConnStr = "Endpoint=sb://sb-registrationapp-eastus.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=..."
$sendGridKey = "SG.xxxxxxxxxxxxxxxxxxxx"

# Update local.settings.json with real values
```

## Building

```bash
dotnet build
```

## Running Locally

### 1. Start Azure Storage Emulator (optional, for storage binding)

```bash
# If using Azure Storage Emulator
azurite --silent --location c:\temp\azurite
```

### 2. Start Function App

```bash
func start
```

This will output:
```
Functions:

    SendEmailNotification: serviceBusTrigger
        Trigger: servicebus
        auth level: anonymous
        queueName: email-notifications-queue
```

### 3. Test the Function

Send a message to the Service Bus queue:

```powershell
$resourceGroup = "rg-registration-app"
$serviceBusName = "sb-registrationapp-eastus"
$queueName = "email-notifications-queue"

$testMessage = @{
    ItemName = "Test Item"
    Description = "This is a test item"
    RecipientEmail = "admin@example.com"
    RecipientName = "Admin User"
    CreatedBy = "Test User"
    CreatedAt = [DateTime]::Now
} | ConvertTo-Json

az servicebus queue send `
  --resource-group $resourceGroup `
  --namespace-name $serviceBusName `
  --queue-name $queueName `
  --message-body $testMessage
```

## Deploying to Azure

### 1. Prepare Local Build

```bash
cd C:\Users\Admin\source\repos\RegistrationApp\ItemNotificationFunction
dotnet build --configuration Release
```

### 2. Publish to Function App

```powershell
$functionAppName = "func-registrationapp"
$resourceGroup = "rg-registration-app"

func azure functionapp publish $functionAppName
```

### 3. Configure Function App Settings

```powershell
$resourceGroup = "rg-registration-app"
$functionAppName = "func-registrationapp"

# Get connection strings from Key Vault
$sbConnStr = az keyvault secret show --vault-name kv-registrationapp --name "ServiceBusConnectionString" --query value -o tsv
$sendGridKey = "YOUR_SENDGRID_API_KEY"

# Set as Function App application settings
az functionapp config appsettings set `
  --name $functionAppName `
  --resource-group $resourceGroup `
  --settings `
    AzureWebJobsServiceBusConnectionString=$sbConnStr `
    SendGridApiKey=$sendGridKey
```

### 4. Verify Deployment

```powershell
# List functions in the app
az functionapp function list --name $functionAppName --resource-group $resourceGroup

# View function details
az functionapp function show --name SendEmailNotification --function-name SendEmailNotification --resource-group $resourceGroup --name $functionAppName
```

### 5. Monitor Function Execution

```powershell
# View real-time logs
az functionapp log tail --name $functionAppName --resource-group $resourceGroup

# Or in Azure Portal:
# Function App > SendEmailNotification > Monitor > Logs
```

## Message Format

The Function expects messages in the following format:

```json
{
  "itemName": "Item Name",
  "description": "Item Description",
  "recipientEmail": "user@example.com",
  "recipientName": "User Name",
  "createdBy": "Creator Name",
  "createdAt": "2026-02-05T12:00:00Z"
}
```

## Error Handling

- **Missing SendGrid API Key**: Function logs warning and returns gracefully
- **Invalid JSON**: Message is abandoned (not retried)
- **SendGrid API Error**: Message is abandoned and logged
- **Other Exceptions**: Message is abandoned for retry

## Troubleshooting

### Function not triggering

```powershell
# Check Service Bus queue
az servicebus queue show-runtime-properties `
  --resource-group rg-registration-app `
  --namespace-name sb-registrationapp-eastus `
  --name email-notifications-queue

# Check for messages in dead-letter queue
az servicebus queue show-runtime-properties `
  --resource-group rg-registration-app `
  --namespace-name sb-registrationapp-eastus `
  --name "email-notifications-queue`$DeadLetterQueue"
```

### Connection string issues

```powershell
# Test connection locally
$connStr = "YOUR_CONNECTION_STRING"
# Update local.settings.json and try func start again
```

### SendGrid API errors

1. Verify API key is correct
2. Check SendGrid account has email sending enabled
3. Verify sender email is authorized

## Cost Estimation

- **Service Bus**: ~$10/month (Standard tier)
- **Function App**: ~$0-15/month (Consumption plan, pay per execution)
- **SendGrid**: $0/month (Free tier: 100 emails/day)

## Next Steps

1. Create a trigger in the backend API to publish messages to Service Bus
2. Configure the Logic App to work with this Function
3. Monitor execution via Application Insights
4. Set up alerts for function failures

## Resources

- [Azure Functions Documentation](https://docs.microsoft.com/azure/azure-functions/)
- [Service Bus Bindings](https://docs.microsoft.com/azure/azure-functions/functions-bindings-service-bus)
- [SendGrid Integration](https://docs.microsoft.com/azure/azure-functions/functions-integrate-storage-sendgrid)
