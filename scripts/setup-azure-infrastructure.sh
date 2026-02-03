#!/bin/bash

# Azure Infrastructure Setup Script
# This script creates all necessary Azure resources for the Registration Application

set -e

# Configuration variables
SUBSCRIPTION_ID="your-subscription-id"
RESOURCE_GROUP="rg-registration-app"
LOCATION="East US"
SQL_SERVER_NAME="registration-sql-$(date +%s)"
SQL_DATABASE_NAME="RegistrationAppDb"
SQL_ADMIN_USER="sqladmin"
SQL_ADMIN_PASSWORD="YourSecurePassword123!@#"  # Change this!
APP_SERVICE_PLAN="asp-registration-app"
BACKEND_APP_NAME="registration-api-$(date +%s | tail -c 6)"
FRONTEND_APP_NAME="registration-app-$(date +%s | tail -c 6)"
KEY_VAULT_NAME="registration-kv-$(date +%s | tail -c 6)"

echo "==============================================="
echo "Azure Infrastructure Setup"
echo "==============================================="
echo ""

# Login to Azure
echo "Logging in to Azure..."
az login
az account set --subscription $SUBSCRIPTION_ID

# Create Resource Group
echo "Creating resource group..."
az group create \
  --name $RESOURCE_GROUP \
  --location "$LOCATION"

# Create Key Vault
echo "Creating Key Vault..."
az keyvault create \
  --name $KEY_VAULT_NAME \
  --resource-group $RESOURCE_GROUP \
  --location "$LOCATION"

# Create SQL Server
echo "Creating SQL Server..."
az sql server create \
  --resource-group $RESOURCE_GROUP \
  --name $SQL_SERVER_NAME \
  --location "$LOCATION" \
  --admin-user $SQL_ADMIN_USER \
  --admin-password $SQL_ADMIN_PASSWORD

# Configure SQL Server Firewall
echo "Configuring SQL Server firewall..."
az sql server firewall-rule create \
  --resource-group $RESOURCE_GROUP \
  --server $SQL_SERVER_NAME \
  --name "AllowAzureServices" \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0

# Create SQL Database
echo "Creating SQL Database..."
az sql db create \
  --resource-group $RESOURCE_GROUP \
  --server $SQL_SERVER_NAME \
  --name $SQL_DATABASE_NAME \
  --edition Standard \
  --service-objective S0

# Store connection string in Key Vault
echo "Storing connection string in Key Vault..."
CONNECTION_STRING="Server=tcp:${SQL_SERVER_NAME}.database.windows.net,1433;Initial Catalog=${SQL_DATABASE_NAME};Persist Security Info=False;User ID=${SQL_ADMIN_USER};Password=${SQL_ADMIN_PASSWORD};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --name "DbConnectionString" \
  --value "$CONNECTION_STRING"

# Create App Service Plan
echo "Creating App Service Plan..."
az appservice plan create \
  --name $APP_SERVICE_PLAN \
  --resource-group $RESOURCE_GROUP \
  --sku B1 \
  --is-linux

# Create Backend Web App
echo "Creating Backend Web App..."
az webapp create \
  --resource-group $RESOURCE_GROUP \
  --plan $APP_SERVICE_PLAN \
  --name $BACKEND_APP_NAME \
  --runtime "DOTNETCORE:8.0" \
  --runtime-version 8.0

# Configure connection string for Backend
echo "Configuring Backend connection string..."
az webapp config connection-string set \
  --name $BACKEND_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --connection-string-type SQLAzure \
  --settings DefaultConnection="$CONNECTION_STRING"

# Enable HTTPS only
az webapp update \
  --name $BACKEND_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --https-only true

# Create Storage Account for Static Web App
echo "Creating Storage Account..."
STORAGE_ACCOUNT="registration${RANDOM}"
az storage account create \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --location "$LOCATION" \
  --sku Standard_LRS

# Create Container for Frontend
echo "Creating Storage Container..."
az storage container create \
  --name '$web' \
  --account-name $STORAGE_ACCOUNT \
  --public-access blob

# Output summary
echo ""
echo "==============================================="
echo "Infrastructure Setup Complete!"
echo "==============================================="
echo ""
echo "Resource Group: $RESOURCE_GROUP"
echo "SQL Server: $SQL_SERVER_NAME.database.windows.net"
echo "SQL Database: $SQL_DATABASE_NAME"
echo "Backend App: https://${BACKEND_APP_NAME}.azurewebsites.net"
echo "Key Vault: $KEY_VAULT_NAME"
echo "Storage Account: $STORAGE_ACCOUNT"
echo ""
echo "Next steps:"
echo "1. Deploy backend application"
echo "2. Apply database migrations"
echo "3. Deploy frontend application"
echo "4. Configure custom domain (optional)"
echo "5. Enable Azure Defender for SQL"
echo ""
