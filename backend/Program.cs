using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Cors.Infrastructure;
using Microsoft.EntityFrameworkCore;
using RegistrationApi.Data;

var builder = WebApplication.CreateBuilder(args);

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

// Add Entity Framework Core
builder.Services.AddDbContext<RegistrationApi.Data.ApplicationDbContext>(options =>
{
    var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
    options.UseSqlServer(connectionString);
});

builder.Services.AddLogging();
builder.Services.AddEndpointsApiExplorer();

// Configure Kestrel to listen on all interfaces
builder.WebHost.ConfigureKestrel(serverOptions =>
{
    serverOptions.ListenAnyIP(80);
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
