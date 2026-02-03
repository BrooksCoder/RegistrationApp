# Security Best Practices for Registration Application

## Overview
This document outlines security best practices for frontend-backend-database communication in Azure environments.

---

## 1. Backend-to-Database Security

### 1.1 Connection String Security

#### ❌ Bad Practice
```csharp
// Hardcoded in code
var connectionString = "Server=myserver;Database=mydb;User Id=sa;Password=SecretPassword123;";
```

#### ✅ Good Practice: Azure Key Vault
```csharp
// Program.cs
using Azure.Identity;
using Azure.Security.KeyVault.Secrets;

var keyVaultUrl = new Uri("https://your-keyvault.vault.azure.net/");
var credential = new DefaultAzureCredential();
var client = new SecretClient(keyVaultUrl, credential);

var connectionStringSecret = await client.GetSecretAsync("DbConnectionString");
string connectionString = connectionStringSecret.Value.Value;

builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlServer(connectionString)
);
```

#### Setup Key Vault Secret
```powershell
# Create Key Vault
az keyvault create --name "registration-kv" --resource-group "rg-registration"

# Add connection string
az keyvault secret set --vault-name "registration-kv" `
  --name "DbConnectionString" `
  --value "Server=tcp:myserver.database.windows.net,1433;Initial Catalog=mydb;Persist Security Info=False;User ID=sqladmin;Password=YourSecurePassword;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

# Grant Web App access to Key Vault
az webapp identity assign --name "registration-api" --resource-group "rg-registration"
az keyvault set-policy --name "registration-kv" `
  --object-id $(az webapp show -n "registration-api" -g "rg-registration" --query identity.principalId -o tsv) `
  --secret-permissions get
```

### 1.2 SQL Injection Prevention

#### ❌ Bad Practice
```csharp
var query = $"SELECT * FROM Items WHERE Name = '{itemName}'";
var results = await _context.Items.FromSqlRaw(query).ToListAsync();
```

#### ✅ Good Practice: Parameterized Queries
```csharp
// Using LINQ (preferred)
var results = await _context.Items
    .Where(x => x.Name == itemName)
    .ToListAsync();

// Using parameterized raw SQL
var results = await _context.Items
    .FromSqlInterpolated($"SELECT * FROM Items WHERE Name = {itemName}")
    .ToListAsync();

// Using stored procedure with parameters
var item = await _context.Items.FromSqlInterpolated(
    $"EXECUTE sp_GetItemByName {itemName}"
).FirstOrDefaultAsync();
```

### 1.3 Database Authentication

#### Using Managed Identity (No Credentials in Code)
```csharp
// Program.cs
var tokenProvider = new DefaultAzureCredential();

var connectionString = new SqlConnectionStringBuilder
{
    DataSource = "myserver.database.windows.net,1433",
    InitialCatalog = "RegistrationAppDb",
    Encrypt = true,
    TrustServerCertificate = false,
    Connection Timeout = 30
}.ConnectionString;

builder.Services.AddDbContext<ApplicationDbContext>((serviceProvider, options) =>
{
    var connection = new SqlConnection(connectionString);
    connection.AccessToken = tokenProvider
        .GetToken(new Azure.Core.TokenRequestContext(
            new[] { "https://database.windows.net/.default" }
        )).Token;
    
    options.UseSqlServer(connection);
});
```

### 1.4 Azure SQL Database Security

#### Enable Advanced Data Security
```powershell
# Enable Azure Defender for SQL
az sql server threat-protection-policy update `
  --resource-group "rg-registration" `
  --server "myserver" `
  --state On

# Enable auditing
az sql server audit-policy update `
  --resource-group "rg-registration" `
  --name "myserver" `
  --state On `
  --storage-account "mystorageaccount" `
  --storage-key "storage-key"

# Enable encryption at rest
az sql server transparent-data-encryption set `
  --resource-group "rg-registration" `
  --server "myserver" `
  --status Enabled
```

#### Row-Level Security (Optional)
```sql
-- Create security function
CREATE FUNCTION Security.fn_securitypredicate(@UserId NVARCHAR(100))
    RETURNS TABLE
    WITH SCHEMABINDING
AS
RETURN SELECT 1 AS fn_securitypredicate_result
WHERE SESSION_CONTEXT(N'UserId') = @UserId
   OR IS_ROLEMEMBER('Admin') = 1;
GO

-- Create security policy
CREATE SECURITY POLICY ItemFilter
    ADD FILTER PREDICATE Security.fn_securitypredicate(UserId) ON dbo.Items
    WITH (STATE = ON);
GO
```

### 1.5 Database Backup & Recovery
```powershell
# Configure automatic backups
az sql db update `
  --resource-group "rg-registration" `
  --server "myserver" `
  --name "RegistrationAppDb" `
  --backup-storage-redundancy Geo

# Create manual backup
az sql db copy `
  --resource-group "rg-registration" `
  --server "myserver" `
  --name "RegistrationAppDb" `
  --dest-server "myserver-backup" `
  --dest-name "RegistrationAppDb-backup"
```

---

## 2. Frontend-to-Backend Security

### 2.1 HTTPS/TLS Communication

#### ✅ Enforce HTTPS
```csharp
// Program.cs
builder.Services.AddHsts(options =>
{
    options.MaxAge = TimeSpan.FromDays(365);
    options.IncludeSubDomains = true;
    options.Preload = true;
});

app.UseHttpsRedirection();
app.UseHsts();
```

#### Configure in Azure App Service
```powershell
# Enable HTTPS only
az webapp update `
  --resource-group "rg-registration" `
  --name "registration-api" `
  --https-only true
```

### 2.2 CORS Configuration

#### ✅ Secure CORS Setup
```csharp
// Program.cs - DO NOT USE *
builder.Services.AddCors(options =>
{
    options.AddPolicy("SecureAngularApp", corsPolicyBuilder =>
    {
        corsPolicyBuilder
            .WithOrigins(
                "https://www.example.com",
                "https://app.example.com"  // Specific URLs only
            )
            .WithMethods("GET", "POST", "PUT", "DELETE")
            .WithHeaders("Content-Type", "Authorization")
            .AllowCredentials()
            .WithExposedHeaders("X-Total-Count") // If needed
            .SetPreflightMaxAge(3600);
    });
});

app.UseCors("SecureAngularApp");
```

#### Environment-Specific CORS
```csharp
var allowedOrigins = app.Environment.IsDevelopment()
    ? new[] { "http://localhost:4200" }
    : new[] { "https://www.example.com" };

builder.Services.AddCors(options =>
{
    options.AddPolicy("AppCors", corsPolicyBuilder =>
    {
        corsPolicyBuilder
            .WithOrigins(allowedOrigins)
            .AllowAnyMethod()
            .AllowAnyHeader();
    });
});
```

### 2.3 Authentication & Authorization

#### Implement JWT Bearer Authentication
```csharp
// Program.cs
builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://login.microsoftonline.com/{tenantId}/v2.0";
        options.Audience = "{apiIdentifier}";
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ClockSkew = TimeSpan.Zero
        };
    });

app.UseAuthentication();
app.UseAuthorization();
```

#### Protect Endpoints
```csharp
[ApiController]
[Route("api/[controller]")]
[Authorize]  // Require authentication
public class ItemsController : ControllerBase
{
    [HttpGet]
    [AllowAnonymous]  // Only if specifically allowed
    public async Task<IActionResult> GetItems() { ... }

    [HttpPost]
    [Authorize(Roles = "Admin")]  // Role-based authorization
    public async Task<IActionResult> CreateItem([FromBody] CreateItemRequest request) { ... }
}
```

### 2.4 Request Validation & Sanitization

#### Input Validation
```csharp
public class CreateItemRequest
{
    [Required(ErrorMessage = "Name is required")]
    [StringLength(200, MinimumLength = 3, 
        ErrorMessage = "Name must be between 3 and 200 characters")]
    public string Name { get; set; } = string.Empty;

    [Required(ErrorMessage = "Description is required")]
    [StringLength(1000, MinimumLength = 5,
        ErrorMessage = "Description must be between 5 and 1000 characters")]
    public string Description { get; set; } = string.Empty;
}

// In controller
[HttpPost]
[Authorize]
public async Task<IActionResult> CreateItem([FromBody] CreateItemRequest request)
{
    if (!ModelState.IsValid)
    {
        return BadRequest(ModelState);
    }
    
    // Sanitize inputs
    var sanitizedName = System.Web.HttpUtility.HtmlEncode(request.Name?.Trim());
    var sanitizedDescription = System.Web.HttpUtility.HtmlEncode(request.Description?.Trim());
    
    // ... rest of logic
}
```

#### Angular Request Interceptor for Headers
```typescript
// src/app/interceptors/auth.interceptor.ts
import { Injectable } from '@angular/core';
import { HttpInterceptor, HttpRequest, HttpHandler, HttpEvent } from '@angular/common/http';
import { Observable } from 'rxjs';

@Injectable()
export class AuthInterceptor implements HttpInterceptor {
  constructor(private authService: AuthService) {}

  intercept(req: HttpRequest<any>, next: HttpHandler): Observable<HttpEvent<any>> {
    const token = this.authService.getToken();
    
    if (token) {
      req = req.clone({
        setHeaders: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json'
        }
      });
    }

    return next.handle(req);
  }
}
```

### 2.5 API Rate Limiting

#### Implement Rate Limiting in Backend
```csharp
// Program.cs
builder.Services.AddMemoryCache();

// Add rate limiting middleware
var rateLimitOptions = new RateLimitOptions
{
    AutoReplenishment = true,
    PermitLimit = 100,
    QueueLimit = 0,
    QueueProcessingOrder = QueueProcessingOrder.OldestFirst,
    Window = TimeSpan.FromMinutes(1)
};

builder.Services.AddRateLimiter(options =>
{
    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: httpContext.User.Identity?.Name ?? httpContext.Connection.RemoteIpAddress?.ToString() ?? "anonymous",
            factory: partition => new FixedWindowRateLimiterOptions
            {
                AutoReplenishment = true,
                PermitLimit = 100,
                QueueLimit = 0,
                Window = TimeSpan.FromMinutes(1)
            }));
});

app.UseRateLimiter();
```

---

## 3. Frontend Security

### 3.1 Content Security Policy (CSP)

```html
<!-- index.html -->
<meta http-equiv="Content-Security-Policy" 
  content="
    default-src 'self';
    script-src 'self' 'unsafe-inline' 'unsafe-eval';
    style-src 'self' 'unsafe-inline';
    img-src 'self' data: https:;
    font-src 'self';
    connect-src 'self' https://your-api.azurewebsites.net;
    frame-ancestors 'none';
    base-uri 'self';
    form-action 'self';
  ">
```

### 3.2 Security Headers in Angular

Create HTTP interceptor:
```typescript
// src/app/interceptors/security.interceptor.ts
import { Injectable } from '@angular/core';
import { HttpInterceptor, HttpRequest, HttpHandler, HttpEvent } from '@angular/common/http';
import { Observable } from 'rxjs';

@Injectable()
export class SecurityInterceptor implements HttpInterceptor {
  intercept(req: HttpRequest<any>, next: HttpHandler): Observable<HttpEvent<any>> {
    return next.handle(req.clone({
      setHeaders: {
        'X-Content-Type-Options': 'nosniff',
        'X-Frame-Options': 'DENY',
        'X-XSS-Protection': '1; mode=block'
      }
    }));
  }
}
```

### 3.3 CSRF Protection

#### Backend CSRF Middleware
```csharp
builder.Services.AddAntiforgery(options =>
{
    options.HeaderName = "X-CSRF-TOKEN";
    options.SuppressXFrameOptionsHeader = false;
});

app.UseAntiforgery();
```

#### Angular CSRF Token
```typescript
// app.config.ts
import { provideHttpClient, withXsrfConfiguration } from '@angular/common/http';

export const appConfig: ApplicationConfig = {
  providers: [
    provideHttpClient(
      withXsrfConfiguration({
        cookieName: 'XSRF-TOKEN',
        headerName: 'X-XSRF-TOKEN'
      })
    )
  ]
};
```

### 3.4 Secure Local Storage

#### ❌ Bad Practice: Storing Sensitive Data in localStorage
```typescript
// DON'T DO THIS
localStorage.setItem('token', jwt);
```

#### ✅ Good Practice: Use HttpOnly Cookies
Configure backend to set HttpOnly cookies:
```csharp
// Program.cs
builder.Services.ConfigureApplicationCookie(options =>
{
    options.Cookie.HttpOnly = true;
    options.Cookie.SecurePolicy = CookieSecurePolicy.Always;
    options.Cookie.SameSite = SameSiteMode.Strict;
});
```

Or use sessionStorage (if necessary):
```typescript
// For development only - use HttpOnly cookies in production
sessionStorage.setItem('token', jwt);
```

### 3.5 Dependency Security

Regularly update Angular dependencies:
```powershell
# Check for vulnerabilities
npm audit

# Fix vulnerabilities
npm audit fix

# Update to latest versions
npm update
```

Add to pipeline:
```yaml
- task: Npm@1
  inputs:
    command: 'custom'
    customCommand: 'audit'
    workingDir: '$(Build.SourcesDirectory)/frontend'
  displayName: 'npm audit'
  continueOnError: true
```

---

## 4. Azure Infrastructure Security

### 4.1 Virtual Network & Network Security

```powershell
# Create VNET
az network vnet create `
  --name vnet-registration `
  --resource-group rg-registration `
  --subnet-name subnet-app

# Create Network Security Group
az network nsg create `
  --name nsg-registration `
  --resource-group rg-registration

# Add security rules
az network nsg rule create `
  --name AllowHTTPS `
  --nsg-name nsg-registration `
  --resource-group rg-registration `
  --priority 100 `
  --source-address-prefixes '*' `
  --source-port-ranges '*' `
  --destination-address-prefixes '*' `
  --destination-port-ranges 443 `
  --access Allow `
  --protocol Tcp

# Deny all inbound by default
az network nsg rule create `
  --name DenyAllInbound `
  --nsg-name nsg-registration `
  --resource-group rg-registration `
  --priority 4096 `
  --access Deny `
  --protocol '*' `
  --direction Inbound
```

### 4.2 Private Endpoints

```powershell
# Create private endpoint for SQL
az network private-endpoint create `
  --name pe-sql-registration `
  --resource-group rg-registration `
  --vnet-name vnet-registration `
  --subnet-name subnet-app `
  --private-connection-resource-id /subscriptions/{subscriptionId}/resourceGroups/rg-registration/providers/Microsoft.Sql/servers/myserver `
  --group-ids sqlServer `
  --connection-name sql-connection
```

### 4.3 Azure Policy & Compliance

```powershell
# Assign security policy
az policy assignment create `
  --name "enforce-https-only" `
  --resource-group rg-registration `
  --policy "subscriptions/{subscriptionId}/providers/Microsoft.Authorization/policyDefinitions/2c89a2e5-7285-40fe-aecd-26d3d1b0511e"
```

---

## 5. Logging & Monitoring

### 5.1 Application Insights Integration

```csharp
// Program.cs
builder.Services.AddApplicationInsightsTelemetry(options =>
{
    options.InstrumentationKey = builder.Configuration["ApplicationInsights:InstrumentationKey"];
});

builder.Logging.AddApplicationInsights();
```

### 5.2 Audit Logging

```csharp
public class AuditMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger _logger;

    public AuditMiddleware(RequestDelegate next, ILogger<AuditMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        var request = await FormatRequest(context.Request);
        
        _logger.LogInformation($"Request: {request}");
        _logger.LogInformation($"User: {context.User?.Identity?.Name}");
        _logger.LogInformation($"Timestamp: {DateTime.UtcNow:O}");

        await _next(context);
    }

    private async Task<string> FormatRequest(HttpRequest request)
    {
        request.Body.Position = 0;
        var body = await new StreamReader(request.Body).ReadToEndAsync();
        request.Body.Position = 0;
        
        return $"{request.Method} {request.Path} {body}";
    }
}

// Register middleware
app.UseMiddleware<AuditMiddleware>();
```

### 5.3 SQL Audit Logging

```powershell
# Enable SQL Server Auditing
az sql server audit-policy update `
  --resource-group rg-registration `
  --name myserver `
  --state On `
  --blob-storage-endpoint https://mystorageaccount.blob.core.windows.net `
  --storage-account-access-key $storageKey `
  --retention-days 90 `
  --audit-actions SUCCESSFUL_DATABASE_AUTHENTICATION_GROUP FAILED_DATABASE_AUTHENTICATION_GROUP
```

---

## 6. Compliance Checklist

- [ ] HTTPS/TLS enforced everywhere
- [ ] Connection strings in Key Vault, not in code
- [ ] SQL injection prevented with parameterized queries
- [ ] Authentication implemented (JWT/OAuth)
- [ ] Authorization checks on all protected endpoints
- [ ] CORS configured for specific domains
- [ ] Rate limiting implemented
- [ ] Input validation & sanitization
- [ ] CSRF protection enabled
- [ ] Security headers configured
- [ ] Logging & monitoring enabled
- [ ] Regular security patches applied
- [ ] Backup & disaster recovery configured
- [ ] Network security configured (NSG, firewall)
- [ ] Azure Defender for SQL enabled
- [ ] Audit logging enabled

---

## 7. References

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Azure Security Best Practices](https://docs.microsoft.com/azure/security/fundamentals/)
- [ASP.NET Core Security](https://docs.microsoft.com/aspnet/core/security/)
- [Angular Security](https://angular.io/guide/security)
- [SQL Server Security](https://docs.microsoft.com/sql/relational-databases/security/)

