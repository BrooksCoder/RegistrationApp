using Microsoft.AspNetCore.Mvc;
using RegistrationApi.Services;

namespace RegistrationApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class NotificationsController : ControllerBase
    {
        private readonly AzureServiceBusService _serviceBusService;
        private readonly ILogger<NotificationsController> _logger;

        public NotificationsController(
            AzureServiceBusService serviceBusService,
            ILogger<NotificationsController> logger)
        {
            _serviceBusService = serviceBusService;
            _logger = logger;
        }

        /// <summary>
        /// Get notification statistics
        /// </summary>
        [HttpGet("stats")]
        public IActionResult GetNotificationStats()
        {
            try
            {
                _logger.LogInformation("Fetching notification statistics");

                // Return mock statistics for now
                return Ok(new
                {
                    queued = 3,
                    sent = 12,
                    failed = 1
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error fetching notification stats");
                return StatusCode(500, new { message = "An error occurred while fetching notification statistics" });
            }
        }

        /// <summary>
        /// Get all notifications
        /// </summary>
        [HttpGet]
        public IActionResult GetNotifications()
        {
            try
            {
                _logger.LogInformation("Fetching notifications");

                // Return mock notifications for now
                var notifications = new[]
                {
                    new
                    {
                        id = "1",
                        subject = "Item Registration Confirmation",
                        recipientEmail = "user@example.com",
                        status = "Sent",
                        timestamp = DateTime.UtcNow.AddHours(-1)
                    },
                    new
                    {
                        id = "2",
                        subject = "Item Approved",
                        recipientEmail = "user@example.com",
                        status = "Pending",
                        timestamp = DateTime.UtcNow.AddMinutes(-30)
                    }
                };

                return Ok(notifications);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error fetching notifications");
                return StatusCode(500, new { message = "An error occurred while fetching notifications" });
            }
        }

        /// <summary>
        /// Send notification for an item
        /// </summary>
        [HttpPost("send")]
        public async Task<IActionResult> SendNotification([FromBody] SendNotificationRequest request)
        {
            try
            {
                _logger.LogInformation($"Sending notification to {request.Email}");

                var message = new
                {
                    email = request.Email,
                    subject = request.Subject,
                    body = request.Body,
                    timestamp = DateTime.UtcNow
                };

                // Publish to Service Bus
                await _serviceBusService.SendMessageAsync("email-notifications-queue", System.Text.Json.JsonSerializer.Serialize(message));

                return Ok(new { message = "Notification queued successfully" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error sending notification");
                return StatusCode(500, new { message = "An error occurred while sending the notification" });
            }
        }
    }

    public class SendNotificationRequest
    {
        public string Email { get; set; } = string.Empty;
        public string Subject { get; set; } = string.Empty;
        public string Body { get; set; } = string.Empty;
    }
}
