# Registration Application - Setup & Deployment Guide

## Table of Contents
1. [Local Development Setup](#local-development-setup)
2. [Azure Resource Configuration](#azure-resource-configuration)
3. [Azure DevOps CI/CD Pipeline](#azure-devops-cicd-pipeline)
4. [Security Best Practices](#security-best-practices)

---

## Local Development Setup

### Prerequisites
- **Node.js** (v18+) and npm
- **.NET 8 SDK**
- **SQL Server 2019+** or **SQL Server Express**
- **Visual Studio Code** or **Visual Studio 2022**
- **Git**
- **Angular CLI** (install with: `npm install -g @angular/cli`)

### Step 1: Frontend Setup (Angular)

#### 1.1 Navigate to frontend folder
```powershell
cd c:\Users\Admin\source\repos\RegistrationApp\frontend
```

#### 1.2 Install dependencies
```powershell
npm install
```

#### 1.3 Configure API URL
Edit `src/app/services/item.service.ts` and update the API URL:
```typescript
private apiUrl = 'http://localhost:5000/api/items'; // For local development
```

#### 1.4 Start the Angular development server
```powershell
ng serve
```

The frontend will be available at `http://localhost:4200`

#### 1.5 Build for production
```powershell
ng build --configuration production
```
The built files will be in `dist/registration-app/`

---

### Step 2: Backend Setup (.NET Core)

#### 2.1 Navigate to backend folder
```powershell
cd c:\Users\Admin\source\repos\RegistrationApp\backend
```

#### 2.2 Restore NuGet packages
```powershell
dotnet restore
```

#### 2.3 Configure database connection
Edit `appsettings.json`:
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=RegistrationAppDb;Trusted_Connection=true;Encrypt=false;"
  }
}
```

For SQL Authentication, use:
```
Server=your-server;Database=RegistrationAppDb;User Id=sa;Password=YourPassword;Encrypt=false;
```

#### 2.4 Create and apply migrations
```powershell
# Add the using statement at the top of Program.cs if not present
# using Microsoft.EntityFrameworkCore;
# using RegistrationApi.Data;

# Create initial migration
dotnet ef migrations add InitialCreate

# Apply migration to database
dotnet ef database update
```

#### 2.5 Run the backend
```powershell
dotnet run
```

The API will be available at `https://localhost:5001` or `http://localhost:5000`

Test the API with:
```powershell
curl http://localhost:5000/api/items
```

---

### Step 3: Database Setup (SQL Server)

#### 3.1 Create the database manually (optional, if EF migrations don't work)

Open SQL Server Management Studio or use PowerShell:

```powershell
sqlcmd -S localhost -U sa -P "YourPassword"
```

Then execute the SQL script:
```sql
:r c:\Users\Admin\source\repos\RegistrationApp\database\01_InitialSetup.sql
```

#### 3.2 Verify database creation
```sql
SELECT * FROM sys.databases WHERE name = 'RegistrationAppDb'
SELECT * FROM RegistrationAppDb.INFORMATION_SCHEMA.TABLES
```

---

### Step 4: Frontend-Backend Integration

#### 4.1 Update CORS in backend (`Program.cs`)
```csharp
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAngularApp", corsPolicyBuilder =>
    {
        corsPolicyBuilder
            .WithOrigins("http://localhost:4200")
            .AllowAnyMethod()
            .AllowAnyHeader();
    });
});
```

#### 4.2 Configure proxy (optional, for development)
Create `proxy.conf.json` in frontend root:
```json
{
  "/api": {
    "target": "http://localhost:5000",
    "secure": false
  }
}
```

Update `angular.json` serve configuration:
```json
"serve": {
  "builder": "@angular-devkit/build-angular:dev-server",
  "options": {
    "proxyConfig": "proxy.conf.json"
  }
}
```

#### 4.3 Test integration
1. Start backend: `dotnet run`
2. Start frontend: `ng serve`
3. Navigate to `http://localhost:4200`
4. Try adding an item

---

## Azure Resource Configuration

### Prerequisites
- **Azure Subscription**
- **Azure CLI** installed
- **Azure DevOps Organization** (for CI/CD)

### Step 1: Create Azure Resources

#### 1.1 Login to Azure
```powershell
az login
az account set --subscription "Your Subscription ID"
```

#### 1.2 Create Resource Group
```powershell
$resourceGroup = "rg-registration-app"
$location = "East US"

az group create --name $resourceGroup --location $location
```

#### 1.3 Create Azure SQL Database
```powershell
$sqlServer = "registration-app-sql-$(Get-Random)"
$sqlDatabase = "RegistrationAppDb"
$adminUser = "sqladmin"
$adminPassword = "YourSecurePassword123!@#" # Change this!

# Create SQL Server
az sql server create `
  --resource-group $resourceGroup `
  --name $sqlServer `
  --location $location `
  --admin-user $adminUser `
  --admin-password $adminPassword

# Configure firewall rules (allow Azure services)
az sql server firewall-rule create `
  --resource-group $resourceGroup `
  --server $sqlServer `
  --name "AllowAzureServices" `
  --start-ip-address 0.0.0.0 `
  --end-ip-address 0.0.0.0

# Add your IP to firewall (replace with your IP)
az sql server firewall-rule create `
  --resource-group $resourceGroup `
  --server $sqlServer `
  --name "AllowMyIP" `
  --start-ip-address 203.0.113.0 `
  --end-ip-address 203.0.113.0

# Create database
az sql db create `
  --resource-group $resourceGroup `
  --server $sqlServer `
  --name $sqlDatabase `
  --edition Standard `
  --service-objective S0
```

#### 1.4 Create App Service Plan
```powershell
$appServicePlan = "asp-registration-app"

az appservice plan create `
  --name $appServicePlan `
  --resource-group $resourceGroup `
  --sku B1 `
  --is-linux
```

#### 1.5 Create Web App for Backend
```powershell
$backendAppName = "registration-api-$(Get-Random)"

az webapp create `
  --resource-group $resourceGroup `
  --plan $appServicePlan `
  --name $backendAppName `
  --runtime "DOTNETCORE:8.0"

# Configure connection string
az webapp config connection-string set `
  --name $backendAppName `
  --resource-group $resourceGroup `
  --connection-string-type SQLAzure `
  --settings DefaultConnection="Server=tcp:$sqlServer.database.windows.net,1433;Initial Catalog=$sqlDatabase;Persist Security Info=False;User ID=$adminUser;Password=$adminPassword;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
```

#### 1.6 Create Static Web App for Frontend
```powershell
$frontendAppName = "registration-app-$(Get-Random)"

az staticwebapp create `
  --name $frontendAppName `
  --resource-group $resourceGroup `
  --location $location `
  --sku Free
```

### Step 2: Configure Application Settings

#### 2.1 Backend App Settings
```powershell
az webapp config appsettings set `
  --name $backendAppName `
  --resource-group $resourceGroup `
  --settings `
    ASPNETCORE_ENVIRONMENT="Production" `
    "Logging:LogLevel:Default"="Information"
```

#### 2.2 Frontend Environment Configuration
Create `environment.prod.ts`:
```typescript
export const environment = {
  production: true,
  apiUrl: 'https://your-backend-app.azurewebsites.net/api'
};
```

Update `environment.ts`:
```typescript
export const environment = {
  production: false,
  apiUrl: 'http://localhost:5000/api'
};
```

---

## Azure DevOps CI/CD Pipeline

### Step 1: Setup Azure DevOps

#### 1.1 Create Azure DevOps Project
1. Go to https://dev.azure.com
2. Create new organization or use existing
3. Create new project (e.g., "RegistrationApp")

#### 1.2 Connect Git Repository
```powershell
cd c:\Users\Admin\source\repos\RegistrationApp
git init
git add .
git commit -m "Initial commit"
git remote add origin https://dev.azure.com/your-org/RegistrationApp/_git/RegistrationApp
git push -u origin main
```

### Step 2: Create CI/CD Pipeline

#### 2.1 Create Build Pipeline YAML
Create `azure-pipelines.yml` in repository root:

```yaml
trigger:
  - main

pr:
  - main

variables:
  buildConfiguration: 'Release'
  nodeVersion: '18.x'
  dotnetVersion: '8.x'

stages:
  - stage: Build
    displayName: 'Build Application'
    jobs:
      - job: BuildFrontend
        displayName: 'Build Angular Frontend'
        pool:
          vmImage: 'ubuntu-latest'
        steps:
          - task: NodeTool@0
            inputs:
              versionSpec: $(nodeVersion)
            displayName: 'Install Node.js'

          - task: Npm@1
            inputs:
              command: 'install'
              workingDir: '$(Build.SourcesDirectory)/frontend'
            displayName: 'npm install'

          - task: Npm@1
            inputs:
              command: 'custom'
              customCommand: 'run build'
              workingDir: '$(Build.SourcesDirectory)/frontend'
            displayName: 'Build Angular'

          - task: PublishBuildArtifacts@1
            inputs:
              pathToPublish: '$(Build.SourcesDirectory)/frontend/dist'
              artifactName: 'frontend'
            displayName: 'Publish Frontend Artifact'

      - job: BuildBackend
        displayName: 'Build .NET Core Backend'
        pool:
          vmImage: 'ubuntu-latest'
        steps:
          - task: UseDotNet@2
            inputs:
              version: $(dotnetVersion)
            displayName: 'Use .NET Core $(dotnetVersion)'

          - task: DotNetCoreCLI@2
            inputs:
              command: 'restore'
              projects: '$(Build.SourcesDirectory)/backend/**/*.csproj'
            displayName: 'Restore NuGet packages'

          - task: DotNetCoreCLI@2
            inputs:
              command: 'build'
              projects: '$(Build.SourcesDirectory)/backend/**/*.csproj'
              arguments: '--configuration $(buildConfiguration)'
            displayName: 'Build .NET Core'

          - task: DotNetCoreCLI@2
            inputs:
              command: 'publish'
              publishWebProjects: true
              arguments: '--configuration $(buildConfiguration) --output $(Build.ArtifactStagingDirectory)'
            displayName: 'Publish .NET Core'

          - task: PublishBuildArtifacts@1
            inputs:
              pathToPublish: '$(Build.ArtifactStagingDirectory)'
              artifactName: 'backend'
            displayName: 'Publish Backend Artifact'

  - stage: Deploy
    displayName: 'Deploy to Azure'
    dependsOn: Build
    condition: succeeded()
    jobs:
      - deployment: DeployBackend
        displayName: 'Deploy Backend'
        pool:
          vmImage: 'ubuntu-latest'
        environment: 'Production'
        strategy:
          runOnce:
            deploy:
              steps:
                - task: DownloadBuildArtifacts@0
                  inputs:
                    artifactName: 'backend'
                    downloadPath: '$(Pipeline.Workspace)'

                - task: AzureWebApp@1
                  inputs:
                    azureSubscription: 'Your-Azure-Service-Connection'
                    appType: 'webAppLinux'
                    appName: 'registration-api-xxxxx'
                    runtimeStack: 'DOTNETCORE|8.0'
                    package: '$(Pipeline.Workspace)/backend'
                    deploymentMethod: 'zipDeploy'
                  displayName: 'Deploy Backend to App Service'

                - script: |
                    az webapp deployment slot swap --name registration-api-xxxxx --resource-group rg-registration-app --slot staging
                  displayName: 'Swap Staging to Production'

      - deployment: DeployFrontend
        displayName: 'Deploy Frontend'
        pool:
          vmImage: 'ubuntu-latest'
        environment: 'Production'
        strategy:
          runOnce:
            deploy:
              steps:
                - task: DownloadBuildArtifacts@0
                  inputs:
                    artifactName: 'frontend'
                    downloadPath: '$(Pipeline.Workspace)'

                - task: AzureStaticWebApp@0
                  inputs:
                    azure_static_web_apps_api_token: '$(deployment_token)'
                    app_location: '$(Pipeline.Workspace)/frontend'
                    output_location: 'dist/registration-app'
                  displayName: 'Deploy Frontend to Static Web App'
```

#### 2.2 Create Release Pipeline
1. In Azure DevOps, go to **Pipelines** > **Releases**
2. Create new release pipeline
3. Add artifact from build pipeline
4. Create stages for development, staging, and production

### Step 3: Database Migration in Pipeline

Add database migration step in pipeline:
```yaml
- task: DotNetCoreCLI@2
  inputs:
    command: 'custom'
    custom: 'ef'
    arguments: 'database update --project $(Build.SourcesDirectory)/backend'
  displayName: 'Apply Entity Framework Migrations'
```

---

## Security Best Practices

### 1. Connection Strings & Secrets Management

#### Use Azure Key Vault
```powershell
# Create Key Vault
az keyvault create --name "registration-app-kv" --resource-group $resourceGroup

# Add connection string secret
az keyvault secret set --vault-name "registration-app-kv" `
  --name "ConnectionString" `
  --value "Server=tcp:$sqlServer.database.windows.net,1433;Initial Catalog=$sqlDatabase;Persist Security Info=False;User ID=$adminUser;Password=$adminPassword;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
```

#### Reference in .NET Core
```csharp
var keyVaultUrl = new Uri($"https://registration-app-kv.vault.azure.net/");
var credential = new DefaultAzureCredential();
var client = new SecretClient(keyVaultUrl, credential);

var connectionStringSecret = await client.GetSecretAsync("ConnectionString");
var connectionString = connectionStringSecret.Value.Value;
```

### 2. API Security

#### 2.1 Enable HTTPS only
```csharp
builder.Services.AddHsts(options =>
{
    options.MaxAge = TimeSpan.FromDays(365);
    options.IncludeSubDomains = true;
    options.Preload = true;
});

app.UseHsts();
```

#### 2.2 Implement Authentication & Authorization
```csharp
builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer(options =>
    {
        options.Authority = "https://login.microsoftonline.com/YOUR_TENANT_ID/v2.0";
        options.Audience = "YOUR_API_IDENTIFIER";
    });

app.UseAuthentication();
app.UseAuthorization();
```

### 3. Frontend Security

#### 3.1 Content Security Policy (CSP)
Add to `index.html`:
```html
<meta http-equiv="Content-Security-Policy" 
  content="default-src 'self'; 
  script-src 'self'; 
  style-src 'self' 'unsafe-inline'; 
  img-src 'self' data: https:;">
```

#### 3.2 CSRF Protection
```typescript
import { HttpClientXsrfModule } from '@angular/common/http';

@NgModule({
  imports: [
    HttpClientXsrfModule.withOptions({
      headerName: 'X-CSRF-TOKEN'
    })
  ]
})
```

### 4. Database Security

#### 4.1 SQL Injection Prevention
Use parameterized queries (already done with Entity Framework):
```csharp
// Safe - using parameterized queries
var item = await _context.Items.FirstOrDefaultAsync(i => i.Id == id);
```

#### 4.2 Row-Level Security (RLS) in SQL Server
```sql
CREATE SCHEMA Security;
GO

CREATE FUNCTION Security.fn_securitypredicate(@UserId NVARCHAR(100))
    RETURNS TABLE
    WITH SCHEMABINDING
AS
RETURN SELECT 1 AS fn_securitypredicate_result
WHERE DATABASE_PRINCIPAL_NAME() = @UserId;
GO

CREATE SECURITY POLICY ItemFilter
ADD FILTER PREDICATE Security.fn_securitypredicate(UserId) ON dbo.Items;
GO
```

### 5. Network Security

#### 5.1 Virtual Networks & NSGs
```powershell
# Create Virtual Network
az network vnet create --name vnet-registration --resource-group $resourceGroup

# Create Network Security Group
az network nsg create --name nsg-registration --resource-group $resourceGroup

# Add security rules
az network nsg rule create --name AllowHTTPS `
  --nsg-name nsg-registration `
  --resource-group $resourceGroup `
  --priority 100 `
  --access Allow `
  --protocol Tcp `
  --destination-port-ranges 443
```

### 6. Monitoring & Logging

#### 6.1 Application Insights
```powershell
az monitor app-insights component create `
  --app registration-app-insights `
  --location $location `
  --resource-group $resourceGroup `
  --application-type web
```

#### 6.2 Configure in .NET
```csharp
builder.Services.AddApplicationInsightsTelemetry();
```

### 7. Compliance & Best Practices

- ✅ Enable Azure Defender for SQL
- ✅ Use Managed Identities for Azure resources
- ✅ Enable audit logging
- ✅ Implement rate limiting
- ✅ Use SSL/TLS certificates
- ✅ Regular security patches and updates
- ✅ Implement backup and disaster recovery

---

## Troubleshooting

### Frontend Issues

**CORS Errors:**
- Ensure backend CORS policy includes frontend URL
- Check backend is running on expected port

**404 on API calls:**
- Verify API URL in `item.service.ts`
- Check backend is running
- Use browser DevTools Network tab to inspect requests

### Backend Issues

**Connection string errors:**
- Verify SQL Server is running
- Check database name matches
- Confirm firewall allows connections

**Migration failures:**
- Delete `Migrations` folder and recreate
- Ensure DbContext is properly configured
- Check Entity Framework tools: `dotnet ef`

### Database Issues

**Database not found:**
```powershell
# Check existing databases
sqlcmd -S localhost -U sa -q "SELECT name FROM sys.databases"
```

**Permission issues:**
```sql
-- Grant permissions to user
GRANT SELECT, INSERT, UPDATE, DELETE ON Items TO [YourUser];
```

---

## Additional Resources

- [Angular Documentation](https://angular.io/docs)
- [ASP.NET Core Documentation](https://docs.microsoft.com/aspnet/core)
- [Entity Framework Core](https://docs.microsoft.com/ef/core)
- [Azure App Service](https://docs.microsoft.com/azure/app-service)
- [Azure SQL Database](https://docs.microsoft.com/azure/azure-sql)
- [Azure DevOps CI/CD](https://docs.microsoft.com/azure/devops/pipelines)

---

## Support

For issues or questions, refer to:
1. Official documentation links above
2. Stack Overflow (tag: angular, asp.net-core)
3. GitHub Issues (if using GitHub repository)
