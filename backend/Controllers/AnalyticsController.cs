using Microsoft.AspNetCore.Mvc;
using RegistrationApi.Services;
using RegistrationApi.Data;
using Microsoft.EntityFrameworkCore;

namespace RegistrationApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AnalyticsController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly AzureStorageService _storageService;
        private readonly ApplicationInsightsService _appInsightsService;
        private readonly AzureCosmosDbService _cosmosService;
        private readonly AzureServiceBusService _serviceBusService;
        private readonly ILogger<AnalyticsController> _logger;

        public AnalyticsController(
            ApplicationDbContext context,
            AzureStorageService storageService,
            ApplicationInsightsService appInsightsService,
            AzureCosmosDbService cosmosService,
            AzureServiceBusService serviceBusService,
            ILogger<AnalyticsController> logger)
        {
            _context = context;
            _storageService = storageService;
            _appInsightsService = appInsightsService;
            _cosmosService = cosmosService;
            _serviceBusService = serviceBusService;
            _logger = logger;
        }

        /// <summary>
        /// Get analytics metrics
        /// </summary>
        [HttpGet]
        public async Task<IActionResult> GetAnalytics()
        {
            try
            {
                _logger.LogInformation("Fetching analytics metrics");

                // Total items
                var totalItems = await _context.Items.CountAsync();
                var approvedItems = await _context.Items.CountAsync(x => x.Status == "Approved");
                var rejectedItems = await _context.Items.CountAsync(x => x.Status == "Rejected");
                var pendingItems = await _context.Items.CountAsync(x => x.Status == "Pending");

                // Calculate metrics
                var analytics = new
                {
                    totalItems = totalItems,
                    approvedItems = approvedItems,
                    rejectedItems = rejectedItems,
                    pendingItems = pendingItems,
                    storageUsed = 1024000, // bytes - placeholder
                    queueDepth = 3,
                    auditCount = 45,
                    apiResponseTime = 25, // milliseconds
                    successRate = totalItems > 0 ? 
                        Math.Round((double)(totalItems - rejectedItems) / totalItems * 100, 2) : 0
                };

                _appInsightsService?.TrackEvent("AnalyticsRequested", 
                    new Dictionary<string, string> 
                    { 
                        { "TotalItems", analytics.totalItems.ToString() },
                        { "ApprovedItems", analytics.approvedItems.ToString() }
                    });

                return Ok(analytics);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error fetching analytics");
                _appInsightsService?.TrackException(ex);
                return StatusCode(500, new { message = "An error occurred while fetching analytics" });
            }
        }

        /// <summary>
        /// Get dashboard overview
        /// </summary>
        [HttpGet("overview")]
        public async Task<IActionResult> GetDashboardOverview()
        {
            try
            {
                _logger.LogInformation("Fetching dashboard overview");

                var overview = new
                {
                    totalItems = await _context.Items.CountAsync(),
                    pendingApprovals = await _context.Items.CountAsync(x => x.Status == "Pending"),
                    approvedThisMonth = await _context.Items
                        .CountAsync(x => x.Status == "Approved" && x.UpdatedAt.HasValue && 
                            x.UpdatedAt.Value.Month == DateTime.UtcNow.Month),
                    successRate = 85.5
                };

                return Ok(overview);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error fetching dashboard overview");
                return StatusCode(500, new { message = "An error occurred while fetching dashboard overview" });
            }
        }
    }
}
