using Microsoft.ApplicationInsights;
using Microsoft.ApplicationInsights.DataContracts;

namespace RegistrationApi.Services
{
    /// <summary>
    /// Service for tracking events and metrics in Azure Application Insights
    /// Used for monitoring application performance and usage
    /// </summary>
    public interface IApplicationInsightsService
    {
        void TrackEvent(string eventName, Dictionary<string, string>? properties = null, Dictionary<string, double>? metrics = null);
        void TrackException(Exception ex, Dictionary<string, string>? properties = null);
        void TrackTrace(string message, SeverityLevel severityLevel = SeverityLevel.Information);
        void TrackMetric(string metricName, double value);
    }

    public class ApplicationInsightsService : IApplicationInsightsService
    {
        private readonly TelemetryClient _telemetryClient;
        private readonly ILogger<ApplicationInsightsService> _logger;

        public ApplicationInsightsService(TelemetryClient telemetryClient, ILogger<ApplicationInsightsService> logger)
        {
            _telemetryClient = telemetryClient;
            _logger = logger;
        }

        public void TrackEvent(string eventName, Dictionary<string, string>? properties = null, Dictionary<string, double>? metrics = null)
        {
            try
            {
                var telemetry = new EventTelemetry(eventName);
                
                if (properties != null)
                {
                    foreach (var prop in properties)
                    {
                        telemetry.Properties.Add(prop.Key, prop.Value);
                    }
                }
                
                _telemetryClient.TrackEvent(telemetry);
                
                if (metrics != null)
                {
                    foreach (var metric in metrics)
                    {
                        _telemetryClient.TrackEvent($"{eventName}_Metric_{metric.Key}", new Dictionary<string, string> 
                        { 
                            { "value", metric.Value.ToString() } 
                        });
                    }
                }
                
                _logger.LogInformation($"Event tracked: {eventName}");
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error tracking event {eventName}: {ex.Message}");
            }
        }

        public void TrackException(Exception ex, Dictionary<string, string>? properties = null)
        {
            try
            {
                _telemetryClient.TrackException(ex, properties);
                _logger.LogError($"Exception tracked: {ex.Message}");
            }
            catch (Exception trackingEx)
            {
                _logger.LogError($"Error tracking exception: {trackingEx.Message}");
            }
        }

        public void TrackTrace(string message, SeverityLevel severityLevel = SeverityLevel.Information)
        {
            try
            {
                _telemetryClient.TrackTrace(message, severityLevel);
                _logger.LogInformation($"Trace tracked: {message}");
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error tracking trace: {ex.Message}");
            }
        }

        public void TrackMetric(string metricName, double value)
        {
            try
            {
                _telemetryClient.GetMetric(metricName).TrackValue(value);
                _logger.LogInformation($"Metric tracked: {metricName} = {value}");
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error tracking metric {metricName}: {ex.Message}");
            }
        }
    }
}
