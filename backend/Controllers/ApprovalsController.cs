using Microsoft.AspNetCore.Mvc;
using RegistrationApi.Data;
using RegistrationApi.Services;
using Microsoft.EntityFrameworkCore;

namespace RegistrationApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ApprovalsController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly AzureCosmosDbService _cosmosService;
        private readonly ApplicationInsightsService _appInsightsService;
        private readonly ILogger<ApprovalsController> _logger;

        public ApprovalsController(
            ApplicationDbContext context,
            AzureCosmosDbService cosmosService,
            ApplicationInsightsService appInsightsService,
            ILogger<ApprovalsController> logger)
        {
            _context = context;
            _cosmosService = cosmosService;
            _appInsightsService = appInsightsService;
            _logger = logger;
        }

        /// <summary>
        /// Get all pending items requiring approval
        /// </summary>
        [HttpGet("pending")]
        public async Task<IActionResult> GetPendingApprovals()
        {
            try
            {
                _logger.LogInformation("Fetching pending approvals");
                var pending = await _context.Items
                    .Where(x => x.Status == "Pending")
                    .OrderByDescending(x => x.CreatedAt)
                    .ToListAsync();

                _appInsightsService?.TrackEvent("PendingApprovalsRequested",
                    new Dictionary<string, string> { { "Count", pending.Count.ToString() } });

                return Ok(pending);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error fetching pending approvals");
                _appInsightsService?.TrackException(ex);
                return StatusCode(500, new { message = "An error occurred while fetching pending approvals" });
            }
        }

        /// <summary>
        /// Get approval statistics
        /// </summary>
        [HttpGet("stats")]
        public async Task<IActionResult> GetApprovalStats()
        {
            try
            {
                _logger.LogInformation("Fetching approval statistics");

                var stats = new
                {
                    pending = await _context.Items.CountAsync(x => x.Status == "Pending"),
                    approved = await _context.Items.CountAsync(x => x.Status == "Approved"),
                    rejected = await _context.Items.CountAsync(x => x.Status == "Rejected")
                };

                return Ok(stats);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error fetching approval stats");
                return StatusCode(500, new { message = "An error occurred while fetching approval stats" });
            }
        }

        /// <summary>
        /// Approve an item
        /// </summary>
        [HttpPost("{id}/approve")]
        public async Task<IActionResult> ApproveItem(int id)
        {
            try
            {
                _logger.LogInformation($"Approving item {id}");
                var item = await _context.Items.FindAsync(id);

                if (item == null)
                {
                    return NotFound(new { message = "Item not found" });
                }

                if (item.Status != "Pending")
                {
                    return BadRequest(new { message = $"Item status is {item.Status}, cannot approve" });
                }

                item.Status = "Approved";
                item.UpdatedAt = DateTime.UtcNow;

                _context.Items.Update(item);
                await _context.SaveChangesAsync();

                // Log to Cosmos DB
                await _cosmosService.LogAuditAsync(new AuditLog
                {
                    ItemId = item.Id.ToString(),
                    Action = "Approved",
                    ItemName = item.Name,
                    Details = new Dictionary<string, object> { { "ChangedAt", DateTime.UtcNow } }
                });

                _appInsightsService?.TrackEvent("ItemApproved",
                    new Dictionary<string, string> { { "ItemId", id.ToString() } });

                return Ok(item);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error approving item {id}");
                _appInsightsService?.TrackException(ex);
                return StatusCode(500, new { message = "An error occurred while approving the item" });
            }
        }

        /// <summary>
        /// Reject an item
        /// </summary>
        [HttpPost("{id}/reject")]
        public async Task<IActionResult> RejectItem(int id)
        {
            try
            {
                _logger.LogInformation($"Rejecting item {id}");
                var item = await _context.Items.FindAsync(id);

                if (item == null)
                {
                    return NotFound(new { message = "Item not found" });
                }

                if (item.Status != "Pending")
                {
                    return BadRequest(new { message = $"Item status is {item.Status}, cannot reject" });
                }

                item.Status = "Rejected";
                item.UpdatedAt = DateTime.UtcNow;

                _context.Items.Update(item);
                await _context.SaveChangesAsync();

                // Log to Cosmos DB
                await _cosmosService.LogAuditAsync(new AuditLog
                {
                    ItemId = item.Id.ToString(),
                    Action = "Rejected",
                    ItemName = item.Name,
                    Details = new Dictionary<string, object> { { "ChangedAt", DateTime.UtcNow } }
                });

                _appInsightsService?.TrackEvent("ItemRejected",
                    new Dictionary<string, string> { { "ItemId", id.ToString() } });

                return Ok(item);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error rejecting item {id}");
                _appInsightsService?.TrackException(ex);
                return StatusCode(500, new { message = "An error occurred while rejecting the item" });
            }
        }
    }
}
