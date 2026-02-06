# Azure Services Implementation Checklist

## Phase 1: Foundation Setup ✅ (COMPLETED)

### Code Implementation
- [x] Create `KeyVaultService.cs` - Retrieve secrets from Azure Key Vault
- [x] Create `ApplicationInsightsService.cs` - Track events and exceptions
- [x] Update `Program.cs` - Register Key Vault and App Insights
- [x] Update `appsettings.json` - Add Azure service configuration keys

### Testing
- [ ] Install Azure CLI
- [ ] Login to Azure account: `az login`
- [ ] Create Key Vault in Azure Portal
- [ ] Create Application Insights resource
- [ ] Update connection strings in appsettings.json
- [ ] Run application and verify no errors
- [ ] Check Application Insights metrics in Azure Portal

---

## Phase 2: Storage & Messaging ✅ (COMPLETED)

### Code Implementation
- [x] Create `AzureStorageService.cs` - Upload/download files from Blob Storage
  - [x] UploadFileAsync() method
  - [x] DownloadFileAsync() method
  - [x] DeleteFileAsync() method
  - [x] ListFilesAsync() method
  - [x] GetFileSasUriAsync() for signed URLs
- [x] Create `AzureServiceBusService.cs` - Publish/subscribe messages
  - [x] SendMessageAsync() to queue
  - [x] PublishEventAsync() to topic
  - [x] GetQueueMessageCountAsync()
- [x] Register services in Program.cs
- [x] Update ItemsController to use services

### Testing
- [ ] Create Storage Account in Azure
- [ ] Create blob containers: "uploads", "item-images"
- [ ] Create Service Bus namespace
- [ ] Create queues: "item-created-queue", "email-notifications-queue"
- [ ] Update connection strings
- [ ] Test file upload: `POST /api/items/1/upload-image`
- [ ] Verify file appears in Azure Storage
- [ ] Verify message appears in Service Bus queue

---

## Phase 3: Analytics & Audit ✅ (COMPLETED)

### Code Implementation
- [x] Create `AzureCosmosDbService.cs` - Store audit logs
  - [x] Create `AuditLog` model class
  - [x] LogAuditAsync() method
  - [x] GetAuditLogsAsync() method
  - [x] GetAuditLogsByActionAsync() method
  - [x] GetAuditLogsByDateRangeAsync() method
- [x] Register Cosmos DB service in Program.cs
- [x] Update ItemsController methods to log audits
  - [x] Log on Create
  - [x] Log on Read
  - [x] Log on Update
  - [x] Log on Delete

### Testing
- [ ] Create Cosmos DB account in Azure
- [ ] Create database: "RegistrationAppDb"
- [ ] Create container: "AuditLogs" with partition key "/partition"
- [ ] Update connection string
- [ ] Create an item and verify audit log appears
- [ ] Query audit logs: `GET /api/items/analytics/audit-logs/1`
- [ ] Verify timestamps and action types

---

## Phase 4: Serverless Functions ⏳ (TO DO)

### Code Implementation
- [ ] Create Azure Function project
- [ ] Create function: `SendEmailNotification`
  - [ ] Service Bus Queue trigger
  - [ ] Parse message data
  - [ ] Send confirmation email via SendGrid
  - [ ] Log to Cosmos DB
- [ ] Create function: `GenerateReport`
  - [ ] Timer trigger (daily)
  - [ ] Query audit logs
  - [ ] Generate PDF report
  - [ ] Upload to Storage
- [ ] Create function: `ItemImageProcessor`
  - [ ] Blob Storage trigger
  - [ ] Resize image
  - [ ] Create thumbnail
  - [ ] Store metadata in Cosmos DB

### Testing
- [ ] Create Function App in Azure
- [ ] Deploy functions
- [ ] Monitor execution in Azure Portal
- [ ] Verify emails sent when items created
- [ ] Check function logs

---

## Phase 5: Logic Apps Workflow ⏳ (TO DO)

### Workflow Design
- [ ] Create Logic App: "ItemApprovalWorkflow"
- [ ] Configure triggers:
  - [ ] Trigger: When item is created in SQL Database
  - [ ] Action 1: Send email to admin for approval
  - [ ] Action 2: Wait for response (approve/reject)
  - [ ] Action 3: If approved → send confirmation email
  - [ ] Action 4: If approved → save to Storage
  - [ ] Action 5: Log workflow status to Cosmos DB

### Testing
- [ ] Create Logic App in Azure
- [ ] Configure email connectors
- [ ] Manually trigger and verify workflow
- [ ] Test approval scenario
- [ ] Test rejection scenario
- [ ] Monitor logic app runs

---

## Integration & End-to-End Testing

### API Endpoints to Test
```bash
# Health check
GET /health

# Create item with all Azure services
POST /api/items
{
  "name": "Test Item",
  "description": "Testing all Azure services"
}
# Should:
# - Create item in SQL Database
# - Log to Cosmos DB (Created action)
# - Track in Application Insights
# - Publish message to Service Bus
# - Trigger Logic App workflow

# Upload image
POST /api/items/1/upload-image
# Should:
# - Upload file to Azure Storage
# - Store file URL in database
# - Log audit event
# - Track in Application Insights

# Get audit logs
GET /api/items/analytics/audit-logs/1
# Should:
# - Query Cosmos DB
# - Return all actions for item 1

# Update item
PUT /api/items/1
{
  "name": "Updated Item",
  "description": "Updated description"
}
# Should:
# - Update database
# - Log to Cosmos DB (Updated action)
# - Track event
# - Capture old and new values

# Delete item
DELETE /api/items/1
# Should:
# - Delete from database
# - Log to Cosmos DB (Deleted action)
# - Track event
# - Soft delete optional
```

---

## Deployment Steps

### Local Docker Testing
```bash
# 1. Install NuGet packages
dotnet restore

# 2. Update appsettings.json with test Azure connection strings
# 3. Build solution
dotnet build

# 4. Run with Docker Compose
docker-compose up -d

# 5. Access API
# - Swagger: http://localhost:5000/swagger
# - Health: http://localhost:5000/health
```

### Deploy to Azure
```bash
# 1. Create Key Vault and add all secrets
# 2. Create Storage Account and containers
# 3. Create Service Bus namespace and queues
# 4. Create Cosmos DB account and database
# 5. Create Application Insights resource
# 6. Create Function App
# 7. Create Logic App
# 8. Push Docker images to ACR
# 9. Deploy containers to ACI or App Service
```

---

## Monitoring & Alerts

### Application Insights Dashboard
- [ ] Create custom dashboard
- [ ] Add tiles for:
  - [ ] Request count
  - [ ] Error rate
  - [ ] Response time
  - [ ] Custom events (ItemCreated, ItemUpdated, etc.)
- [ ] Set up alerts:
  - [ ] Error rate > 5%
  - [ ] Response time > 2s
  - [ ] Application unavailable

### Cosmos DB Monitoring
- [ ] Monitor RU (Request Unit) usage
- [ ] Set up alerts for quota exceeded
- [ ] Review query performance

### Service Bus Monitoring
- [ ] Monitor queue depth
- [ ] Watch for dead-letter messages
- [ ] Set up alerts for processing delays

---

## Documentation

### Complete
- [x] AZURE_INTEGRATION_GUIDE.md - Full setup instructions
- [x] AZURE_NUGET_PACKAGES.md - Required packages
- [x] This checklist - Implementation tracking

### To Complete
- [ ] Add code comments explaining Azure services
- [ ] Create architecture diagram
- [ ] Add Postman collection for testing
- [ ] Create troubleshooting guide
- [ ] Add performance tuning guide

---

## Cost Tracking

### Estimated Monthly Cost
- Key Vault: $0.34
- Application Insights: $2-5
- Storage Account: $0.10-1
- Service Bus: $10
- Cosmos DB (400 RU/s): $23
- Function App: $0-15
- Logic Apps: $0-5
- **Total: $36-59/month**

### Budget Tracking
- [ ] Set up cost alerts in Azure
- [ ] Review actual vs estimated costs weekly
- [ ] Optimize expensive resources

---

## Learning Outcomes

By completing this checklist, you will have learned:

✅ **Azure Key Vault**
- How to secure sensitive configuration
- Retrieving secrets programmatically
- Access control and policies

✅ **Azure Application Insights**
- Monitoring and diagnostics
- Custom event tracking
- Performance metrics

✅ **Azure Storage**
- Blob storage concepts
- File upload/download
- SAS tokens for security

✅ **Azure Service Bus**
- Message queues and topics
- Asynchronous messaging
- Event-driven architecture

✅ **Azure Cosmos DB**
- NoSQL database design
- Document storage
- Partition keys and queries

✅ **Azure Functions**
- Serverless computing
- Event triggers
- Cost-efficient automation

✅ **Azure Logic Apps**
- No-code workflow automation
- Integration patterns
- Business process automation

---

## Next Steps After Completion

1. **Add Authentication**: Implement Azure AD
2. **Add HTTPS**: Use Azure Front Door or Application Gateway
3. **Add Caching**: Implement Redis Cache
4. **Add Monitoring**: Advanced Application Insights dashboards
5. **Add Analytics**: Power BI integration
6. **Scale**: Auto-scaling and load balancing
7. **Security**: Implement network security groups and firewalls

---

**Status**: 🚀 Ready to Begin Implementation
**Target Completion**: 2-3 weeks
**Difficulty**: Beginner to Intermediate
**Prerequisites**: Azure account, .NET 8.0, Docker

---

**Last Updated**: February 5, 2026
**Owner**: Learning Project
**Version**: 1.0
