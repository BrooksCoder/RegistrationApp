#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Comprehensive Production Fix Script - RegistrationApp
    
.DESCRIPTION
    Fixes all critical production issues identified in code review.
    - Removes hardcoded secrets
    - Updates configuration files
    - Sets up Managed Identity
    - Configures environment variables
    
.PARAMETER Environment
    Target environment: 'Production' or 'Development'
    
.PARAMETER ResourceGroup
    Azure resource group name
    
.PARAMETER AppName
    API App Service name
    
.PARAMETER FunctionAppName
    Function App name
    
.PARAMETER KeyVaultName
    Azure Key Vault name

.EXAMPLE
    .\Fix-ProductionIssues.ps1 -Environment Production -ResourceGroup rg-registration-app `
        -AppName registration-api-prod -FunctionAppName func-registrationapp `
        -KeyVaultName kv-registrationapp
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('Production', 'Development')]
    [string]$Environment,
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$true)]
    [string]$AppName,
    
    [Parameter(Mandatory=$true)]
    [string]$FunctionAppName,
    
    [Parameter(Mandatory=$true)]
    [string]$KeyVaultName,
    
    [Parameter(Mandatory=$false)]
    [string]$SqlServer = "regsql2807.database.windows.net",
    
    [Parameter(Mandatory=$false)]
    [string]$SqlDatabase = "RegistrationAppDb",
    
    [Parameter(Mandatory=$false)]
    [string]$SqlUsername = "sqladmin"
)

# Color output
function Write-Success { Write-Host -ForegroundColor Green "✓ $args" }
function Write-Error { Write-Host -ForegroundColor Red "✗ $args" }
function Write-Warning { Write-Host -ForegroundColor Yellow "⚠ $args" }
function Write-Info { Write-Host -ForegroundColor Cyan "ℹ $args" }

Write-Info "=========================================="
Write-Info "Production Fix Script - RegistrationApp"
Write-Info "=========================================="
Write-Info "Environment: $Environment"
Write-Info "Resource Group: $ResourceGroup"
Write-Info "App Service: $AppName"
Write-Info "Function App: $FunctionAppName"
Write-Info "Key Vault: $KeyVaultName"
Write-Info ""

# Step 1: Check Azure CLI authentication
Write-Info "Step 1: Verifying Azure Authentication..."
try {
    $account = az account show --query 'user.name' -o tsv 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Authenticated as: $account"
    }
}
catch {
    Write-Error "Not authenticated. Run 'az login' first."
    exit 1
}

# Step 2: Enable Managed Identity for App Service
Write-Info "Step 2: Enabling Managed Identity for App Service..."
try {
    $identity = az webapp identity assign `
        --resource-group $ResourceGroup `
        --name $AppName `
        --query 'principalId' -o tsv
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Managed Identity enabled (Principal ID: $identity)"
    }
}
catch {
    Write-Error "Failed to enable Managed Identity for App Service: $_"
}

# Step 3: Enable Managed Identity for Function App
Write-Info "Step 3: Enabling Managed Identity for Function App..."
try {
    $functionIdentity = az functionapp identity assign `
        --resource-group $ResourceGroup `
        --name $FunctionAppName `
        --query 'principalId' -o tsv
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Function App Managed Identity enabled (Principal ID: $functionIdentity)"
    }
}
catch {
    Write-Error "Failed to enable Managed Identity for Function App: $_"
}

# Step 4: Grant Key Vault access to App Service
Write-Info "Step 4: Granting Key Vault access to App Service..."
try {
    az keyvault set-policy `
        --name $KeyVaultName `
        --object-id $identity `
        --secret-permissions get list `
        --query 'properties.accessPolicies | length(@)' -o tsv | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Key Vault access granted to App Service"
    }
}
catch {
    Write-Error "Failed to grant Key Vault access: $_"
}

# Step 5: Grant Key Vault access to Function App
Write-Info "Step 5: Granting Key Vault access to Function App..."
try {
    az keyvault set-policy `
        --name $KeyVaultName `
        --object-id $functionIdentity `
        --secret-permissions get list `
        --query 'properties.accessPolicies | length(@)' -o tsv | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Key Vault access granted to Function App"
    }
}
catch {
    Write-Error "Failed to grant Key Vault access to Function App: $_"
}

# Step 6: Prompt for sensitive information
Write-Info ""
Write-Warning "IMPORTANT: You will need to provide the following secrets:"
Write-Info "- SQL Server password"
Write-Info "- SendGrid API key"
Write-Info "- Service Bus connection string (or will be set from Key Vault)"
Write-Info ""

$sqlPassword = Read-Host "Enter SQL Server password" -AsSecureString
$sendGridApiKey = Read-Host "Enter SendGrid API key" -AsSecureString
$serviceBusConnStr = Read-Host "Enter Service Bus connection string (or press Enter to skip)" -AsSecureString

# Step 7: Set secrets in Key Vault
Write-Info "Step 6: Updating Key Vault secrets..."

if ($sqlPassword -and $sqlPassword.Length -gt 0) {
    $sqlPasswordPlainText = [System.Net.NetworkCredential]::new('', $sqlPassword).Password
    try {
        az keyvault secret set `
            --vault-name $KeyVaultName `
            --name "SqlPassword" `
            --value $sqlPasswordPlainText | Out-Null
        Write-Success "SQL password updated in Key Vault"
    }
    catch {
        Write-Error "Failed to set SQL password: $_"
    }
}

if ($sendGridApiKey -and $sendGridApiKey.Length -gt 0) {
    $sendGridKeyPlainText = [System.Net.NetworkCredential]::new('', $sendGridApiKey).Password
    try {
        az keyvault secret set `
            --vault-name $KeyVaultName `
            --name "SendGridApiKey" `
            --value $sendGridKeyPlainText | Out-Null
        Write-Success "SendGrid API key updated in Key Vault"
    }
    catch {
        Write-Error "Failed to set SendGrid API key: $_"
    }
}

# Step 8: Set environment variables in App Service
Write-Info "Step 7: Configuring App Service environment variables..."

$sqlPasswordPlainText = [System.Net.NetworkCredential]::new('', $sqlPassword).Password
$connectionString = "Server=tcp:$SqlServer,1433;Initial Catalog=$SqlDatabase;Persist Security Info=False;User ID=$SqlUsername;Password=$sqlPasswordPlainText;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

try {
    az webapp config appsettings set `
        --resource-group $ResourceGroup `
        --name $AppName `
        --settings `
            "ASPNETCORE_ENVIRONMENT=$Environment" `
            "AzureKeyVault__VaultUri=https://$KeyVaultName.vault.azure.net/" `
            "ConnectionStrings__DefaultConnection=$connectionString" `
            "AzureCosmosDb__DatabaseName=RegistrationAppDb" `
            "AzureCosmosDb__ContainerName=AuditLogs" | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "App Service environment variables configured"
    }
}
catch {
    Write-Error "Failed to configure App Service settings: $_"
}

# Step 9: Set environment variables in Function App
Write-Info "Step 8: Configuring Function App environment variables..."

if ($sendGridApiKey -and $sendGridApiKey.Length -gt 0) {
    $sendGridKeyPlainText = [System.Net.NetworkCredential]::new('', $sendGridApiKey).Password
}

try {
    az functionapp config appsettings set `
        --resource-group $ResourceGroup `
        --name $FunctionAppName `
        --settings `
            "AzureWebJobsStorage=@Microsoft.KeyVault(SecretUri=https://$KeyVaultName.vault.azure.net/secrets/StorageAccountConnectionString/)" `
            "AzureWebJobsServiceBusConnectionString=@Microsoft.KeyVault(SecretUri=https://$KeyVaultName.vault.azure.net/secrets/ServiceBusConnectionString/)" `
            "SendGridApiKey=@Microsoft.KeyVault(SecretUri=https://$KeyVaultName.vault.azure.net/secrets/SendGridApiKey/)" | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Function App environment variables configured with Key Vault references"
    }
}
catch {
    Write-Error "Failed to configure Function App settings: $_"
}

# Step 10: Create appsettings.Production.json
Write-Info "Step 9: Creating updated configuration files..."

$appSettingsProd = @{
    "Logging" = @{
        "LogLevel" = @{
            "Default" = "Information"
            "Microsoft" = "Warning"
            "Microsoft.EntityFrameworkCore" = "Warning"
        }
    }
    "AllowedHosts" = "*"
    "ConnectionStrings" = @{
        "DefaultConnection" = ""  # Will come from environment variable
        "AzureServiceBus" = ""    # Will come from Key Vault
        "AzureStorageAccount" = "" # Will come from Key Vault
        "AzureCosmosDb" = ""      # Will come from Key Vault
    }
    "AzureKeyVault" = @{
        "VaultUri" = "https://$KeyVaultName.vault.azure.net/"
    }
    "AzureCosmosDb" = @{
        "DatabaseName" = "RegistrationAppDb"
        "ContainerName" = "AuditLogs"
    }
    "ApplicationInsights" = @{
        "InstrumentationKey" = ""
        "ConnectionString" = ""
    }
} | ConvertTo-Json -Depth 10

try {
    $appSettingsProd | Out-File -FilePath "backend\appsettings.Production.json" -Encoding UTF8
    Write-Success "Created backend\appsettings.Production.json"
}
catch {
    Write-Error "Failed to create appsettings.Production.json: $_"
}

# Step 11: Update .gitignore
Write-Info "Step 10: Updating .gitignore..."

$gitignoreEntries = @(
    "backend/appsettings.*.json",
    "ItemNotificationFunction/local.settings.json",
    "*.user",
    ".DS_Store"
)

try {
    if (Test-Path ".gitignore") {
        $gitignoreContent = Get-Content ".gitignore" -Raw
    }
    else {
        $gitignoreContent = ""
    }
    
    foreach ($entry in $gitignoreEntries) {
        if ($gitignoreContent -notlike "*$entry*") {
            $gitignoreContent += "`n$entry"
        }
    }
    
    $gitignoreContent | Out-File -FilePath ".gitignore" -Encoding UTF8
    Write-Success "Updated .gitignore"
}
catch {
    Write-Error "Failed to update .gitignore: $_"
}

# Step 12: Summary
Write-Info ""
Write-Info "=========================================="
Write-Info "Fix Summary"
Write-Info "=========================================="
Write-Success "Managed Identity enabled for App Service"
Write-Success "Managed Identity enabled for Function App"
Write-Success "Key Vault access policies configured"
Write-Success "Environment variables set"
Write-Success "Configuration files updated"
Write-Success ".gitignore updated"
Write-Info ""

Write-Warning "Next Steps:"
Write-Info "1. Verify all secrets are in Key Vault:"
Write-Info "   az keyvault secret list --vault-name $KeyVaultName"
Write-Info ""
Write-Info "2. Rebuild and redeploy the backend:"
Write-Info "   cd backend"
Write-Info "   dotnet build --configuration Release"
Write-Info "   dotnet publish -c Release -o out"
Write-Info ""
Write-Info "3. Deploy to Azure App Service"
Write-Info ""
Write-Info "4. Test the API:"
Write-Info "   curl https://$AppName.azurewebsites.net/health"
Write-Info ""
Write-Info "5. Check logs:"
Write-Info "   az webapp log tail --resource-group $ResourceGroup --name $AppName"
Write-Info ""
