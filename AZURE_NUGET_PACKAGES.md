# Azure Integration NuGet Packages

## Installation Commands

Run these commands in your RegistrationApp.API project directory:

```bash
# Azure Key Vault
dotnet add package Azure.Identity
dotnet add package Azure.Security.KeyVault.Secrets

# Azure Storage
dotnet add package Azure.Storage.Blobs

# Azure Service Bus
dotnet add package Azure.Messaging.ServiceBus

# Azure Cosmos DB
dotnet add package Azure.Cosmos

# Azure Application Insights
dotnet add package Microsoft.ApplicationInsights
dotnet add package Microsoft.ApplicationInsights.AspNetCore
dotnet add package Microsoft.Extensions.Logging.ApplicationInsights

# Optional: For Azure Functions (if creating function apps)
dotnet add package Microsoft.Azure.WebJobs.Extensions.Storage
dotnet add package Microsoft.Azure.WebJobs.Extensions.ServiceBus
```

## Or Add to .csproj File

```xml
<ItemGroup>
  <!-- Azure Key Vault -->
  <PackageReference Include="Azure.Identity" Version="1.11.0" />
  <PackageReference Include="Azure.Security.KeyVault.Secrets" Version="4.5.0" />
  <PackageReference Include="Azure.Extensions.AspNetCore.Configuration.Secrets" Version="1.3.0" />

  <!-- Azure Storage -->
  <PackageReference Include="Azure.Storage.Blobs" Version="12.19.0" />

  <!-- Azure Service Bus -->
  <PackageReference Include="Azure.Messaging.ServiceBus" Version="7.17.0" />

  <!-- Azure Cosmos DB -->
  <PackageReference Include="Azure.Cosmos" Version="4.0.0" />

  <!-- Azure Application Insights -->
  <PackageReference Include="Microsoft.ApplicationInsights" Version="2.22.0" />
  <PackageReference Include="Microsoft.ApplicationInsights.AspNetCore" Version="2.22.0" />
  <PackageReference Include="Microsoft.Extensions.Logging.ApplicationInsights" Version="2.22.0" />
</ItemGroup>
```

## Restore Dependencies

```bash
dotnet restore
```

## Verify Installation

```bash
dotnet list package

# Output should show all Azure packages
```

---

## Optional Packages for Additional Features

### For Sending Emails (SendGrid)
```bash
dotnet add package SendGrid
```

### For Azure Functions
```bash
dotnet add package Azure.Functions.Worker
dotnet add package Azure.Functions.Worker.Extensions.ServiceBus
dotnet add package Azure.Functions.Worker.Extensions.Storage
```

### For Authentication (Azure AD)
```bash
dotnet add package Microsoft.Identity.Web
dotnet add package Microsoft.Identity.Web.DownstreamApi
```

### For Health Checks
```bash
dotnet add package AspNetCore.HealthChecks.CosmosDb
dotnet add package AspNetCore.HealthChecks.AzureServiceBus
dotnet add package AspNetCore.HealthChecks.AzureStorage
```

---

## Summary

**Total Packages**: 11 core + 5 optional = 16

**Size Impact**: ~50 MB added to project dependencies

**Compatibility**: .NET 8.0 compatible ✅

---

**Installation Date**: February 5, 2026
