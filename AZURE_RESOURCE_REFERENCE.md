# Azure Resource Reference for RegistrationApp

**Resource Group**: `rg-registration-app`
**Created**: February 5, 2026

---

## 📋 Complete Resource Inventory

### Existing Resources (Already Created) ✅

#### Key Vaults (Secrets Management)

| Name | Region | Purpose | Status |
|------|--------|---------|--------|
| **kv-registrationapp** | East US | Application secrets, storage keys, API keys | ✅ ACTIVE |
| **regsql-kv-2807** | East US | SQL Server credentials | ✅ ACTIVE |

**Quick Access:**
```bash
# List all secrets in kv-registrationapp
az keyvault secret list --vault-name kv-registrationapp

# Get a specific secret
az keyvault secret show --vault-name kv-registrationapp --name "SqlConnectionString"
```

---

#### SQL Server & Database

| Name | Region | Type | Status |
|------|--------|------|--------|
| **regsql2807** | Central India | SQL Server | ✅ ACTIVE |
| **RegistrationAppDb** | Central India | SQL Database | ✅ ACTIVE |

**Quick Access:**
```bash
# Get SQL Server details
az sql server show --name regsql2807 --resource-group rg-registration-app

# Get database details
az sql db show --server regsql2807 --name RegistrationAppDb --resource-group rg-registration-app

# Connection string format
Server=regsql2807.database.windows.net;Database=RegistrationAppDb;User ID=sqladmin;Password=YOUR_PASSWORD;Encrypt=true;
```

**Database Tables:**
- `Items` - Main application data (Id, Name, Description, CreatedAt)
- (Other tables as configured)

---

#### Container Registry

| Name | Region | Status |
|------|--------|--------|
| **registrationappacr** | East US | ✅ ACTIVE |

**Images Stored:**
- registration-api:latest
- registration-frontend:latest

**Quick Access:**
```bash
# Login to registry
az acr login --name registrationappacr

# List images
az acr repository list --name registrationappacr

# Get full registry URL
az acr show --name registrationappacr --query loginServer -o tsv
# Output: registrationappacr.azurecr.io
```

---

#### Container Instances (Running Applications)

| Name | Region | Purpose | Status |
|------|--------|---------|--------|
| **registration-api-2807** | Central India | Dev/Test API | ✅ RUNNING |
| **registration-api-prod** | Central India | Production API | ✅ RUNNING |
| **registration-frontend-2807** | Central India | Dev/Test Frontend | ✅ RUNNING |
| **registration-frontend-prod** | Central India | Production Frontend | ✅ RUNNING |

**Quick Access:**
```bash
# List all containers
az container list --resource-group rg-registration-app

# Check status
az container show --name registration-api-prod --resource-group rg-registration-app --query instanceView.state

# View logs
az container logs --name registration-api-prod --resource-group rg-registration-app

# Get IP address
az container show --name registration-api-prod --resource-group rg-registration-app --query ipAddress.ip -o tsv
```

---

### New Resources to Create (This Guide)

#### Storage Account (File Uploads)

```bash
# Variable
$storageName = "stregistrationapp2807"
$location = "eastus"

# Status
⏳ TO CREATE - For file uploads, backups, and blob storage
```

**What you'll store:**
- Item images
- Document uploads
- Application backups
- Audit log exports

**Container Paths:**
- `/uploads/` - User uploaded files
- `/item-images/` - Product/item images

---

#### Service Bus Namespace (Async Messaging)

```bash
# Variable
$serviceBusName = "sb-registrationapp-eastus"
$location = "eastus"

# Status
⏳ TO CREATE - For decoupled message processing
```

**Queues to create:**
- `item-created-queue` - Triggered when items are created
- `email-notifications-queue` - For sending emails

**Usage Pattern:**
```
Item Created → API publishes to Service Bus 
            → Azure Function processes 
            → Email sent
```

---

#### Cosmos DB (Audit Logging)

```bash
# Variable
$cosmosName = "cosmos-registrationapp-india"
$location = "centralindia"

# Status
⏳ TO CREATE - For audit trail and analytics
```

**Database Structure:**
- **Database**: RegistrationAppDb
- **Container**: AuditLogs
  - **Partition Key**: /partition
  - **Sample Documents**:
    ```json
    {
      "id": "audit-123",
      "partition": "item-1",
      "itemId": "1",
      "action": "Created",
      "itemName": "Product Name",
      "changedBy": "user@example.com",
      "timestamp": "2026-02-05T10:30:00Z",
      "details": { "field": "value changed" }
    }
    ```

**Queries You Can Run:**
```csharp
// Get audit logs for specific item
SELECT * FROM AuditLogs WHERE itemId = '1'

// Get all deletions
SELECT * FROM AuditLogs WHERE action = 'Deleted'

// Get recent changes
SELECT * FROM AuditLogs WHERE timestamp > '2026-02-01'
```

---

#### Application Insights (Monitoring)

```bash
# Variable
$appInsightsName = "insights-registration-app"
$location = "eastus"

# Status
⏳ TO CREATE - For performance monitoring and diagnostics
```

**What gets tracked:**
- Application events
- Exceptions and errors
- Performance metrics
- Request/response times
- Custom business metrics

---

#### Azure Functions (Serverless Processing)

```bash
# Variable
$functionAppName = "func-registrationapp"
$location = "eastus"

# Status
⏳ TO CREATE - For event-driven processing
```

**Functions to create:**
1. **SendEmailNotification**
   - Trigger: Service Bus queue message
   - Action: Send email via SendGrid
   - Runs when: Items are created or approved

2. **GenerateReport**
   - Trigger: Timer (daily at midnight)
   - Action: Create summary report
   - Stores: In Blob Storage

---

#### Logic Apps (Workflow Automation)

```bash
# Variable
$logicAppName = "logic-item-approval-workflow"
$location = "eastus"

# Status
⏳ TO CREATE - For business process automation
```

**Workflow Steps:**
1. Trigger: New item created in SQL
2. Send approval email to admin
3. Wait for approval response
4. If approved: Send confirmation & store in blob
5. If rejected: Send rejection & log reason

---

## 🔐 Connection Strings & Secrets

### In Key Vault: `kv-registrationapp`

```bash
# List all secrets
az keyvault secret list --vault-name kv-registrationapp

# Create new secrets
az keyvault secret set \
  --vault-name kv-registrationapp \
  --name "StorageAccountConnectionString" \
  --value "DefaultEndpointsProtocol=https;..."
```

**Secrets to Add** (during setup):

| Secret Name | Example Format | Source |
|------------|-------------------|--------|
| SqlConnectionString | Server=regsql2807.database.windows.net;... | SQL Server |
| StorageAccountConnectionString | DefaultEndpointsProtocol=https;... | Storage Account |
| ServiceBusConnectionString | Endpoint=sb://sb-registrationapp... | Service Bus |
| CosmosDbConnectionString | AccountEndpoint=https://cosmos-... | Cosmos DB |
| ApplicationInsightsInstrumentationKey | (GUID format) | App Insights |

---

### In Key Vault: `regsql-kv-2807`

```bash
# SQL Server specific secrets
az keyvault secret list --vault-name regsql-kv-2807
```

**Secrets to Maintain**:

| Secret Name | Current Value |
|------------|----------------|
| SqlAdminUsername | sqladmin |
| SqlAdminPassword | YOUR_PASSWORD |

---

## 📍 Regional Distribution

### East US (Primary/Development)
- ✅ kv-registrationapp (Key Vault)
- ✅ regsql-kv-2807 (Key Vault)
- ✅ registrationappacr (Container Registry)
- ⏳ stregistrationapp2807 (Storage - TO CREATE)
- ⏳ sb-registrationapp-eastus (Service Bus - TO CREATE)
- ⏳ insights-registration-app (App Insights - TO CREATE)
- ⏳ func-registrationapp (Functions - TO CREATE)
- ⏳ logic-item-approval (Logic Apps - TO CREATE)

### Central India (Production/Database)
- ✅ regsql2807 (SQL Server)
- ✅ RegistrationAppDb (Database)
- ✅ registration-api-2807 (Container Instance)
- ✅ registration-api-prod (Container Instance)
- ✅ registration-frontend-2807 (Container Instance)
- ✅ registration-frontend-prod (Container Instance)
- ⏳ cosmos-registrationapp-india (Cosmos DB - TO CREATE)

**Rationale:**
- East US: Development, registry, monitoring (lower cost)
- Central India: Production, database (where users are)
- Cosmos DB in Central India: Audit logs close to production database

---

## 🚀 Quick Setup Commands

### 1. Verify All Existing Resources

```bash
# Login
az login
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Set default group
az configure --defaults group=rg-registration-app

# List all resources
az resource list --query "[].{Name:name, Type:type, Location:location}" -o table

# Should show 12 existing resources + new ones you create
```

### 2. Create Missing Resources (In Order)

```bash
# Phase 1: Storage & Messaging (East US)
# Run Phase 2 section from AZURE_INTEGRATION_GUIDE.md

# Phase 2: Analytics & Database (Central India)
# Run Phase 3 section from AZURE_INTEGRATION_GUIDE.md

# Phase 3: Serverless & Automation (East US)
# Run Phase 4 section from AZURE_INTEGRATION_GUIDE.md
```

### 3. Verify New Resources

```bash
# After creating each resource, verify it exists
az resource list --resource-group rg-registration-app --query "[].{Name:name, Type:type}" -o table

# Total should grow from 12 to 20+ resources
```

---

## 📊 Resource Naming Convention

**Pattern**: `{service}-{project}{purpose}-{region-code}`

**Examples**:
- `kv-registrationapp` = **kv** (Key Vault) + **registrationapp** (project)
- `stregistrationapp2807` = **st** (Storage) + **registrationapp** + **2807** (sequential)
- `sb-registrationapp-eastus` = **sb** (Service Bus) + **registrationapp** + **eastus** (region)
- `cosmos-registrationapp-india` = **cosmos** + **registrationapp** + **india** (region)

**Prefixes Used**:
- `kv` = Key Vault
- `st` = Storage Account
- `sb` = Service Bus
- `cosmos` = Cosmos DB
- `func` = Azure Functions
- `insights` = Application Insights
- `logic` = Logic Apps
- `rg` = Resource Group
- `acr` = Container Registry

---

## 💰 Cost Breakdown (Monthly)

### Existing Resources
| Service | Cost/Month | Notes |
|---------|-----------|-------|
| Container Instances (4) | ~$150-200 | Running 24/7 |
| SQL Server | ~$15-30 | Basic tier |
| Key Vaults (2) | ~$0.68 | Standard tier |
| Container Registry | ~$5-10 | Basic tier |
| **Subtotal** | **~$170-240** | Current |

### New Resources (To Create)
| Service | Cost/Month | Notes |
|---------|-----------|-------|
| Storage Account | ~$1-2 | Standard LRS |
| Service Bus | ~$10 | Standard tier |
| Cosmos DB | ~$25 | 400 RU/s baseline |
| App Insights | ~$2-5 | Pay-as-you-go |
| Functions | ~$0-15 | Consumption plan |
| Logic Apps | ~$0-5 | Per execution |
| **Subtotal** | **~$38-42** | New services |

**Total**: ~$208-282/month for complete setup

---

## 🔑 Useful Azure CLI Commands for Your Setup

### Check Resource Status

```bash
# All resources in group
az resource list --resource-group rg-registration-app

# Specific service health
az container show --name registration-api-prod --resource-group rg-registration-app
az sql server show --name regsql2807 --resource-group rg-registration-app
az keyvault show --name kv-registrationapp --resource-group rg-registration-app
```

### Manage Secrets

```bash
# View all secrets (names only)
az keyvault secret list --vault-name kv-registrationapp

# Get specific secret value
az keyvault secret show --vault-name kv-registrationapp --name "SqlConnectionString" --query value -o tsv

# Update secret
az keyvault secret set --vault-name kv-registrationapp --name "SqlConnectionString" --value "new_value"

# Add new secret
az keyvault secret set --vault-name kv-registrationapp --name "NewSecretName" --value "secret_value"
```

### Container Management

```bash
# Restart a container
az container restart --name registration-api-prod --resource-group rg-registration-app

# Get container logs (last 50 lines)
az container logs --name registration-api-prod --resource-group rg-registration-app --tail 50

# Check container IP
az container show --name registration-api-prod --resource-group rg-registration-app --query ipAddress.ip -o tsv

# Stop container
az container stop --name registration-api-prod --resource-group rg-registration-app

# Start container
az container start --name registration-api-prod --resource-group rg-registration-app
```

### Database Management

```bash
# Database details
az sql db show --server regsql2807 --name RegistrationAppDb --resource-group rg-registration-app

# List tables
sqlcmd -S regsql2807.database.windows.net -U sqladmin -P PASSWORD -d RegistrationAppDb -Q "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES"

# Run query
sqlcmd -S regsql2807.database.windows.net -U sqladmin -P PASSWORD -d RegistrationAppDb -Q "SELECT COUNT(*) FROM Items"
```

---

## 📞 Support & Documentation

**Microsoft Learn** (Free training):
- https://learn.microsoft.com/en-us/training/modules/
  - Search for: "Azure Key Vault", "Azure Storage", "Cosmos DB", "Service Bus", "Functions", "Logic Apps"

**Official Documentation**:
- Azure CLI: https://docs.microsoft.com/cli/azure/
- Resource Manager: https://docs.microsoft.com/en-us/azure/azure-resource-manager/
- Services: https://docs.microsoft.com/en-us/azure/

**Support**:
- Azure Portal: Help + support section
- Stack Overflow: Tag with service name + azure
- GitHub Issues: For SDK-specific problems

---

## ✅ Implementation Checklist

### Resources (Create in This Order)

- [ ] **Storage Account** (East US)
  - [ ] Create account
  - [ ] Create containers (uploads, item-images)
  - [ ] Get connection string
  - [ ] Add to Key Vault

- [ ] **Service Bus** (East US)
  - [ ] Create namespace
  - [ ] Create queues (item-created, email-notifications)
  - [ ] Get connection string
  - [ ] Add to Key Vault

- [ ] **Cosmos DB** (Central India)
  - [ ] Create account
  - [ ] Create database
  - [ ] Create container
  - [ ] Get connection string
  - [ ] Add to Key Vault

- [ ] **Application Insights** (East US)
  - [ ] Create resource
  - [ ] Get instrumentation key
  - [ ] Add to Key Vault

- [ ] **Azure Functions** (East US)
  - [ ] Create Function App
  - [ ] Create SendEmailNotification function
  - [ ] Create GenerateReport function
  - [ ] Configure connections

- [ ] **Logic Apps** (East US)
  - [ ] Create Logic App
  - [ ] Configure approval workflow
  - [ ] Test workflow

### Application Updates

- [ ] Update `appsettings.json` with connection strings
- [ ] Install NuGet packages (`dotnet restore`)
- [ ] Build application (`dotnet build`)
- [ ] Test locally (`dotnet run`)
- [ ] Deploy to Container Registry
- [ ] Update Container Instances with new image
- [ ] Verify all services working in Application Insights

---

**Last Updated**: February 5, 2026
**Status**: Reference guide for your specific resource group
**Next Step**: Follow AZURE_INTEGRATION_GUIDE.md Phase 2 onwards

