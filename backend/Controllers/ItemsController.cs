using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RegistrationApi.Data;
using RegistrationApi.Models;

namespace RegistrationApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ItemsController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly ILogger<ItemsController> _logger;

        public ItemsController(ApplicationDbContext context, ILogger<ItemsController> logger)
        {
            _context = context;
            _logger = logger;
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
                return Ok(items);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error fetching items");
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
