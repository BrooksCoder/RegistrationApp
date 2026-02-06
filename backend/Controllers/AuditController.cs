using Microsoft.AspNetCore.Mvc;
using RegistrationApi.Services;

namespace RegistrationApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AuditController : ControllerBase
    {
        private readonly AzureCosmosDbService _cosmosService;
        private readonly ILogger<AuditController> _logger;

        public AuditController(
            AzureCosmosDbService cosmosService,
            ILogger<AuditController> logger)
        {
            _cosmosService = cosmosService;
            _logger = logger;
        }

        /// <summary>
        /// Get all audit logs
        /// </summary>
        [HttpGet]
        public async Task<IActionResult> GetAllAuditLogs()
        {
            try
            {
                _logger.LogInformation("Fetching all audit logs from Cosmos DB");
                // Return empty list for now - would be extended to fetch from Cosmos DB
                return Ok(new object[] { });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error fetching audit logs");
                return StatusCode(500, new { message = "An error occurred while fetching audit logs" });
            }
        }

        /// <summary>
        /// Get audit logs for a specific item
        /// </summary>
        [HttpGet("{itemId}")]
        public async Task<IActionResult> GetItemAuditLogs(string itemId)
        {
            try
            {
                _logger.LogInformation($"Fetching audit logs for item: {itemId}");
                // Return empty list for now - would be extended to fetch from Cosmos DB
                return Ok(new object[] { });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error fetching audit logs for item {itemId}");
                return StatusCode(500, new { message = "An error occurred while fetching audit logs" });
            }
        }

        /// <summary>
        /// Log an action
        /// </summary>
        [HttpPost]
        public async Task<IActionResult> LogAction([FromBody] LogActionRequest request)
        {
            try
            {
                _logger.LogInformation($"Logging action: {request.Action} for item: {request.ItemId}");

                var auditLog = new AuditLog
                {
                    ItemId = request.ItemId.ToString(),
                    Action = request.Action,
                    ItemName = request.ItemName,
                    Details = request.Details ?? new Dictionary<string, object>()
                };

                await _cosmosService.LogAuditAsync(auditLog);
                return Ok(auditLog);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error logging action");
                return StatusCode(500, new { message = "An error occurred while logging the action" });
            }
        }
    }

    public class LogActionRequest
    {
        public int ItemId { get; set; }
        public string Action { get; set; } = string.Empty;
        public string ItemName { get; set; } = string.Empty;
        public Dictionary<string, object>? Details { get; set; }
    }
}
