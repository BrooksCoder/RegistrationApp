using Azure.Storage.Blobs;
using Azure.Storage.Blobs.Models;
using Microsoft.Extensions.Configuration;

namespace RegistrationApi.Services
{
    /// <summary>
    /// Service for uploading and managing files in Azure Blob Storage
    /// Used for storing item images and documents
    /// </summary>
    public interface IAzureStorageService
    {
        Task<string> UploadFileAsync(IFormFile file, string containerName = "uploads");
        Task<Stream> DownloadFileAsync(string blobName, string containerName = "uploads");
        Task<bool> DeleteFileAsync(string blobName, string containerName = "uploads");
        Task<List<string>> ListFilesAsync(string containerName = "uploads");
        Task<string> GetFileSasUriAsync(string blobName, string containerName = "uploads", int expiryMinutes = 60);
    }

    public class AzureStorageService : IAzureStorageService
    {
        private readonly BlobServiceClient _blobServiceClient;
        private readonly ILogger<AzureStorageService> _logger;
        private readonly bool _isConfigured;

        public AzureStorageService(IConfiguration configuration, ILogger<AzureStorageService> logger)
        {
            _logger = logger;
            _isConfigured = false;

            string connectionString = configuration.GetConnectionString("AzureStorageAccount");
            
            // Check if connection string is valid (not a placeholder or empty)
            if (string.IsNullOrEmpty(connectionString) || connectionString.Contains("ACCOUNT_NAME") || connectionString.Contains("ACCOUNT_KEY"))
            {
                _logger.LogWarning("Azure Storage connection string not properly configured. Using mock service.");
                _blobServiceClient = null;
                return;
            }

            try
            {
                _blobServiceClient = new BlobServiceClient(connectionString);
                _isConfigured = true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error initializing Azure Storage: {ex.Message}");
                _blobServiceClient = null;
            }
        }

        public async Task<string> UploadFileAsync(IFormFile file, string containerName = "uploads")
        {
            try
            {
                if (!_isConfigured)
                {
                    _logger.LogWarning("Azure Storage not configured. Skipping file upload.");
                    return $"mock_{Guid.NewGuid()}.bin";
                }

                // Validate file
                if (file == null || file.Length == 0)
                {
                    throw new ArgumentException("File is empty");
                }

                if (file.Length > 52428800) // 50 MB limit
                {
                    throw new ArgumentException("File size exceeds 50 MB limit");
                }

                // Create container if it doesn't exist
                var containerClient = _blobServiceClient.GetBlobContainerClient(containerName);
                await containerClient.CreateIfNotExistsAsync();

                // Generate unique filename
                string fileName = $"{Guid.NewGuid()}_{Path.GetFileName(file.FileName)}";

                // Upload file
                var blobClient = containerClient.GetBlobClient(fileName);
                using (var stream = file.OpenReadStream())
                {
                    await blobClient.UploadAsync(stream, overwrite: true);
                }

                _logger.LogInformation($"File uploaded successfully: {fileName}");
                return blobClient.Uri.ToString();
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error uploading file: {ex.Message}");
                throw;
            }
        }

        public async Task<Stream> DownloadFileAsync(string blobName, string containerName = "uploads")
        {
            try
            {
                if (!_isConfigured)
                {
                    _logger.LogWarning("Azure Storage not configured. Cannot download file.");
                    return null;
                }

                var containerClient = _blobServiceClient.GetBlobContainerClient(containerName);
                var blobClient = containerClient.GetBlobClient(blobName);

                // Check if blob exists
                if (!await blobClient.ExistsAsync())
                {
                    throw new FileNotFoundException($"Blob not found: {blobName}");
                }

                BlobDownloadInfo download = await blobClient.DownloadAsync();
                return download.Content;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error downloading file: {ex.Message}");
                throw;
            }
        }

        public async Task<bool> DeleteFileAsync(string blobName, string containerName = "uploads")
        {
            try
            {
                if (!_isConfigured)
                {
                    _logger.LogWarning("Azure Storage not configured. Cannot delete file.");
                    return true;
                }

                var containerClient = _blobServiceClient.GetBlobContainerClient(containerName);
                var blobClient = containerClient.GetBlobClient(blobName);

                var result = await blobClient.DeleteIfExistsAsync();
                _logger.LogInformation($"File deleted: {blobName} - Success: {result.Value}");
                return result.Value;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error deleting file: {ex.Message}");
                throw;
            }
        }

        public async Task<List<string>> ListFilesAsync(string containerName = "uploads")
        {
            try
            {
                if (!_isConfigured)
                {
                    _logger.LogWarning("Azure Storage not configured. Returning empty list.");
                    return new List<string>();
                }

                var containerClient = _blobServiceClient.GetBlobContainerClient(containerName);
                var blobs = new List<string>();

                await foreach (BlobItem blobItem in containerClient.GetBlobsAsync())
                {
                    blobs.Add(blobItem.Name);
                }

                return blobs;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error listing files: {ex.Message}");
                throw;
            }
        }

        public async Task<string> GetFileSasUriAsync(string blobName, string containerName = "uploads", int expiryMinutes = 60)
        {
            try
            {
                var containerClient = _blobServiceClient.GetBlobContainerClient(containerName);
                var blobClient = containerClient.GetBlobClient(blobName);

                // Check if blob exists
                if (!await blobClient.ExistsAsync())
                {
                    throw new FileNotFoundException($"Blob not found: {blobName}");
                }

                // Generate SAS URI
                var sasUri = blobClient.GenerateSasUri(
                    Azure.Storage.Sas.BlobSasPermissions.Read,
                    DateTimeOffset.UtcNow.AddMinutes(expiryMinutes)
                );

                return sasUri.ToString();
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error generating SAS URI: {ex.Message}");
                throw;
            }
        }
    }
}
