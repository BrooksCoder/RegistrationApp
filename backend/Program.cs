using Azure.Identity;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Cors.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.ApplicationInsights;
using RegistrationApi.Data;
using RegistrationApi.Services;

var builder = WebApplication.CreateBuilder(args);

// ==================== AZURE KEY VAULT CONFIGURATION ====================
// Load configuration from Key Vault in production (if properly configured)
if (!builder.Environment.IsDevelopment())
{
    var clientId = Environment.GetEnvironmentVariable("AZURE_CLIENT_ID");
    var clientSecret = Environment.GetEnvironmentVariable("AZURE_CLIENT_SECRET");
    var tenantId = Environment.GetEnvironmentVariable("AZURE_TENANT_ID");
    var keyVaultUrl = builder.Configuration["AzureKeyVault:VaultUri"];

    if (!string.IsNullOrEmpty(clientId) && !string.IsNullOrEmpty(clientSecret))
    {
        try
        {
            // Use Service Principal credentials instead of DefaultAzureCredential
            var credential = new ClientSecretCredential(tenantId, clientId, clientSecret);
            builder.Configuration.AddAzureKeyVault(
                new Uri(keyVaultUrl),
                credential);
            Console.WriteLine("✓ Key Vault configured with Service Principal");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"✗ Failed to connect to Key Vault: {ex.Message}");
            throw;
        }
    }
    else
    {
        throw new InvalidOperationException(
            "Service Principal credentials not found. " +
            "Set AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, and AZURE_TENANT_ID environment variables.");
    }
}

// ==================== AZURE APPLICATION INSIGHTS ====================
// Add Application Insights for monitoring (if properly configured)
var appInsightsConfig = builder.Configuration["ApplicationInsights:InstrumentationKey"];
if (!string.IsNullOrEmpty(appInsightsConfig) && !appInsightsConfig.StartsWith("<"))
{
    builder.Services.AddApplicationInsightsTelemetry();
    Console.WriteLine("✓ Application Insights configured");
}
else
{
    Console.WriteLine("⚠ Application Insights not configured (placeholder or empty), skipping");
}

// ==================== SERVICES ====================
// Add services to the container
builder.Services.AddControllers();
builder.Services.AddSwaggerGen();
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAngularApp", corsPolicyBuilder =>
    {
        corsPolicyBuilder
            .AllowAnyOrigin()
            .AllowAnyMethod()
            .AllowAnyHeader();
    });
});

// Register Key Vault Service
builder.Services.AddSingleton<KeyVaultService>();

// Register Azure Services
if (!string.IsNullOrEmpty(appInsightsConfig) && !appInsightsConfig.StartsWith("<"))
{
    builder.Services.AddApplicationInsightsTelemetry();
    builder.Services.AddSingleton<IApplicationInsightsService, ApplicationInsightsService>();
    Console.WriteLine("✓ ApplicationInsightsService registered");
}
else
{
    // Register a no-op implementation when App Insights is not configured
    builder.Services.AddSingleton<IApplicationInsightsService, NoOpApplicationInsightsService>();
    Console.WriteLine("⚠ NoOpApplicationInsightsService registered (App Insights not configured)");
}
builder.Services.AddScoped<AzureStorageService>();
builder.Services.AddScoped<AzureServiceBusService>();
builder.Services.AddScoped<AzureCosmosDbService>();

// Add Entity Framework Core
builder.Services.AddDbContext<RegistrationApi.Data.ApplicationDbContext>(options =>
{
    // Priority: Environment variable > appsettings.json
    var connectionString = Environment.GetEnvironmentVariable("ConnectionStrings__DefaultConnection") 
        ?? builder.Configuration.GetConnectionString("DefaultConnection");
    
    if (string.IsNullOrEmpty(connectionString))
    {
        throw new InvalidOperationException("Connection string 'DefaultConnection' not found in environment variables or configuration.");
    }
    
    Console.WriteLine("Using connection string from: " + (Environment.GetEnvironmentVariable("ConnectionStrings__DefaultConnection") != null ? "Environment Variable" : "appsettings.json"));
    options.UseSqlServer(connectionString);
});

builder.Services.AddLogging();
builder.Services.AddEndpointsApiExplorer();

// Configure Kestrel to listen on all interfaces
// In container environments, listen on 0.0.0.0:80
// In development, use default ports
builder.WebHost.ConfigureKestrel(serverOptions =>
{
    if (builder.Environment.IsProduction())
    {
        // Production: Listen on all interfaces on port 80
        serverOptions.ListenAnyIP(80);
    }
    else
    {
        // Development: Listen on localhost ports
        serverOptions.ListenLocalhost(58082, listenOptions =>
        {
            listenOptions.UseHttps();
        });
        serverOptions.ListenLocalhost(58083);
    }
});

var app = builder.Build();

// Configure the HTTP request pipeline
// Enable Swagger in all environments for now
app.UseSwagger();
app.UseSwaggerUI();

// Only redirect to HTTPS in production with proper certificate support
// For now, skip HTTPS redirect since we're using HTTP in containers
// app.UseHttpsRedirection();

app.UseCors("AllowAngularApp");
app.UseAuthorization();
app.MapControllers();

// Apply migrations automatically (optional - for development) with retry logic
var retryCount = 0;
const int maxRetries = 10;
const int delayMs = 3000;

while (retryCount < maxRetries)
{
    try
    {
        using (var scope = app.Services.CreateScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<RegistrationApi.Data.ApplicationDbContext>();
            dbContext.Database.Migrate();
            Console.WriteLine("✓ Database migrations applied successfully");
            break;
        }
    }
    catch (Exception ex)
    {
        retryCount++;
        Console.WriteLine($"Database connection attempt {retryCount}/{maxRetries} failed: {ex.Message}");
        if (retryCount < maxRetries)
        {
            Console.WriteLine($"Retrying in {delayMs}ms...");
            await Task.Delay(delayMs);
        }
        else
        {
            Console.WriteLine("✗ Failed to connect to database after maximum retries. Starting app anyway.");
            break;
        }
    }
}

app.Run();
