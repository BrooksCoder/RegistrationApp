using Microsoft.Azure.Cosmos;
using Newtonsoft.Json;

namespace RegistrationApi.Services
{
    /// <summary>
    /// Model for audit logs stored in Azure Cosmos DB
    /// </summary>
    public class AuditLog
    {
        public AuditLog()
        {
            Id = Guid.NewGuid().ToString();
            Timestamp = DateTime.UtcNow;
            ChangedBy = "System";
            Details = new();
        }

        [JsonProperty("id")]
        public string Id { get; set; }

        [JsonProperty("itemId")]
        public string ItemId { get; set; }

        [JsonProperty("action")]
        public string Action { get; set; } // Created, Updated, Deleted, Viewed

        [JsonProperty("itemName")]
        public string ItemName { get; set; }

        [JsonProperty("itemDescription")]
        public string ItemDescription { get; set; }

        [JsonProperty("changedBy")]
        public string ChangedBy { get; set; }

        [JsonProperty("timestamp")]
        public DateTime Timestamp { get; set; }

        [JsonProperty("details")]
        public Dictionary<string, object> Details { get; set; }

        [JsonProperty("ipAddress")]
        public string IpAddress { get; set; }

        [JsonProperty("userAgent")]
        public string UserAgent { get; set; }

        [JsonProperty("partition")]
        public string Partition { get; set; } // For partitioning strategy
    }

    /// <summary>
    /// Service for logging audit trail in Azure Cosmos DB
    /// Tracks all CRUD operations with timestamps and details
    /// </summary>
    public interface IAzureCosmosDbService
    {
        Task<string> LogAuditAsync(AuditLog auditLog);
        Task<List<AuditLog>> GetAuditLogsAsync(string itemId, int? limit = null);
        Task<List<AuditLog>> GetAuditLogsByActionAsync(string action, int? limit = null);
        Task<List<AuditLog>> GetAuditLogsByDateRangeAsync(DateTime startDate, DateTime endDate);
    }

    public class AzureCosmosDbService : IAzureCosmosDbService
    {
        private readonly Container _container;
        private readonly ILogger<AzureCosmosDbService> _logger;
        private readonly bool _isConfigured;

        public AzureCosmosDbService(IConfiguration configuration, ILogger<AzureCosmosDbService> logger)
        {
            _logger = logger;
            _isConfigured = false;

            try
            {
                string connectionString = configuration.GetConnectionString("AzureCosmosDb");
                string databaseName = configuration["AzureCosmosDb:DatabaseName"] ?? "RegistrationAppDb";
                string containerName = configuration["AzureCosmosDb:ContainerName"] ?? "AuditLogs";

                if (string.IsNullOrEmpty(connectionString) || connectionString.Contains("ACCOUNT_NAME") || connectionString.Contains("ACCOUNT_KEY"))
                {
                    _logger.LogWarning("Azure Cosmos DB connection string not properly configured. Using mock service.");
                    return;
                }

                var cosmosClient = new CosmosClient(connectionString);
                var database = cosmosClient.GetDatabase(databaseName);
                _container = database.GetContainer(containerName);
                _isConfigured = true;

                _logger.LogInformation($"Cosmos DB initialized: {databaseName}/{containerName}");
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error initializing Cosmos DB: {ex.Message}");
            }
        }

        public async Task<string> LogAuditAsync(AuditLog auditLog)
        {
            try
            {
                if (!_isConfigured)
                {
                    _logger.LogWarning("Azure Cosmos DB not configured. Audit logging skipped.");
                    return auditLog.Id;
                }

                auditLog.Partition = auditLog.ItemId ?? "system";
                
                // Ensure the auditLog has a valid ID before inserting
                if (string.IsNullOrWhiteSpace(auditLog.Id))
                {
                    auditLog.Id = Guid.NewGuid().ToString();
                }
                
                var response = await _container.CreateItemAsync(auditLog, new PartitionKey(auditLog.Partition));
                
                _logger.LogInformation($"Audit log created: {auditLog.Id} - Action: {auditLog.Action}");
                return auditLog.Id;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error logging audit: {ex.Message}");
                // Return the ID even on error to prevent 500 responses
                return auditLog?.Id ?? "error";
            }
        }

        public async Task<List<AuditLog>> GetAuditLogsAsync(string itemId, int? limit = null)
        {
            try
            {
                string query = "SELECT * FROM c WHERE c.itemId = @itemId ORDER BY c.timestamp DESC";
                var queryDefinition = new QueryDefinition(query).WithParameter("@itemId", itemId);

                var iterator = _container.GetItemQueryIterator<AuditLog>(queryDefinition);
                var logs = new List<AuditLog>();

                while (iterator.HasMoreResults)
                {
                    var response = await iterator.ReadNextAsync();
                    logs.AddRange(response);

                    if (limit.HasValue && logs.Count >= limit.Value)
                    {
                        return logs.Take(limit.Value).ToList();
                    }
                }

                _logger.LogInformation($"Retrieved {logs.Count} audit logs for item {itemId}");
                return logs;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error retrieving audit logs: {ex.Message}");
                throw;
            }
        }

        public async Task<List<AuditLog>> GetAuditLogsByActionAsync(string action, int? limit = null)
        {
            try
            {
                string query = "SELECT * FROM c WHERE c.action = @action ORDER BY c.timestamp DESC";
                var queryDefinition = new QueryDefinition(query).WithParameter("@action", action);

                var iterator = _container.GetItemQueryIterator<AuditLog>(queryDefinition);
                var logs = new List<AuditLog>();

                while (iterator.HasMoreResults)
                {
                    var response = await iterator.ReadNextAsync();
                    logs.AddRange(response);

                    if (limit.HasValue && logs.Count >= limit.Value)
                    {
                        return logs.Take(limit.Value).ToList();
                    }
                }

                _logger.LogInformation($"Retrieved {logs.Count} audit logs for action {action}");
                return logs;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error retrieving audit logs by action: {ex.Message}");
                throw;
            }
        }

        public async Task<List<AuditLog>> GetAuditLogsByDateRangeAsync(DateTime startDate, DateTime endDate)
        {
            try
            {
                string query = "SELECT * FROM c WHERE c.timestamp >= @startDate AND c.timestamp <= @endDate ORDER BY c.timestamp DESC";
                var queryDefinition = new QueryDefinition(query)
                    .WithParameter("@startDate", startDate)
                    .WithParameter("@endDate", endDate);

                var iterator = _container.GetItemQueryIterator<AuditLog>(queryDefinition);
                var logs = new List<AuditLog>();

                while (iterator.HasMoreResults)
                {
                    var response = await iterator.ReadNextAsync();
                    logs.AddRange(response);
                }

                _logger.LogInformation($"Retrieved {logs.Count} audit logs between {startDate} and {endDate}");
                return logs;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error retrieving audit logs by date range: {ex.Message}");
                throw;
            }
        }
    }
}
