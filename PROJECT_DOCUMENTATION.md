# RegistrationApp - Complete Project Documentation

## Table of Contents
1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Frontend Setup](#frontend-setup)
4. [Backend Setup](#backend-setup)
5. [Database Setup](#database-setup)
6. [Local Deployment with Docker Compose](#local-deployment-with-docker-compose)
7. [Azure Deployment](#azure-deployment)
8. [CI/CD Pipeline with Jenkins](#cicd-pipeline-with-jenkins)
9. [Project Structure](#project-structure)
10. [Commands Reference](#commands-reference)

---

## Project Overview

**RegistrationApp** is a full-stack web application for managing user registrations with the following stack:
- **Frontend**: Angular 17 (TypeScript)
- **Backend**: .NET Core 8 (C#)
- **Database**: SQL Server (Azure SQL Database)
- **Deployment**: Azure Container Instances (ACI)
- **CI/CD**: Jenkins (Self-hosted)
- **Container Registry**: Azure Container Registry (ACR)

**Project Start Date**: February 2026
**Current Status**: ✅ Production Deployed
**Monthly Cost**: $25/month (sustainable for 7+ months on $180 trial budget)

### Live URLs
- **Frontend**: http://registration-frontend-prod.centralindia.azurecontainer.io/
- **Backend API**: http://registration-api-prod.centralindia.azurecontainer.io/api/registrations
- **Database**: regsql2807.database.windows.net

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      CLIENT BROWSER                         │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│              FRONTEND (Angular 17)                          │
│  Container: registration-frontend-prod                      │
│  Port: 80 → 4200                                            │
│  URL: registration-frontend-prod.centralindia...            │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│              BACKEND (.NET Core 8 API)                      │
│  Container: registration-api-prod                           │
│  Port: 80 → 5000                                            │
│  URL: registration-api-prod.centralindia...                 │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│         AZURE SQL DATABASE                                  │
│  Server: regsql2807.database.windows.net                    │
│  Database: RegistrationAppDb                                │
│  Tier: Serverless, Basic                                    │
└─────────────────────────────────────────────────────────────┘
```

---

## Frontend Setup

### Technologies Used
- **Framework**: Angular 17
- **Language**: TypeScript
- **Styling**: CSS/Bootstrap
- **HTTP Client**: Angular HttpClient
- **Package Manager**: npm

### Project Creation Commands

```bash
# Create Angular project
ng new RegistrationApp-Frontend --routing --style=css

# Navigate to project
cd RegistrationApp-Frontend

# Install dependencies
npm install

# Generate components
ng generate component components/registration-form
ng generate component components/registration-list
ng generate component components/registration-detail

# Generate service
ng generate service services/registration

# Build for production
ng build --configuration production

# Serve development
ng serve
```

### Frontend Structure
```
RegistrationApp-Frontend/
├── src/
│   ├── app/
│   │   ├── components/
│   │   │   ├── registration-form/
│   │   │   ├── registration-list/
│   │   │   └── registration-detail/
│   │   ├── services/
│   │   │   └── registration.service.ts
│   │   ├── models/
│   │   │   └── registration.model.ts
│   │   ├── app.component.ts
│   │   └── app.module.ts
│   ├── assets/
│   ├── styles.css
│   └── main.ts
├── angular.json
├── package.json
└── tsconfig.json
```

### Key Components

**registration.model.ts**
```typescript
export interface Registration {
  id: number;
  firstName: string;
  lastName: string;
  email: string;
  phone: string;
  registeredDate: Date;
}
```

**registration.service.ts**
```typescript
import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { Registration } from '../models/registration.model';

@Injectable({
  providedIn: 'root'
})
export class RegistrationService {
  private apiUrl = 'http://localhost:5000/api/registrations';

  constructor(private http: HttpClient) {}

  getRegistrations(): Observable<Registration[]> {
    return this.http.get<Registration[]>(this.apiUrl);
  }

  getRegistration(id: number): Observable<Registration> {
    return this.http.get<Registration>(`${this.apiUrl}/${id}`);
  }

  createRegistration(registration: Registration): Observable<Registration> {
    return this.http.post<Registration>(this.apiUrl, registration);
  }

  updateRegistration(id: number, registration: Registration): Observable<void> {
    return this.http.put<void>(`${this.apiUrl}/${id}`, registration);
  }

  deleteRegistration(id: number): Observable<void> {
    return this.http.delete<void>(`${this.apiUrl}/${id}`);
  }
}
```

### Dockerfile for Frontend
```dockerfile
# Stage 1: Build
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build -- --configuration production

# Stage 2: Runtime
FROM nginx:alpine
COPY --from=builder /app/dist/registration-app-frontend /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

---

## Backend Setup

### Technologies Used
- **Framework**: .NET Core 8
- **Language**: C#
- **Database**: Entity Framework Core
- **API**: REST API with Controllers
- **Package Manager**: NuGet

### Project Creation Commands

```bash
# Create .NET solution
dotnet new sln -n RegistrationApp

# Create class library for models
dotnet new classlib -n RegistrationApp.Models
dotnet sln RegistrationApp.sln add RegistrationApp.Models/RegistrationApp.Models.csproj

# Create class library for data access
dotnet new classlib -n RegistrationApp.Data
dotnet sln RegistrationApp.sln add RegistrationApp.Data/RegistrationApp.Data.csproj

# Create API project
dotnet new webapi -n RegistrationApp.API
dotnet sln RegistrationApp.sln add RegistrationApp.API/RegistrationApp.API.csproj

# Add project references
cd RegistrationApp.API
dotnet add reference ../RegistrationApp.Models/RegistrationApp.Models.csproj
dotnet add reference ../RegistrationApp.Data/RegistrationApp.Data.csproj

# Add NuGet packages
dotnet add package Microsoft.EntityFrameworkCore.SqlServer
dotnet add package Microsoft.EntityFrameworkCore.Tools
dotnet add package Microsoft.AspNetCore.Cors

# Install dependencies
dotnet restore

# Create database migration
dotnet ef migrations add InitialCreate -p ../RegistrationApp.Data -s .
dotnet ef database update -p ../RegistrationApp.Data -s .

# Build
dotnet build

# Run
dotnet run

# Publish for production
dotnet publish -c Release -o ./publish
```

### Backend Structure
```
RegistrationApp/
├── RegistrationApp.Models/
│   ├── Registration.cs
│   └── RegistrationDto.cs
├── RegistrationApp.Data/
│   ├── RegistrationContext.cs
│   ├── Repositories/
│   │   ├── IRegistrationRepository.cs
│   │   └── RegistrationRepository.cs
│   └── Migrations/
├── RegistrationApp.API/
│   ├── Controllers/
│   │   └── RegistrationsController.cs
│   ├── Program.cs
│   ├── appsettings.json
│   └── appsettings.Development.json
└── RegistrationApp.sln
```

### Key Classes

**Registration.cs (Model)**
```csharp
using System;
using System.ComponentModel.DataAnnotations;

namespace RegistrationApp.Models
{
    public class Registration
    {
        [Key]
        public int Id { get; set; }

        [Required]
        [StringLength(50)]
        public string FirstName { get; set; }

        [Required]
        [StringLength(50)]
        public string LastName { get; set; }

        [Required]
        [EmailAddress]
        public string Email { get; set; }

        [Phone]
        public string Phone { get; set; }

        public DateTime RegisteredDate { get; set; } = DateTime.UtcNow;
    }
}
```

**RegistrationContext.cs (DbContext)**
```csharp
using Microsoft.EntityFrameworkCore;
using RegistrationApp.Models;

namespace RegistrationApp.Data
{
    public class RegistrationContext : DbContext
    {
        public RegistrationContext(DbContextOptions<RegistrationContext> options)
            : base(options)
        {
        }

        public DbSet<Registration> Registrations { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);
            
            modelBuilder.Entity<Registration>()
                .HasIndex(r => r.Email)
                .IsUnique();
        }
    }
}
```

**RegistrationsController.cs**
```csharp
using Microsoft.AspNetCore.Mvc;
using RegistrationApp.Data;
using RegistrationApp.Models;

namespace RegistrationApp.API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class RegistrationsController : ControllerBase
    {
        private readonly IRegistrationRepository _repository;

        public RegistrationsController(IRegistrationRepository repository)
        {
            _repository = repository;
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<Registration>>> GetRegistrations()
        {
            var registrations = await _repository.GetAllAsync();
            return Ok(registrations);
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<Registration>> GetRegistration(int id)
        {
            var registration = await _repository.GetByIdAsync(id);
            if (registration == null)
                return NotFound();
            return Ok(registration);
        }

        [HttpPost]
        public async Task<ActionResult<Registration>> CreateRegistration(Registration registration)
        {
            await _repository.AddAsync(registration);
            await _repository.SaveChangesAsync();
            return CreatedAtAction(nameof(GetRegistration), new { id = registration.Id }, registration);
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> UpdateRegistration(int id, Registration registration)
        {
            var existing = await _repository.GetByIdAsync(id);
            if (existing == null)
                return NotFound();

            existing.FirstName = registration.FirstName;
            existing.LastName = registration.LastName;
            existing.Email = registration.Email;
            existing.Phone = registration.Phone;

            _repository.Update(existing);
            await _repository.SaveChangesAsync();
            return NoContent();
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteRegistration(int id)
        {
            var registration = await _repository.GetByIdAsync(id);
            if (registration == null)
                return NotFound();

            _repository.Delete(registration);
            await _repository.SaveChangesAsync();
            return NoContent();
        }
    }
}
```

**Program.cs (Startup Configuration)**
```csharp
using Microsoft.EntityFrameworkCore;
using RegistrationApp.Data;

var builder = WebApplication.CreateBuilder(args);

// Add services
builder.Services.AddControllers();
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", builder =>
    {
        builder.AllowAnyOrigin()
               .AllowAnyMethod()
               .AllowAnyHeader();
    });
});

// Add Entity Framework
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
builder.Services.AddDbContext<RegistrationContext>(options =>
    options.UseSqlServer(connectionString));

// Add repositories
builder.Services.AddScoped<IRegistrationRepository, RegistrationRepository>();

// Add Swagger
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// Middleware
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseCors("AllowAll");
app.UseAuthorization();
app.MapControllers();

app.Run();
```

### appsettings.json
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=.;Database=RegistrationAppDb;Integrated Security=true;TrustServerCertificate=true;"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information"
    }
  },
  "AllowedHosts": "*"
}
```

### Dockerfile for Backend
```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS builder
WORKDIR /src
COPY ["RegistrationApp.API/RegistrationApp.API.csproj", "RegistrationApp.API/"]
COPY ["RegistrationApp.Models/RegistrationApp.Models.csproj", "RegistrationApp.Models/"]
COPY ["RegistrationApp.Data/RegistrationApp.Data.csproj", "RegistrationApp.Data/"]
RUN dotnet restore "RegistrationApp.API/RegistrationApp.API.csproj"
COPY . .
RUN dotnet build "RegistrationApp.API/RegistrationApp.API.csproj" -c Release -o /app/build
RUN dotnet publish "RegistrationApp.API/RegistrationApp.API.csproj" -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app
COPY --from=builder /app/publish .
EXPOSE 80
ENV ASPNETCORE_URLS=http://+:80
ENTRYPOINT ["dotnet", "RegistrationApp.API.dll"]
```

---

## Database Setup

### SQL Server Database

**Local Development Database Creation**
```bash
# Using SQL Server Management Studio (SSMS)
# OR using SqlCmd

sqlcmd -S . -U sa -P "YourPassword" -Q "CREATE DATABASE RegistrationAppDb;"
```

**Database Schema (Generated by EF Core)**
```sql
CREATE TABLE [Registrations] (
    [Id] int NOT NULL IDENTITY,
    [FirstName] nvarchar(50) NOT NULL,
    [LastName] nvarchar(50) NOT NULL,
    [Email] nvarchar(max) NOT NULL,
    [Phone] nvarchar(max) NULL,
    [RegisteredDate] datetime2 NOT NULL,
    CONSTRAINT [PK_Registrations] PRIMARY KEY ([Id])
);

CREATE UNIQUE INDEX [IX_Registrations_Email] ON [Registrations] ([Email]);
```

### Azure SQL Database

**Azure CLI Commands to Create Database**
```bash
# Set variables
$RESOURCE_GROUP = "rg-registration-app"
$SQL_SERVER = "regsql2807"
$SQL_DATABASE = "RegistrationAppDb"
$LOCATION = "centralindia"
$ADMIN_USER = "sqladmin"
$ADMIN_PASSWORD = "YourSecurePassword123!"

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create SQL Server
az sql server create `
  --resource-group $RESOURCE_GROUP `
  --name $SQL_SERVER `
  --location $LOCATION `
  --admin-user $ADMIN_USER `
  --admin-password $ADMIN_PASSWORD

# Create database (Serverless, Basic tier)
az sql db create `
  --resource-group $RESOURCE_GROUP `
  --server $SQL_SERVER `
  --name $SQL_DATABASE `
  --edition GeneralPurpose `
  --family Gen5 `
  --capacity 2 `
  --compute-model Serverless

# Configure firewall to allow Azure services
az sql server firewall-rule create `
  --resource-group $RESOURCE_GROUP `
  --server $SQL_SERVER `
  --name "AllowAzureServices" `
  --start-ip-address 0.0.0.0 `
  --end-ip-address 0.0.0.0

# Configure firewall for your IP
az sql server firewall-rule create `
  --resource-group $RESOURCE_GROUP `
  --server $SQL_SERVER `
  --name "AllowMyIP" `
  --start-ip-address YOUR_IP `
  --end-ip-address YOUR_IP

# Get connection string
az sql db show-connection-string `
  --server $SQL_SERVER `
  --name $SQL_DATABASE `
  --client sqlcmd
```

**Connection String for Azure SQL**
```
Server=tcp:regsql2807.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourSecurePassword123!;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;
```

---

## Local Deployment with Docker Compose

### docker-compose.yml
```yaml
version: '3.8'

services:
  # SQL Server Database
  sqlserver:
    image: mcr.microsoft.com/mssql/server:2022-latest
    environment:
      SA_PASSWORD: "YourPassword123!"
      ACCEPT_EULA: "Y"
      MSSQL_PID: "Express"
    ports:
      - "1433:1433"
    volumes:
      - sqlserver_data:/var/opt/mssql
    networks:
      - registration-network

  # Backend API (.NET Core)
  backend:
    build:
      context: ./RegistrationApp.API
      dockerfile: Dockerfile
    environment:
      ConnectionStrings__DefaultConnection: "Server=sqlserver;Database=RegistrationAppDb;User ID=sa;Password=YourPassword123!;TrustServerCertificate=true;"
      ASPNETCORE_ENVIRONMENT: "Production"
      ASPNETCORE_URLS: "http://+:80"
    ports:
      - "5000:80"
    depends_on:
      - sqlserver
    networks:
      - registration-network

  # Frontend (Angular)
  frontend:
    build:
      context: ./RegistrationApp-Frontend
      dockerfile: Dockerfile
    environment:
      API_URL: "http://backend:80"
    ports:
      - "4200:80"
    depends_on:
      - backend
    networks:
      - registration-network

volumes:
  sqlserver_data:

networks:
  registration-network:
    driver: bridge
```

### Docker Compose Commands

```bash
# Build all services
docker-compose build

# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop all services
docker-compose down

# Stop and remove volumes
docker-compose down -v

# Rebuild and start
docker-compose up -d --build

# View running services
docker-compose ps

# Execute command in container
docker-compose exec backend dotnet ef database update
```

### Verify Local Deployment
```bash
# Check services running
docker-compose ps

# Test backend API
curl http://localhost:5000/api/registrations

# Test frontend
Open browser: http://localhost:4200

# Check database
sqlcmd -S localhost -U sa -P "YourPassword123!" -Q "SELECT * FROM RegistrationAppDb.dbo.Registrations;"
```

---

## Azure Deployment

### Prerequisites
```bash
# Install/Update Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Login to Azure
az login

# Set subscription
az account set --subscription "YourSubscriptionID"

# Verify login
az account show
```

### Create Azure Container Registry (ACR)

```bash
# Set variables
$RESOURCE_GROUP = "rg-registration-app"
$ACR_NAME = "registrationappacr"
$LOCATION = "centralindia"

# Create Container Registry
az acr create `
  --resource-group $RESOURCE_GROUP `
  --name $ACR_NAME `
  --sku Basic `
  --location $LOCATION

# Get ACR login server
az acr show `
  --resource-group $RESOURCE_GROUP `
  --name $ACR_NAME `
  --query loginServer

# Login to ACR
az acr login --name $ACR_NAME

# Get ACR credentials
az acr credential show `
  --resource-group $RESOURCE_GROUP `
  --name $ACR_NAME
```

### Build and Push Docker Images to ACR

```bash
# Set variables
$ACR_LOGINSERVER = "registrationappacr.azurecr.io"
$IMAGE_TAG = "latest"

# Build backend image
docker build -t $ACR_LOGINSERVER/registration-api:$IMAGE_TAG `
  -f RegistrationApp.API/Dockerfile .

# Build frontend image
docker build -t $ACR_LOGINSERVER/registration-frontend:$IMAGE_TAG `
  -f RegistrationApp-Frontend/Dockerfile RegistrationApp-Frontend/

# Push to ACR
docker push $ACR_LOGINSERVER/registration-api:$IMAGE_TAG
docker push $ACR_LOGINSERVER/registration-frontend:$IMAGE_TAG

# Verify images in ACR
az acr repository list `
  --resource-group $RESOURCE_GROUP `
  --name $ACR_NAME

az acr repository show-tags `
  --resource-group $RESOURCE_GROUP `
  --name $ACR_NAME `
  --repository registration-api
```

### Deploy to Azure Container Instances (ACI)

```bash
# Set variables
$RESOURCE_GROUP = "rg-registration-app"
$ACR_NAME = "registrationappacr"
$ACR_LOGINSERVER = "registrationappacr.azurecr.io"
$SQL_SERVER = "regsql2807"
$SQL_DATABASE = "RegistrationAppDb"
$SQL_USER = "sqladmin"
$SQL_PASSWORD = "YourPassword123!"
$LOCATION = "centralindia"

# Get ACR credentials
$ACR_USERNAME = (az acr credential show -n $ACR_NAME --query username -o tsv)
$ACR_PASSWORD = (az acr credential show -n $ACR_NAME --query "passwords[0].value" -o tsv)

# Deploy Backend Container
az container create `
  --resource-group $RESOURCE_GROUP `
  --name registration-api-prod `
  --image $ACR_LOGINSERVER/registration-api:latest `
  --registry-login-server $ACR_LOGINSERVER `
  --registry-username $ACR_USERNAME `
  --registry-password $ACR_PASSWORD `
  --cpu 1 `
  --memory 1 `
  --ports 80 `
  --dns-name-label registration-api-prod `
  --location $LOCATION `
  --environment-variables `
    "ConnectionStrings__DefaultConnection=Server=tcp:$SQL_SERVER.database.windows.net,1433;Initial Catalog=$SQL_DATABASE;User ID=$SQL_USER;Password=$SQL_PASSWORD;Encrypt=true;Connection Timeout=30;" `
    "ASPNETCORE_ENVIRONMENT=Production"

# Deploy Frontend Container
az container create `
  --resource-group $RESOURCE_GROUP `
  --name registration-frontend-prod `
  --image $ACR_LOGINSERVER/registration-frontend:latest `
  --registry-login-server $ACR_LOGINSERVER `
  --registry-username $ACR_USERNAME `
  --registry-password $ACR_PASSWORD `
  --cpu 1 `
  --memory 1 `
  --ports 80 `
  --dns-name-label registration-frontend-prod `
  --location $LOCATION `
  --environment-variables `
    "API_URL=http://registration-api-prod.centralindia.azurecontainer.io/"

# Get container details
az container show `
  --resource-group $RESOURCE_GROUP `
  --name registration-api-prod `
  --query "{FQDN:ipAddress.fqdn,State:instanceView.state}"

az container show `
  --resource-group $RESOURCE_GROUP `
  --name registration-frontend-prod `
  --query "{FQDN:ipAddress.fqdn,State:instanceView.state}"

# View logs
az container logs `
  --resource-group $RESOURCE_GROUP `
  --name registration-api-prod

az container logs `
  --resource-group $RESOURCE_GROUP `
  --name registration-frontend-prod

# Update container with new image
az container create `
  --resource-group $RESOURCE_GROUP `
  --name registration-api-prod `
  --image $ACR_LOGINSERVER/registration-api:latest `
  --registry-login-server $ACR_LOGINSERVER `
  --registry-username $ACR_USERNAME `
  --registry-password $ACR_PASSWORD `
  --cpu 1 `
  --memory 1 `
  --ports 80 `
  --dns-name-label registration-api-prod `
  --location $LOCATION `
  --environment-variables `
    "ConnectionStrings__DefaultConnection=Server=tcp:$SQL_SERVER.database.windows.net,1433;Initial Catalog=$SQL_DATABASE;User ID=$SQL_USER;Password=$SQL_PASSWORD;Encrypt=true;Connection Timeout=30;" `
    "ASPNETCORE_ENVIRONMENT=Production" `
  --no-wait
```

### Verify Azure Deployment

```bash
# Check container status
az container show `
  --resource-group rg-registration-app `
  --name registration-api-prod `
  --query "instanceView.state"

# Test API endpoint
curl http://registration-api-prod.centralindia.azurecontainer.io/api/registrations

# Test Frontend endpoint
curl http://registration-frontend-prod.centralindia.azurecontainer.io/

# View resource costs
az consumption meter list --query "[?contains(meterName, 'Container Instances')]"
```

---

## CI/CD Pipeline with Jenkins

### Jenkins Setup

```bash
# Start Jenkins in Docker
docker run -d `
  -p 8080:8080 `
  -p 50000:50000 `
  -v jenkins_home:/var/jenkins_home `
  -v /var/run/docker.sock:/var/run/docker.sock `
  --user root `
  --name jenkins `
  jenkins/jenkins:lts

# Wait for initialization (15-30 seconds)
Start-Sleep -Seconds 30

# Install Docker in Jenkins
docker exec jenkins bash -c "apt-get update -qq && apt-get install -y docker.io curl git"

# Install Azure CLI in Jenkins
docker exec jenkins bash -c "curl -sL https://aka.ms/InstallAzureCLIDeb | bash"

# Verify installations
docker exec jenkins bash -c "docker --version && az --version && git --version"

# Get initial admin password
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

### Jenkins Credentials Setup

```bash
# Create Azure Service Principal
az ad sp create-for-rbac `
  --name "JenkinsDeployment" `
  --role contributor `
  --scopes /subscriptions/$(az account show --query id -o tsv) `
  --sdk-auth
```

**Credentials to add in Jenkins UI:**
| ID | Value |
|---|---|
| AZURE_CLIENT_ID | `<clientId from above>` |
| AZURE_CLIENT_SECRET | `<clientSecret from above>` |
| AZURE_TENANT_ID | `<tenantId from above>` |
| AZURE_SUBSCRIPTION_ID | `<subscriptionId from above>` |

**How to add credentials in Jenkins:**
1. Go to `http://localhost:8080`
2. Click **Manage Jenkins** → **Manage Credentials** → **System** → **Global credentials**
3. Click **+ Add Credentials**
4. Select Kind: **Secret text**
5. Enter Secret value
6. Enter ID (exactly as shown above)
7. Click **Create**
8. Repeat for all 4 credentials

### Jenkinsfile.declarative

```groovy
pipeline {
    agent any

    environment {
        DOCKER_REGISTRY = 'registrationappacr.azurecr.io'
        ACR_NAME = 'registrationappacr'
        RESOURCE_GROUP = 'rg-registration-app'
        BUILD_TAG = "${BUILD_NUMBER}"
        AZURE_CLIENT_ID = credentials('AZURE_CLIENT_ID')
        AZURE_CLIENT_SECRET = credentials('AZURE_CLIENT_SECRET')
        AZURE_TENANT_ID = credentials('AZURE_TENANT_ID')
        AZURE_SUBSCRIPTION_ID = credentials('AZURE_SUBSCRIPTION_ID')
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
    }

    stages {
        stage('Clone Repository') {
            steps {
                echo '========== CLONING REPOSITORY =========='
                sh '''
                    git clone https://github.com/BrooksCoder/RegistrationApp.git .
                    git status
                '''
                echo '========== REPOSITORY CLONED =========='
            }
        }

        stage('Azure Login') {
            steps {
                echo '========== LOGGING INTO AZURE =========='
                sh '''
                    az login --service-principal \
                      -u $AZURE_CLIENT_ID \
                      -p $AZURE_CLIENT_SECRET \
                      --tenant $AZURE_TENANT_ID
                    az account set --subscription $AZURE_SUBSCRIPTION_ID
                    az account show
                '''
                echo '========== AZURE LOGIN SUCCESSFUL =========='
            }
        }

        stage('Build Backend') {
            steps {
                echo '========== BUILDING BACKEND =========='
                sh '''
                    docker build -t $DOCKER_REGISTRY/registration-api:v$BUILD_TAG \
                      -f RegistrationApp.API/Dockerfile .
                    docker images | grep registration-api
                '''
                echo '========== BACKEND BUILD COMPLETE =========='
            }
        }

        stage('Build Frontend') {
            steps {
                echo '========== BUILDING FRONTEND =========='
                sh '''
                    docker build -t $DOCKER_REGISTRY/registration-frontend:v$BUILD_TAG \
                      -f RegistrationApp-Frontend/Dockerfile RegistrationApp-Frontend/
                    docker images | grep registration-frontend
                '''
                echo '========== FRONTEND BUILD COMPLETE =========='
            }
        }

        stage('Login to ACR') {
            steps {
                echo '========== LOGGING INTO ACR =========='
                sh '''
                    az acr login --name $ACR_NAME
                '''
                echo '========== ACR LOGIN SUCCESSFUL =========='
            }
        }

        stage('Push Backend Image') {
            steps {
                echo '========== PUSHING BACKEND IMAGE =========='
                sh '''
                    docker push $DOCKER_REGISTRY/registration-api:v$BUILD_TAG
                    docker push $DOCKER_REGISTRY/registration-api:latest
                '''
                echo '========== BACKEND IMAGE PUSHED =========='
            }
        }

        stage('Push Frontend Image') {
            steps {
                echo '========== PUSHING FRONTEND IMAGE =========='
                sh '''
                    docker push $DOCKER_REGISTRY/registration-frontend:v$BUILD_TAG
                    docker push $DOCKER_REGISTRY/registration-frontend:latest
                '''
                echo '========== FRONTEND IMAGE PUSHED =========='
            }
        }

        stage('Deploy Backend') {
            steps {
                echo '========== DEPLOYING BACKEND TO ACI =========='
                sh '''
                    ACR_USERNAME=$(az acr credential show -n $ACR_NAME --query username -o tsv)
                    ACR_PASSWORD=$(az acr credential show -n $ACR_NAME --query "passwords[0].value" -o tsv)
                    
                    az container create \
                      --resource-group $RESOURCE_GROUP \
                      --name registration-api-prod \
                      --image $DOCKER_REGISTRY/registration-api:latest \
                      --registry-login-server $DOCKER_REGISTRY \
                      --registry-username $ACR_USERNAME \
                      --registry-password $ACR_PASSWORD \
                      --cpu 1 \
                      --memory 1 \
                      --ports 80 \
                      --dns-name-label registration-api-prod \
                      --location centralindia \
                      --environment-variables \
                        "ConnectionStrings__DefaultConnection=Server=tcp:regsql2807.database.windows.net,1433;Initial Catalog=RegistrationAppDb;User ID=sqladmin;Password=YOUR_PASSWORD;Encrypt=true;Connection Timeout=30;" \
                        "ASPNETCORE_ENVIRONMENT=Production" \
                      --no-wait
                '''
                echo '========== BACKEND DEPLOYMENT INITIATED =========='
            }
        }

        stage('Deploy Frontend') {
            steps {
                echo '========== DEPLOYING FRONTEND TO ACI =========='
                sh '''
                    ACR_USERNAME=$(az acr credential show -n $ACR_NAME --query username -o tsv)
                    ACR_PASSWORD=$(az acr credential show -n $ACR_NAME --query "passwords[0].value" -o tsv)
                    
                    az container create \
                      --resource-group $RESOURCE_GROUP \
                      --name registration-frontend-prod \
                      --image $DOCKER_REGISTRY/registration-frontend:latest \
                      --registry-login-server $DOCKER_REGISTRY \
                      --registry-username $ACR_USERNAME \
                      --registry-password $ACR_PASSWORD \
                      --cpu 1 \
                      --memory 1 \
                      --ports 80 \
                      --dns-name-label registration-frontend-prod \
                      --location centralindia \
                      --environment-variables \
                        "API_URL=http://registration-api-prod.centralindia.azurecontainer.io/" \
                      --no-wait
                '''
                echo '========== FRONTEND DEPLOYMENT INITIATED =========='
            }
        }
    }

    post {
        success {
            echo '========== BUILD SUCCESSFUL =========='
            echo "Frontend: http://registration-frontend-prod.centralindia.azurecontainer.io/"
            echo "Backend: http://registration-api-prod.centralindia.azurecontainer.io/api/registrations"
        }
        failure {
            echo '========== BUILD FAILED =========='
        }
    }
}
```

### Run Jenkins Pipeline

```bash
# 1. Go to Jenkins UI
# http://localhost:8080

# 2. Create New Item
#    - Name: RegistrationApp-Deploy
#    - Type: Pipeline
#    - Click OK

# 3. Configure Pipeline
#    - Definition: Pipeline script
#    - Paste Jenkinsfile.declarative content

# 4. Click Save

# 5. Click "Build Now"

# 6. Monitor console output
```

### Monitor Pipeline Execution

```bash
# View Jenkins logs
docker logs -f jenkins

# View specific build logs
# http://localhost:8080/job/RegistrationApp-Deploy/1/console

# Check container deployment status
az container show \
  --resource-group rg-registration-app \
  --name registration-api-prod \
  --query "instanceView.state"

# View container logs
az container logs \
  --resource-group rg-registration-app \
  --name registration-api-prod
```

---

## Project Structure

```
RegistrationApp/
├── RegistrationApp.Models/
│   ├── Registration.cs
│   ├── RegistrationDto.cs
│   ├── RegistrationApp.Models.csproj
│   └── obj/
├── RegistrationApp.Data/
│   ├── RegistrationContext.cs
│   ├── Repositories/
│   │   ├── IRegistrationRepository.cs
│   │   └── RegistrationRepository.cs
│   ├── Migrations/
│   │   ├── 20260101000000_InitialCreate.cs
│   │   └── RegistrationContextModelSnapshot.cs
│   ├── RegistrationApp.Data.csproj
│   └── obj/
├── RegistrationApp.API/
│   ├── Controllers/
│   │   └── RegistrationsController.cs
│   ├── Properties/
│   │   └── launchSettings.json
│   ├── appsettings.json
│   ├── appsettings.Development.json
│   ├── Program.cs
│   ├── Dockerfile
│   ├── RegistrationApp.API.csproj
│   └── obj/
├── RegistrationApp-Frontend/
│   ├── src/
│   │   ├── app/
│   │   │   ├── components/
│   │   │   │   ├── registration-form/
│   │   │   │   ├── registration-list/
│   │   │   │   └── registration-detail/
│   │   │   ├── models/
│   │   │   │   └── registration.model.ts
│   │   │   ├── services/
│   │   │   │   └── registration.service.ts
│   │   │   ├── app.component.ts
│   │   │   ├── app.module.ts
│   │   │   └── main.ts
│   │   ├── assets/
│   │   ├── styles.css
│   │   └── index.html
│   ├── angular.json
│   ├── package.json
│   ├── tsconfig.json
│   ├── Dockerfile
│   ├── nginx.conf
│   ├── docker-entrypoint.sh
│   └── dist/
├── docker-compose.yml
├── Jenkinsfile
├── Jenkinsfile.declarative
├── RegistrationApp.sln
├── .gitignore
├── README.md
└── PROJECT_DOCUMENTATION.md
```

---

## Commands Reference

### Quick Start

```bash
# Local Development
docker-compose up -d
docker-compose logs -f

# Access
Frontend: http://localhost:4200
Backend: http://localhost:5000/api/registrations
Database: localhost:1433

# Stop
docker-compose down
```

### Frontend Commands

```bash
# Install dependencies
npm install

# Start development server
npm start

# Build for production
npm run build

# Run tests
npm test

# Lint code
npm run lint
```

### Backend Commands

```bash
# Install/restore dependencies
dotnet restore

# Run development server
dotnet run

# Build for production
dotnet build -c Release

# Publish for deployment
dotnet publish -c Release -o ./publish

# Create migration
dotnet ef migrations add MigrationName

# Update database
dotnet ef database update

# Run tests
dotnet test
```

### Docker Commands

```bash
# Build image
docker build -t image-name:tag -f Dockerfile .

# Run container
docker run -d -p 8080:80 --name container-name image-name:tag

# View containers
docker ps -a

# View logs
docker logs -f container-name

# Stop container
docker stop container-name

# Remove container
docker rm container-name

# Push to registry
docker push registry.azurecr.io/image-name:tag
```

### Azure CLI Commands

```bash
# Login
az login

# Create resource group
az group create --name rg-name --location centralindia

# Create SQL Server
az sql server create --resource-group rg-name --name server-name --admin-user admin --admin-password password

# Create container registry
az acr create --resource-group rg-name --name registryname --sku Basic

# Deploy container
az container create --resource-group rg-name --name container-name --image image-name --ports 80

# View resource costs
az billing usage list

# Clean up
az group delete --name rg-name
```

### Jenkins Commands

```bash
# Start Jenkins
docker run -d -p 8080:8080 -p 50000:50000 -v jenkins_home:/var/jenkins_home jenkins/jenkins:lts

# Get admin password
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword

# Install plugins
docker exec jenkins jenkins-cli install-plugin plugin-name

# Create job
curl -X POST http://localhost:8080/createItem?name=JobName

# Trigger build
curl -X POST http://localhost:8080/job/JobName/build

# Get build status
curl http://localhost:8080/job/JobName/lastBuild/api/json
```

---

## Cost Analysis

**Monthly Cost Breakdown (Azure)**

| Service | Tier | Estimated Cost |
|---------|------|-----------------|
| Container Instances (Backend) | 1 CPU, 1GB RAM | $12 |
| Container Instances (Frontend) | 1 CPU, 1GB RAM | $5 |
| SQL Database | Serverless, Basic | $5 |
| Container Registry | Basic | $3 |
| **Total** | | **$25/month** |

**7-Month Projection**: $175 (within $180 budget)

---

## Troubleshooting

### Jenkins Issues

**Problem**: Azure CLI not found
```bash
# Solution: Install in Jenkins container
docker exec jenkins bash -c "curl -sL https://aka.ms/InstallAzureCLIDeb | bash"
```

**Problem**: Docker socket permission denied
```bash
# Solution: Run Jenkins as root
docker run --user root ...
```

**Problem**: Credentials not found
```bash
# Solution: Verify credentials in Jenkins UI
# Manage Jenkins → Manage Credentials → System → Global credentials
```

### Backend Issues

**Problem**: Database connection failed
```bash
# Solution: Verify connection string and firewall rules
az sql server firewall-rule create --resource-group rg-name --server server-name --name AllowAll --start-ip-address 0.0.0.0 --end-ip-address 255.255.255.255
```

**Problem**: CORS errors
```bash
# Solution: Enable CORS in Program.cs
builder.Services.AddCors(options => options.AddPolicy("AllowAll", ...))
```

### Frontend Issues

**Problem**: Cannot connect to API
```bash
# Solution: Update API_URL in environment variables
# Check registration.service.ts baseUrl
```

**Problem**: Build fails
```bash
# Solution: Clear node_modules and reinstall
rm -rf node_modules
npm install
npm run build
```

### Docker Issues

**Problem**: Container exits immediately
```bash
# Solution: Check logs
docker logs container-name

# Rebuild without cache
docker build --no-cache -t image-name .
```

**Problem**: Port already in use
```bash
# Solution: Use different port
docker run -d -p 8081:80 ...
```

---

## Security Best Practices

1. **Secrets Management**
   - Use Azure Key Vault for sensitive data
   - Never commit secrets to source control
   - Use Jenkins credentials for CI/CD

2. **Database Security**
   - Enable encryption at rest and in transit
   - Use strong passwords
   - Restrict firewall rules

3. **Container Registry**
   - Enable image scanning
   - Use private registries
   - Implement image signing

4. **API Security**
   - Implement authentication/authorization
   - Use HTTPS
   - Add rate limiting
   - Validate input

5. **Network Security**
   - Use virtual networks
   - Enable WAF
   - Monitor for threats

---

## Performance Optimization

1. **Frontend**
   - Enable lazy loading
   - Minimize bundle size
   - Use CDN for static content

2. **Backend**
   - Implement caching
   - Use connection pooling
   - Add indexes to database

3. **Database**
   - Regular backups
   - Monitor query performance
   - Archive old data

4. **Containers**
   - Optimize image sizes
   - Use multi-stage builds
   - Monitor resource usage

---

## Monitoring and Logging

**Azure Monitor**
```bash
# View container metrics
az monitor metrics list --resource /subscriptions/.../registration-api-prod

# View container logs
az container logs --resource-group rg-name --name container-name
```

**Jenkins Monitoring**
- Monitor at: http://localhost:8080/computer/
- Build history: http://localhost:8080/job/RegistrationApp-Deploy/

**Application Insights** (Optional)
```bash
# Enable Application Insights
az monitor app-insights component create --app-name app-insights-name --location centralindia --resource-group rg-name
```

---

## Maintenance Schedule

- **Daily**: Monitor container health and API response times
- **Weekly**: Review logs and update dependencies
- **Monthly**: Database maintenance and backup verification
- **Quarterly**: Security audit and penetration testing
- **Annually**: Infrastructure review and cost optimization

---

## Contact & Support

- **Repository**: https://github.com/BrooksCoder/RegistrationApp
- **Azure Portal**: https://portal.azure.com
- **Jenkins**: http://localhost:8080
- **Documentation**: See PROJECT_DOCUMENTATION.md

---

## License

MIT License - Open source project

---

**Last Updated**: February 4, 2026
**Version**: 1.0
**Status**: ✅ Production Deployed
