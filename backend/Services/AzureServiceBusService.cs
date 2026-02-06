using Azure.Messaging.ServiceBus;
using System.Text.Json;

namespace RegistrationApi.Services
{
    /// <summary>
    /// Service for publishing messages to Azure Service Bus
    /// Used for asynchronous email notifications and event processing
    /// </summary>
    public interface IAzureServiceBusService
    {
        Task SendMessageAsync(string queueName, object messageData);
        Task PublishEventAsync(string topicName, object eventData);
        Task<int> GetQueueMessageCountAsync(string queueName);
    }

    public class AzureServiceBusService : IAzureServiceBusService
    {
        private readonly ServiceBusClient _serviceBusClient;
        private readonly ILogger<AzureServiceBusService> _logger;
        private readonly IConfiguration _configuration;
        private readonly bool _isConfigured;

        public AzureServiceBusService(IConfiguration configuration, ILogger<AzureServiceBusService> logger)
        {
            _logger = logger;
            _configuration = configuration;
            _isConfigured = false;

            string connectionString = _configuration.GetConnectionString("AzureServiceBus");
            
            // Check if connection string is valid (not a placeholder or empty)
            if (string.IsNullOrEmpty(connectionString) || connectionString.Contains("SERVICE_BUS_NAME") || connectionString.Contains("CONNECTION_KEY"))
            {
                _logger.LogWarning("Azure Service Bus connection string not properly configured. Using mock service.");
                _serviceBusClient = null;
                return;
            }

            try
            {
                _serviceBusClient = new ServiceBusClient(connectionString);
                _isConfigured = true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error initializing Azure Service Bus: {ex.Message}");
                _serviceBusClient = null;
            }
        }

        public async Task SendMessageAsync(string queueName, object messageData)
        {
            try
            {
                if (!_isConfigured)
                {
                    _logger.LogWarning("Azure Service Bus not configured. Skipping message send.");
                    return;
                }

                var sender = _serviceBusClient.CreateSender(queueName);
                var messageBody = JsonSerializer.Serialize(messageData);
                var message = new ServiceBusMessage(messageBody);

                // Add metadata
                message.ApplicationProperties.Add("Timestamp", DateTime.UtcNow);
                message.ApplicationProperties.Add("MessageType", messageData.GetType().Name);

                await sender.SendMessageAsync(message);
                _logger.LogInformation($"Message sent to queue '{queueName}': {messageBody}");
                await sender.DisposeAsync();
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error sending message to queue '{queueName}': {ex.Message}");
                throw;
            }
        }

        public async Task PublishEventAsync(string topicName, object eventData)
        {
            try
            {
                var sender = _serviceBusClient.CreateSender(topicName);
                var messageBody = JsonSerializer.Serialize(eventData);
                var message = new ServiceBusMessage(messageBody);

                // Add metadata
                message.ApplicationProperties.Add("Timestamp", DateTime.UtcNow);
                message.ApplicationProperties.Add("EventType", eventData.GetType().Name);

                await sender.SendMessageAsync(message);
                _logger.LogInformation($"Event published to topic '{topicName}': {messageBody}");
                await sender.DisposeAsync();
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error publishing event to topic '{topicName}': {ex.Message}");
                throw;
            }
        }

        public async Task<int> GetQueueMessageCountAsync(string queueName)
        {
            try
            {
                var receiver = _serviceBusClient.CreateReceiver(queueName);
                // Note: In production, use Azure Service Bus Management API for accurate count
                _logger.LogInformation($"Checking queue '{queueName}'");
                await receiver.DisposeAsync();
                return 0; // Placeholder
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error checking queue '{queueName}': {ex.Message}");
                throw;
            }
        }
    }
}
