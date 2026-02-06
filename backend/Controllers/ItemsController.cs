using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RegistrationApi.Data;
using RegistrationApi.Models;
using RegistrationApi.Services;

namespace RegistrationApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ItemsController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly ILogger<ItemsController> _logger;
        private readonly AzureStorageService _storageService;
        private readonly AzureServiceBusService _serviceBusService;
        private readonly AzureCosmosDbService _cosmosService;
        private readonly ApplicationInsightsService _appInsightsService;

        public ItemsController(
            ApplicationDbContext context, 
            ILogger<ItemsController> logger,
            AzureStorageService storageService = null,
            AzureServiceBusService serviceBusService = null,
            AzureCosmosDbService cosmosService = null,
            ApplicationInsightsService appInsightsService = null)
        {
            _context = context;
            _logger = logger;
            _storageService = storageService;
            _serviceBusService = serviceBusService;
            _cosmosService = cosmosService;
            _appInsightsService = appInsightsService;
        }

        // Health check endpoint
        [HttpGet("/health")]
        public IActionResult Health()
        {
            return Ok(new { status = "healthy" });
        }

        /// <summary>
        /// Get all items
        /// </summary>
        [HttpGet]
        public async Task<ActionResult<IEnumerable<Item>>> GetItems()
        {
            try
            {
                _logger.LogInformation("Fetching all items");
                var items = await _context.Items.OrderByDescending(x => x.CreatedAt).ToListAsync();
                
                // Track in Application Insights
                if (_appInsightsService != null)
                {
                    _appInsightsService.TrackEvent("GetItemsRequested", 
                        new Dictionary<string, string> { { "ItemCount", items.Count.ToString() } });
                }

                // Log audit to Cosmos DB
                if (_cosmosService != null)
                {
                    try
                    {
                        await _cosmosService.LogAuditAsync(new AuditLog
                        {
                            ItemId = "all",
                            Action = "Viewed",
                            ItemName = "All Items List",
                            Details = new Dictionary<string, object> { { "ItemCount", items.Count } }
                        });
                    }
                    catch (Exception cosmosEx)
                    {
                        _logger.LogWarning(cosmosEx, "Failed to log audit to Cosmos DB");
                    }
                }

                return Ok(items);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error fetching items");
                if (_appInsightsService != null)
                {
                    _appInsightsService.TrackException(ex);
                }
                return StatusCode(500, new { message = "An error occurred while fetching items" });
            }
        }

        /// <summary>
        /// Get an item by ID
        /// </summary>
        [HttpGet("{id}")]
        public async Task<ActionResult<Item>> GetItem(int id)
        {
            try
            {
                _logger.LogInformation($"Fetching item with ID: {id}");
                var item = await _context.Items.FindAsync(id);

                if (item == null)
                {
                    return NotFound(new { message = "Item not found" });
                }

                return Ok(item);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error fetching item with ID: {id}");
                return StatusCode(500, new { message = "An error occurred while fetching the item" });
            }
        }

        /// <summary>
        /// Create a new item
        /// </summary>
        [HttpPost]
        public async Task<ActionResult<Item>> CreateItem([FromBody] CreateItemRequest request)
        {
            try
            {
                if (!ModelState.IsValid)
                {
                    return BadRequest(ModelState);
                }

                _logger.LogInformation($"Creating new item: {request.Name}");

                var item = new Item
                {
                    Name = request.Name.Trim(),
                    Description = request.Description.Trim(),
                    CreatedAt = DateTime.UtcNow
                };

                _context.Items.Add(item);
                await _context.SaveChangesAsync();

                _logger.LogInformation($"Item created successfully with ID: {item.Id}");
                return CreatedAtAction(nameof(GetItem), new { id = item.Id }, item);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error creating item");
                return StatusCode(500, new { message = "An error occurred while creating the item" });
            }
        }

        /// <summary>
        /// Create a new item with image upload
        /// </summary>
        [HttpPost("with-image")]
        public async Task<ActionResult<Item>> CreateItemWithImage()
        {
            try
            {
                var name = Request.Form["name"].ToString();
                var description = Request.Form["description"].ToString();
                var imageFile = Request.Form.Files.FirstOrDefault();

                if (string.IsNullOrWhiteSpace(name) || string.IsNullOrWhiteSpace(description))
                {
                    return BadRequest(new { message = "Name and description are required" });
                }

                _logger.LogInformation($"Creating new item with image: {name}");

                var item = new Item
                {
                    Name = name.Trim(),
                    Description = description.Trim(),
                    CreatedAt = DateTime.UtcNow,
                    Status = "Pending"
                };

                // Handle image upload if provided
                if (imageFile != null && imageFile.Length > 0)
                {
                    try
                    {
                        if (_storageService != null)
                        {
                            var uploadUrl = await _storageService.UploadFileAsync(imageFile, "item-images");
                            item.ImageUrl = uploadUrl;
                            _logger.LogInformation($"Image uploaded successfully: {uploadUrl}");
                        }
                    }
                    catch (Exception storageEx)
                    {
                        _logger.LogWarning(storageEx, "Failed to upload image, continuing without image");
                    }
                }

                _context.Items.Add(item);
                await _context.SaveChangesAsync();

                // Send notification
                if (_serviceBusService != null)
                {
                    try
                    {
                        var notification = new
                        {
                            email = "admin@registrationapp.com",
                            subject = "New Item Created",
                            body = $"A new item '{item.Name}' has been created."
                        };
                        await _serviceBusService.SendMessageAsync("email-notifications-queue", 
                            System.Text.Json.JsonSerializer.Serialize(notification));
                    }
                    catch (Exception notificationEx)
                    {
                        _logger.LogWarning(notificationEx, "Failed to send notification");
                    }
                }

                _logger.LogInformation($"Item created successfully with ID: {item.Id}");
                return CreatedAtAction(nameof(GetItem), new { id = item.Id }, item);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error creating item with image");
                return StatusCode(500, new { message = "An error occurred while creating the item" });
            }
        }

        /// <summary>
        /// Update an existing item
        /// </summary>
        [HttpPut("{id}")]
        public async Task<IActionResult> UpdateItem(int id, [FromBody] UpdateItemRequest request)
        {
            try
            {
                if (!ModelState.IsValid)
                {
                    return BadRequest(ModelState);
                }

                _logger.LogInformation($"Updating item with ID: {id}");
                var item = await _context.Items.FindAsync(id);

                if (item == null)
                {
                    return NotFound(new { message = "Item not found" });
                }

                item.Name = request.Name.Trim();
                item.Description = request.Description.Trim();

                _context.Items.Update(item);
                await _context.SaveChangesAsync();

                _logger.LogInformation($"Item with ID: {id} updated successfully");
                return Ok(item);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error updating item with ID: {id}");
                return StatusCode(500, new { message = "An error occurred while updating the item" });
            }
        }

        /// <summary>
        /// Delete an item
        /// </summary>
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteItem(int id)
        {
            try
            {
                _logger.LogInformation($"Deleting item with ID: {id}");
                var item = await _context.Items.FindAsync(id);

                if (item == null)
                {
                    return NotFound(new { message = "Item not found" });
                }

                _context.Items.Remove(item);
                await _context.SaveChangesAsync();

                _logger.LogInformation($"Item with ID: {id} deleted successfully");
                return NoContent();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error deleting item with ID: {id}");
                return StatusCode(500, new { message = "An error occurred while deleting the item" });
            }
        }

        /// <summary>
        /// Get items pending approval
        /// </summary>
        [HttpGet("status/pending")]
        public async Task<ActionResult<IEnumerable<Item>>> GetPendingItems()
        {
            try
            {
                _logger.LogInformation("Fetching pending items");
                var pendingItems = await _context.Items
                    .Where(x => x.Status == "Pending")
                    .OrderByDescending(x => x.CreatedAt)
                    .ToListAsync();

                _appInsightsService?.TrackEvent("GetPendingItemsRequested", 
                    new Dictionary<string, string> { { "Count", pendingItems.Count.ToString() } });

                return Ok(pendingItems);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error fetching pending items");
                _appInsightsService?.TrackException(ex);
                return StatusCode(500, new { message = "An error occurred while fetching pending items" });
            }
        }

        /// <summary>
        /// Approve an item
        /// </summary>
        [HttpPost("{id}/approve")]
        public async Task<ActionResult<Item>> ApproveItem(int id)
        {
            try
            {
                _logger.LogInformation($"Approving item with ID: {id}");
                var item = await _context.Items.FindAsync(id);

                if (item == null)
                {
                    return NotFound(new { message = "Item not found" });
                }

                item.Status = "Approved";
                item.UpdatedAt = DateTime.UtcNow;

                _context.Items.Update(item);
                await _context.SaveChangesAsync();

                // Log to Cosmos DB
                if (_cosmosService != null)
                {
                    await _cosmosService.LogAuditAsync(new AuditLog
                    {
                        ItemId = item.Id.ToString(),
                        Action = "Approved",
                        ItemName = item.Name,
                        Details = new Dictionary<string, object> { { "PreviousStatus", "Pending" } }
                    });
                }

                _appInsightsService?.TrackEvent("ItemApproved", 
                    new Dictionary<string, string> { { "ItemId", id.ToString() } });

                _logger.LogInformation($"Item with ID: {id} approved successfully");
                return Ok(item);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error approving item with ID: {id}");
                _appInsightsService?.TrackException(ex);
                return StatusCode(500, new { message = "An error occurred while approving the item" });
            }
        }

        /// <summary>
        /// Reject an item
        /// </summary>
        [HttpPost("{id}/reject")]
        public async Task<ActionResult<Item>> RejectItem(int id)
        {
            try
            {
                _logger.LogInformation($"Rejecting item with ID: {id}");
                var item = await _context.Items.FindAsync(id);

                if (item == null)
                {
                    return NotFound(new { message = "Item not found" });
                }

                item.Status = "Rejected";
                item.UpdatedAt = DateTime.UtcNow;

                _context.Items.Update(item);
                await _context.SaveChangesAsync();

                // Log to Cosmos DB
                if (_cosmosService != null)
                {
                    await _cosmosService.LogAuditAsync(new AuditLog
                    {
                        ItemId = item.Id.ToString(),
                        Action = "Rejected",
                        ItemName = item.Name,
                        Details = new Dictionary<string, object> { { "PreviousStatus", "Pending" } }
                    });
                }

                _appInsightsService?.TrackEvent("ItemRejected", 
                    new Dictionary<string, string> { { "ItemId", id.ToString() } });

                _logger.LogInformation($"Item with ID: {id} rejected successfully");
                return Ok(item);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error rejecting item with ID: {id}");
                _appInsightsService?.TrackException(ex);
                return StatusCode(500, new { message = "An error occurred while rejecting the item" });
            }
        }
    }

    public class CreateItemRequest
    {
        public string Name { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
    }

    public class UpdateItemRequest
    {
        public string Name { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
    }
}
