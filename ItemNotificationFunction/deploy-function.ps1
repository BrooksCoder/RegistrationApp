#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploy ItemNotificationFunction to Azure

.DESCRIPTION
    This script deploys the ItemNotificationFunction to your Azure Function App
    and configures all necessary settings from Key Vault

.PARAMETER FunctionAppName
    Name of the Azure Function App (default: func-registrationapp)

.PARAMETER ResourceGroup
    Name of the resource group (default: rg-registration-app)

.EXAMPLE
    .\deploy-function.ps1 -FunctionAppName func-registrationapp -ResourceGroup rg-registration-app
#>

param(
    [string]$FunctionAppName = "func-registrationapp",
    [string]$ResourceGroup = "rg-registration-app",
    [string]$KeyVaultName = "kv-registrationapp"
)

# Colors for output
$InfoColor = "Cyan"
$SuccessColor = "Green"
$WarningColor = "Yellow"
$ErrorColor = "Red"

function Write-Section {
    param([string]$Text)
    Write-Host ""
    Write-Host "═" * 70 -ForegroundColor $InfoColor
    Write-Host "  $Text" -ForegroundColor $InfoColor
    Write-Host "═" * 70 -ForegroundColor $InfoColor
    Write-Host ""
}

function Write-Step {
    param([string]$Text)
    Write-Host "→ $Text" -ForegroundColor $InfoColor
}

function Write-Success {
    param([string]$Text)
    Write-Host "✅ $Text" -ForegroundColor $SuccessColor
}

function Write-Warning {
    param([string]$Text)
    Write-Host "⚠️  $Text" -ForegroundColor $WarningColor
}

function Write-Error {
    param([string]$Text)
    Write-Host "❌ $Text" -ForegroundColor $ErrorColor
}

try {
    Write-Section "ItemNotificationFunction - Deployment Script"
    
    # Step 1: Verify prerequisites
    Write-Step "Verifying prerequisites..."
    
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        Write-Error "Azure CLI not found. Please install Azure CLI."
        exit 1
    }
    Write-Success "Azure CLI installed"
    
    if (-not (Get-Command func -ErrorAction SilentlyContinue)) {
        Write-Warning "Azure Functions Core Tools not found. Installing..."
        npm install -g azure-functions-core-tools@4 --unsafe-perm true
    }
    Write-Success "Azure Functions Core Tools available"
    
    # Step 2: Verify Function App exists
    Write-Step "Verifying Function App: $FunctionAppName"
    
    $functionApp = az functionapp show `
        --name $FunctionAppName `
        --resource-group $ResourceGroup `
        --query name -o tsv 2>/dev/null
    
    if (-not $functionApp) {
        Write-Error "Function App '$FunctionAppName' not found in resource group '$ResourceGroup'"
        exit 1
    }
    Write-Success "Function App found: $functionApp"
    
    # Step 3: Get connection strings from Key Vault
    Write-Step "Retrieving connection strings from Key Vault: $KeyVaultName"
    
    $sbConnStr = az keyvault secret show `
        --vault-name $KeyVaultName `
        --name "ServiceBusConnectionString" `
        --query value -o tsv 2>/dev/null
    
    if (-not $sbConnStr) {
        Write-Error "ServiceBusConnectionString not found in Key Vault"
        Write-Warning "Please set it using: az keyvault secret set --vault-name $KeyVaultName --name 'ServiceBusConnectionString' --value 'YOUR_CONNECTION_STRING'"
        exit 1
    }
    Write-Success "Service Bus connection string retrieved"
    
    # Step 4: Check for SendGrid API Key
    Write-Step "Checking SendGrid API Key in Key Vault"
    
    $sendGridKey = az keyvault secret show `
        --vault-name $KeyVaultName `
        --name "SendGridApiKey" `
        --query value -o tsv 2>/dev/null
    
    if (-not $sendGridKey) {
        Write-Warning "SendGrid API Key not found in Key Vault"
        Write-Warning "Email notifications will be skipped. To enable:"
        Write-Warning "1. Get SendGrid API key from https://sendgrid.com/ (free tier available)"
        Write-Warning "2. Save it: az keyvault secret set --vault-name $KeyVaultName --name 'SendGridApiKey' --value 'YOUR_KEY'"
        $sendGridKey = ""
    } else {
        Write-Success "SendGrid API Key found"
    }
    
    # Step 5: Build the function
    Write-Section "Building Function App"
    
    Write-Step "Building project..."
    $currentLocation = Get-Location
    Set-Location "$PSScriptRoot"
    
    dotnet build --configuration Release
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Build failed"
        Set-Location $currentLocation
        exit 1
    }
    Write-Success "Build completed successfully"
    
    # Step 6: Deploy to Azure
    Write-Section "Deploying to Azure"
    
    Write-Step "Publishing function to Azure..."
    func azure functionapp publish $FunctionAppName --build-native-deps
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Deployment failed"
        Set-Location $currentLocation
        exit 1
    }
    Write-Success "Function published to Azure"
    
    # Step 7: Configure application settings
    Write-Section "Configuring Function App Settings"
    
    Write-Step "Setting application settings..."
    
    $settings = @(
        "AzureWebJobsServiceBusConnectionString=$sbConnStr"
    )
    
    if ($sendGridKey) {
        $settings += "SendGridApiKey=$sendGridKey"
    }
    
    az functionapp config appsettings set `
        --name $FunctionAppName `
        --resource-group $ResourceGroup `
        --settings $settings | Out-Null
    
    Write-Success "Application settings configured"
    
    # Step 8: Verify deployment
    Write-Section "Verifying Deployment"
    
    Write-Step "Listing functions in $FunctionAppName..."
    az functionapp function list `
        --name $FunctionAppName `
        --resource-group $ResourceGroup `
        --query "[].{Name:name, Trigger:trigger.type}" `
        --output table
    
    # Step 9: Display monitoring information
    Write-Section "Deployment Complete!"
    
    Write-Host "📊 Monitor your function:" -ForegroundColor $SuccessColor
    Write-Host "   • Azure Portal: https://portal.azure.com/#@/resource/subscriptions/*/resourceGroups/$ResourceGroup/providers/Microsoft.Web/sites/$FunctionAppName"
    Write-Host ""
    Write-Host "📋 View live logs:" -ForegroundColor $SuccessColor
    Write-Host "   az functionapp log tail --name $FunctionAppName --resource-group $ResourceGroup"
    Write-Host ""
    Write-Host "🧪 Test the function:" -ForegroundColor $SuccessColor
    Write-Host "   Send a message to the Service Bus queue:"
    Write-Host ""
    Write-Host "   `$message = @{" -ForegroundColor $WarningColor
    Write-Host "     itemName = 'Test Item'" -ForegroundColor $WarningColor
    Write-Host "     description = 'Test'" -ForegroundColor $WarningColor
    Write-Host "     recipientEmail = 'admin@example.com'" -ForegroundColor $WarningColor
    Write-Host "     recipientName = 'Admin'" -ForegroundColor $WarningColor
    Write-Host "     createdBy = 'Test'" -ForegroundColor $WarningColor
    Write-Host "     createdAt = [DateTime]::Now" -ForegroundColor $WarningColor
    Write-Host "   } | ConvertTo-Json" -ForegroundColor $WarningColor
    Write-Host ""
    Write-Host "   az servicebus queue send \" -ForegroundColor $WarningColor
    Write-Host "     --resource-group $ResourceGroup \" -ForegroundColor $WarningColor
    Write-Host "     --namespace-name sb-registrationapp-eastus \" -ForegroundColor $WarningColor
    Write-Host "     --queue-name email-notifications-queue \" -ForegroundColor $WarningColor
    Write-Host "     --message-body `$message" -ForegroundColor $WarningColor
    Write-Host ""
    
    Set-Location $currentLocation
    Write-Success "Deployment script completed successfully!"
}
catch {
    Write-Error "An error occurred: $_"
    exit 1
}
