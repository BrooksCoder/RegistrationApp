using Azure.Identity;
using Azure.Security.KeyVault.Secrets;
using Microsoft.Extensions.Configuration;

namespace RegistrationApi.Services
{
    /// <summary>
    /// Service to manage Azure Key Vault operations
    /// Retrieves secrets securely from Azure Key Vault
    /// </summary>
    public interface IKeyVaultService
    {
        Task<string> GetSecretAsync(string secretName);
    }

    public class KeyVaultService : IKeyVaultService
    {
        private readonly SecretClient _secretClient;
        private readonly IConfiguration _configuration;
        private readonly ILogger<KeyVaultService> _logger;

        public KeyVaultService(IConfiguration configuration, ILogger<KeyVaultService> logger)
        {
            _configuration = configuration;
            _logger = logger;

            var keyVaultUrl = _configuration["AzureKeyVault:VaultUri"];
            
            // Use Managed Identity in Azure, or DefaultAzureCredential locally
            var credential = new DefaultAzureCredential();
            _secretClient = new SecretClient(new Uri(keyVaultUrl), credential);
        }

        public async Task<string> GetSecretAsync(string secretName)
        {
            try
            {
                _logger.LogInformation($"Retrieving secret: {secretName} from Key Vault");
                KeyVaultSecret secret = await _secretClient.GetSecretAsync(secretName);
                return secret.Value;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error retrieving secret {secretName}: {ex.Message}");
                // Fallback to appsettings value in case of failure
                return _configuration[$"Secrets:{secretName}"] ?? string.Empty;
            }
        }
    }
}
