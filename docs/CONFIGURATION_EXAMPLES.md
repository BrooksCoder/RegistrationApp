# Environment Configuration Examples

## Backend Configuration

### appsettings.json (Local Development)
```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft": "Warning",
      "Microsoft.EntityFrameworkCore": "Information"
    }
  },
  "AllowedHosts": "*",
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=RegistrationAppDb;Trusted_Connection=true;Encrypt=false;"
  }
}
```

### appsettings.json (SQL Authentication)
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=RegistrationAppDb;User Id=sa;Password=YourPassword;Encrypt=false;"
  }
}
```

### appsettings.json (Azure Production)
```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft": "Warning"
    }
  },
  "AllowedHosts": "*.azurewebsites.net",
  "ApplicationInsights": {
    "InstrumentationKey": "your-instrumentation-key"
  }
}
```

## Frontend Configuration

### environment.ts (Development)
```typescript
export const environment = {
  production: false,
  apiUrl: 'http://localhost:5000/api'
};
```

### environment.prod.ts (Production)
```typescript
export const environment = {
  production: true,
  apiUrl: 'https://registration-api-xxxxx.azurewebsites.net/api'
};
```

## Docker Environment Variables

### .env file for Docker Compose
```
SQL_PASSWORD=YourSecurePassword123!@#
ASPNETCORE_ENVIRONMENT=Development
ASPNETCORE_URLS=http://+:80
DOTNET_CLI_TELEMETRY_OPTOUT=true
```

## Azure Configuration

### Resource Names
```
Resource Group: rg-registration-app
SQL Server: registration-sql-xxxxx
SQL Database: RegistrationAppDb
App Service Plan: asp-registration-app
Backend App: registration-api-xxxxx
Key Vault: registration-kv-xxxxx
Storage Account: registrationxxxxx
```

### Connection String Template
```
Server=tcp:registration-sql-xxxxx.database.windows.net,1433;
Initial Catalog=RegistrationAppDb;
Persist Security Info=False;
User ID=sqladmin;
Password=YourPassword;
MultipleActiveResultSets=False;
Encrypt=True;
TrustServerCertificate=False;
Connection Timeout=30;
```

### Key Vault Secrets
- `DbConnectionString` - Database connection string
- `ApiKey` - (if using API key authentication)
- `JwtSecret` - (if using JWT)
- `AppSettings` - (JSON formatted app settings)

## Azure DevOps Variables

### Pipeline Variables
```
buildConfiguration: Release
nodeVersion: 18.x
dotnetVersion: 8.x
```

### Variable Groups (Secure Variables)
- `backendAppNameStaging` - Backend staging app name
- `backendAppNameProd` - Backend production app name
- `sqlConnectionString` - Secure connection string
- `azureServiceConnection` - Service connection name
- `deploymentToken` - Static web app deployment token

## CORS Configuration

### Development
```csharp
.WithOrigins("http://localhost:4200")
```

### Production
```csharp
.WithOrigins(
    "https://www.example.com",
    "https://app.example.com"
)
```

## Database Configuration

### SQL Server Connection (Windows Authentication)
```
Server=localhost;
Database=RegistrationAppDb;
Trusted_Connection=true;
```

### SQL Server Connection (SQL Authentication)
```
Server=localhost;
Database=RegistrationAppDb;
User Id=sa;
Password=YourPassword;
```

### SQL Server Connection (Azure)
```
Server=tcp:server-name.database.windows.net,1433;
Initial Catalog=DatabaseName;
User ID=username;
Password=password;
Encrypt=true;
TrustServerCertificate=false;
```

## Angular Build Configuration

### Development Build
```
ng build --configuration development
```

### Production Build
```
ng build --configuration production
```

### Build Options
```json
{
  "configurations": {
    "production": {
      "budgets": [
        {
          "type": "initial",
          "maximumWarning": "500kb",
          "maximumError": "1mb"
        }
      ],
      "outputHashing": "all"
    }
  }
}
```

## .NET Core Configuration

### Logging Levels
```
Critical - 5
Error - 4
Warning - 3
Information - 2
Debug - 1
Trace - 0
```

### CORS Configuration
```csharp
builder.Services.AddCors(options =>
{
    options.AddPolicy("AngularApp", corsPolicyBuilder =>
    {
        corsPolicyBuilder
            .WithOrigins(allowedOrigins)
            .WithMethods("GET", "POST", "PUT", "DELETE")
            .WithHeaders("Content-Type", "Authorization")
            .AllowCredentials();
    });
});
```

### Entity Framework Configuration
```csharp
builder.Services.AddDbContext<ApplicationDbContext>(options =>
{
    var connectionString = builder.Configuration
        .GetConnectionString("DefaultConnection");
    options.UseSqlServer(connectionString);
});
```

## Docker Compose Environment

### Backend Service
```yaml
environment:
  - ASPNETCORE_ENVIRONMENT=Development
  - ASPNETCORE_URLS=http://+:80
  - ConnectionStrings__DefaultConnection=Server=sqlserver;Database=RegistrationAppDb;User Id=sa;Password=YourPassword;Encrypt=false;
```

### Frontend Service
```yaml
environment:
  - NGINX_HOST=localhost
  - NGINX_PORT=80
```

### Database Service
```yaml
environment:
  - ACCEPT_EULA=Y
  - SA_PASSWORD=YourSecurePassword123!@#
  - MSSQL_PID=Developer
```

## Security Configuration

### HTTPS Configuration
```csharp
builder.Services.AddHsts(options =>
{
    options.MaxAge = TimeSpan.FromDays(365);
    options.IncludeSubDomains = true;
    options.Preload = true;
});

app.UseHttpsRedirection();
app.UseHsts();
```

### Rate Limiting
```csharp
var rateLimitOptions = new RateLimitOptions
{
    PermitLimit = 100,
    Window = TimeSpan.FromMinutes(1)
};
```

### Security Headers
```csharp
app.Use(async (context, next) =>
{
    context.Response.Headers.Add("X-Content-Type-Options", "nosniff");
    context.Response.Headers.Add("X-Frame-Options", "DENY");
    context.Response.Headers.Add("X-XSS-Protection", "1; mode=block");
    await next();
});
```

## Azure DevOps Pipeline Configuration

### Build Variables
```yaml
variables:
  buildConfiguration: 'Release'
  nodeVersion: '18.x'
  dotnetVersion: '8.x'
```

### Deployment Variables
```yaml
variables:
  - group: RegistrationAppVariables
  - name: artifactName
    value: 'drop'
```

## Monitoring Configuration

### Application Insights
```csharp
builder.Services.AddApplicationInsightsTelemetry(options =>
{
    options.InstrumentationKey = builder.Configuration["ApplicationInsights:InstrumentationKey"];
});
```

### Logging Configuration
```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft": "Warning",
      "Microsoft.EntityFrameworkCore": "Information"
    }
  }
}
```
