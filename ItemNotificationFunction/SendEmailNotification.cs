using System;
using System.Text.Json;
using System.Threading.Tasks;
using Azure.Messaging.ServiceBus;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using SendGrid;
using SendGrid.Helpers.Mail;

namespace ItemNotificationFunction;

/// <summary>
/// Azure Function that processes Service Bus messages and sends email notifications
/// Triggered when items are created in the registration application
/// </summary>
public class SendEmailNotification
{
    private readonly ILogger<SendEmailNotification> _logger;

    public SendEmailNotification(ILogger<SendEmailNotification> logger)
    {
        _logger = logger;
    }

    [Function(nameof(SendEmailNotification))]
    public async Task Run(
        [ServiceBusTrigger("email-notifications-queue", Connection = "AzureWebJobsServiceBusConnectionString")]
        ServiceBusReceivedMessage message,
        ServiceBusMessageActions messageActions)
    {
        try
        {
            _logger.LogInformation("Processing Service Bus message: {messageId}", message.MessageId);
            
            // Parse the message body
            var messageBody = message.Body.ToString();
            _logger.LogInformation("Message Body: {body}", messageBody);

            // Try to deserialize - support both simple format and complex format
            NotificationData? notificationData = null;
            
            // First, try simple email notification format
            try
            {
                var simpleEmail = JsonSerializer.Deserialize<EmailNotification>(messageBody);
                if (simpleEmail != null && !string.IsNullOrEmpty(simpleEmail.Email))
                {
                    notificationData = new NotificationData
                    {
                        ItemName = simpleEmail.Subject ?? "Email Notification",
                        Description = simpleEmail.Body ?? "",
                        RecipientEmail = simpleEmail.Email,
                        RecipientName = "User",
                        CreatedBy = "System",
                        CreatedAt = DateTime.UtcNow
                    };
                    _logger.LogInformation("Successfully deserialized as simple email notification");
                }
            }
            catch (Exception ex)
            {
                _logger.LogInformation("Not a simple email notification format: {error}", ex.Message);
            }
            
            // If simple format didn't work, try complex format
            if (notificationData == null)
            {
                try
                {
                    notificationData = JsonSerializer.Deserialize<NotificationData>(messageBody);
                    if (notificationData != null)
                    {
                        _logger.LogInformation("Successfully deserialized as complex notification data");
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogWarning("Failed to deserialize notification data in any format: {error}", ex.Message);
                }
            }
            
            if (notificationData == null)
            {
                _logger.LogWarning("Failed to deserialize notification data - message will be abandoned");
                await messageActions.AbandonMessageAsync(message);
                return;
            }

            // Send email using SendGrid
            await SendEmailAsync(notificationData, _logger);

            // Complete the message after successful processing
            await messageActions.CompleteMessageAsync(message);
            _logger.LogInformation("Message processed successfully: {messageId}", message.MessageId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing message: {messageId}", message.MessageId);
            // Abandon the message to allow retry
            await messageActions.AbandonMessageAsync(message);
            throw;
        }
    }

    /// <summary>
    /// Sends or logs an email notification
    /// In development mode, logs to console instead of actually sending
    /// </summary>
    private async Task SendEmailAsync(NotificationData data, ILogger logger)
    {
        try
        {
            var sendGridApiKey = Environment.GetEnvironmentVariable("SendGridApiKey");
            
            // If no API key or placeholder key, just log the email
            if (string.IsNullOrEmpty(sendGridApiKey) || sendGridApiKey.StartsWith("SG.test") || sendGridApiKey.Contains("placeholder"))
            {
                logger.LogInformation("=== EMAIL NOTIFICATION (LOGGED MODE) ===");
                logger.LogInformation("To: {to}", data.RecipientEmail);
                logger.LogInformation("Recipient Name: {name}", data.RecipientName);
                logger.LogInformation("Subject: Item Notification - {itemName}", data.ItemName);
                logger.LogInformation("Body Preview: {description}", data.Description);
                logger.LogInformation("Item Details - Name: {itemName}, CreatedBy: {createdBy}, CreatedAt: {createdAt}", 
                    data.ItemName, data.CreatedBy, data.CreatedAt);
                logger.LogInformation("=== END EMAIL NOTIFICATION ===");
                logger.LogWarning("Email was logged instead of sent (no valid SendGrid API key configured)");
                return;
            }

            // If valid API key exists, send the actual email
            var client = new SendGridClient(sendGridApiKey);
            var from = new EmailAddress("noreply@registrationapp.com", "Registration App");
            var to = new EmailAddress(data.RecipientEmail, data.RecipientName);
            
            var subject = $"Item Created: {data.ItemName}";
            var htmlContent = $@"
                <h2>New Item Notification</h2>
                <p>Hello {data.RecipientName},</p>
                <p>A new item has been created in the registration system:</p>
                <ul>
                    <li><strong>Item Name:</strong> {data.ItemName}</li>
                    <li><strong>Description:</strong> {data.Description}</li>
                    <li><strong>Created By:</strong> {data.CreatedBy}</li>
                    <li><strong>Created At:</strong> {data.CreatedAt:yyyy-MM-dd HH:mm:ss}</li>
                </ul>
                <p>Please log in to review and take action if needed.</p>
                <p>Best regards,<br>Registration App Team</p>
            ";

            var msg = new SendGridMessage()
            {
                From = from,
                Subject = subject,
                HtmlContent = htmlContent
            };
            msg.AddTo(to);

            var response = await client.SendEmailAsync(msg);
            
            if (response.IsSuccessStatusCode)
            {
                logger.LogInformation("✅ Email sent successfully to {email}", data.RecipientEmail);
            }
            else
            {
                logger.LogError("❌ Failed to send email. Status Code: {statusCode}", response.StatusCode);
            }
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Error processing email notification");
            throw;
        }
    }
}

/// <summary>
/// Model for notification data from Service Bus messages
/// </summary>
public class NotificationData
{
    public string ItemName { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string RecipientEmail { get; set; } = string.Empty;
    public string RecipientName { get; set; } = string.Empty;
    public string CreatedBy { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
}

/// <summary>
/// Simple email notification model
/// </summary>
public class EmailNotification
{
    public string? Email { get; set; }
    public string? Subject { get; set; }
    public string? Body { get; set; }
    public string? Timestamp { get; set; }
}