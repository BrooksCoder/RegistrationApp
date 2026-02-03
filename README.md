# Registration Application - Full-Stack Web Application

A complete full-stack web application demonstrating a modern architecture with **Angular** frontend, **.NET Core** backend, and **SQL Server** database, deployed to **Microsoft Azure** with **CI/CD pipeline**.

## 📋 Features

- ✅ **Angular 17** - Responsive, modern frontend with TypeScript
- ✅ **.NET Core 8** - Robust RESTful API backend
- ✅ **SQL Server** - Enterprise-grade database
- ✅ **Entity Framework Core** - ORM for database operations
- ✅ **Azure Deployment** - Cloud-hosted infrastructure
- ✅ **Azure DevOps** - Automated CI/CD pipeline
- ✅ **Security** - HTTPS, JWT authentication, CORS, SQL injection prevention
- ✅ **Docker Support** - Containerized deployment
- ✅ **Database Migrations** - EF Core migrations for version control
- ✅ **Logging & Monitoring** - Application Insights integration

## 📁 Project Structure

```
RegistrationApp/
├── frontend/                 # Angular 17 application
│   ├── src/
│   │   ├── app/
│   │   │   ├── app.component.ts
│   │   │   ├── app.component.html
│   │   │   ├── app.component.scss
│   │   │   ├── models/
│   │   │   ├── services/
│   │   │   └── interceptors/
│   │   ├── main.ts
│   │   └── index.html
│   ├── angular.json
│   ├── package.json
│   ├── Dockerfile
│   └── nginx.conf
│
├── backend/                  # .NET Core 8 API
│   ├── Models/
│   │   └── Item.cs
│   ├── Data/
│   │   └── ApplicationDbContext.cs
│   ├── Controllers/
│   │   └── ItemsController.cs
│   ├── Migrations/
│   ├── Program.cs
│   ├── appsettings.json
│   ├── RegistrationApi.csproj
│   └── Dockerfile
│
├── database/                 # Database scripts
│   └── 01_InitialSetup.sql
│
├── docs/                     # Documentation
│   ├── SETUP_AND_DEPLOYMENT.md
│   ├── AZURE_DEVOPS_PIPELINE.md
│   ├── SECURITY_BEST_PRACTICES.md
│   └── QUICK_START.md
│
├── scripts/                  # Deployment scripts
│   ├── setup-azure-infrastructure.sh
│   └── setup-azure-infrastructure.ps1
│
└── docker-compose.yml        # Local development with Docker
```

## 🚀 Quick Start

### Prerequisites
- Node.js 18+ and npm
- .NET 8 SDK
- SQL Server 2019+ or SQL Server Express
- Angular CLI: `npm install -g @angular/cli`

### Local Development

#### 1. Backend Setup
```powershell
cd backend
dotnet restore
dotnet ef database update
dotnet run
# API available at: http://localhost:5000
```

#### 2. Frontend Setup
```powershell
cd frontend
npm install
ng serve
# App available at: http://localhost:4200
```

#### 3. Test the Application
1. Open `http://localhost:4200`
2. Add an item with name and description
3. Verify it appears in the list and is saved to database

### Docker Development
```powershell
docker-compose up
# Frontend: http://localhost
# Backend: http://localhost:5000
# Database: localhost:1433
```

## 📚 Documentation

Complete documentation is provided in the `docs/` folder:

1. **[QUICK_START.md](./docs/QUICK_START.md)** - Get started quickly with prerequisites and commands
2. **[SETUP_AND_DEPLOYMENT.md](./docs/SETUP_AND_DEPLOYMENT.md)** - Comprehensive setup guide and Azure deployment
3. **[AZURE_DEVOPS_PIPELINE.md](./docs/AZURE_DEVOPS_PIPELINE.md)** - CI/CD pipeline configuration and setup
4. **[SECURITY_BEST_PRACTICES.md](./docs/SECURITY_BEST_PRACTICES.md)** - Security implementation guide

## 🏗️ Architecture

### Frontend Architecture
- **Angular 17** with standalone components
- **RxJS** for reactive programming
- **HttpClient** for API communication
- **Reactive Forms** for form handling
- **TypeScript** for type safety
- **SCSS** for styling

### Backend Architecture
- **ASP.NET Core 8** Web API
- **Entity Framework Core 8** for data access
- **Dependency Injection** for loose coupling
- **CORS** enabled for frontend communication
- **Swagger/OpenAPI** for API documentation
- **Entity Framework Migrations** for database versioning

### Database Architecture
- **SQL Server** with relational schema
- **Entity Framework Code-First** approach
- **Stored procedures** for common operations
- **Indexes** for query performance
- **Audit logging** for compliance

## 🔐 Security Features

- ✅ HTTPS/TLS enforced
- ✅ Connection strings stored in Azure Key Vault
- ✅ SQL injection prevention with parameterized queries
- ✅ CORS configured for specific domains
- ✅ Input validation and sanitization
- ✅ JWT authentication ready
- ✅ Rate limiting support
- ✅ CSRF protection
- ✅ Security headers (X-Frame-Options, X-Content-Type-Options, CSP)
- ✅ Secrets management in Azure Key Vault
- ✅ Audit logging enabled

## 🌐 Azure Deployment

### Azure Resources Required
1. **Azure Resource Group** - Container for all resources
2. **Azure SQL Database** - Managed SQL Server database
3. **App Service Plan** - Hosting plan for web apps
4. **App Service (Backend)** - Hosts .NET Core API
5. **Static Web App (Frontend)** - Hosts Angular application
6. **Key Vault** - Manages secrets and connection strings
7. **Application Insights** - Logging and monitoring
8. **Storage Account** - For static content

### Deployment Steps

1. **Create Azure Resources**
   ```powershell
   .\scripts\setup-azure-infrastructure.ps1 `
     -SubscriptionId "your-sub-id" `
     -ResourceGroup "rg-registration-app" `
     -SqlAdminPassword "YourSecurePassword123!@#"
   ```

2. **Deploy Backend**
   ```powershell
   cd backend
   dotnet publish -c Release -o ./publish
   # Deploy publish folder to App Service
   ```

3. **Deploy Frontend**
   ```powershell
   cd frontend
   npm run build
   # Deploy dist folder to Static Web App
   ```

4. **Setup CI/CD Pipeline**
   - See [AZURE_DEVOPS_PIPELINE.md](./docs/AZURE_DEVOPS_PIPELINE.md)

## 🔄 CI/CD Pipeline

The Azure DevOps pipeline provides:
- ✅ Automated builds for frontend and backend
- ✅ Unit testing and code coverage
- ✅ Staging and production deployments
- ✅ Database migrations
- ✅ Email notifications on failures
- ✅ Approval gates for production

Pipeline stages:
1. **Build** - Compile frontend/backend and run tests
2. **Deploy to Staging** - Deploy to staging environment
3. **Deploy to Production** - Deploy to production (with approvals)

## 📊 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/items` | Get all items |
| GET | `/api/items/{id}` | Get item by ID |
| POST | `/api/items` | Create new item |
| PUT | `/api/items/{id}` | Update item |
| DELETE | `/api/items/{id}` | Delete item |
| GET | `/swagger` | API documentation |

## 🧪 Testing

### Frontend Tests
```powershell
cd frontend
npm run test
```

### Backend Tests
```powershell
cd backend
dotnet test
```

## 📈 Monitoring

- **Application Insights** - Track application performance
- **Application Logs** - Monitor logs in Azure
- **Azure SQL Auditing** - Track database operations
- **Application Metrics** - CPU, memory, response times

## 🔧 Database Migrations

Create a new migration:
```powershell
cd backend
dotnet ef migrations add MigrationName
dotnet ef database update
```

Apply migrations in production:
```powershell
dotnet ef database update --configuration Release
```

## 📦 Dependencies

### Frontend
- `@angular/core` - Angular framework
- `@angular/forms` - Form handling
- `@angular/common/http` - HTTP client
- `rxjs` - Reactive programming

### Backend
- `Microsoft.EntityFrameworkCore` - ORM
- `Microsoft.EntityFrameworkCore.SqlServer` - SQL Server provider
- `Swashbuckle.AspNetCore` - Swagger/OpenAPI

## 🛠️ Development Tools

- **Visual Studio Code** - Frontend development
- **Visual Studio 2022** - Backend development
- **SQL Server Management Studio** - Database management
- **Postman** - API testing
- **Azure Data Studio** - Database management (cross-platform)

## 📝 Environment Configuration

### appsettings.json (Backend)
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=RegistrationAppDb;Trusted_Connection=true;"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information"
    }
  }
}
```

### environment.ts (Frontend)
```typescript
export const environment = {
  production: false,
  apiUrl: 'http://localhost:5000/api'
};
```

## 🚨 Troubleshooting

### Common Issues

**CORS Errors**
- Verify backend CORS policy includes frontend URL
- Check backend is running on expected port

**Database Connection Errors**
- Verify SQL Server is running
- Check connection string in appsettings.json
- Verify database name matches

**API Not Found (404)**
- Ensure backend is running
- Check API URL in frontend service
- Verify route configuration

See [QUICK_START.md](./docs/QUICK_START.md) for more troubleshooting tips.

## 📞 Support & Resources

- [Angular Documentation](https://angular.io/docs)
- [ASP.NET Core Documentation](https://docs.microsoft.com/aspnet/core)
- [Entity Framework Core](https://docs.microsoft.com/ef/core)
- [Azure Documentation](https://docs.microsoft.com/azure)
- [Azure DevOps Documentation](https://docs.microsoft.com/azure/devops)
- [Stack Overflow](https://stackoverflow.com) - Tag: `angular`, `asp.net-core`

## 📄 License

This project is provided as-is for educational and commercial purposes.

## 🤝 Contributing

1. Clone the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📞 Contact

For questions or issues, please refer to the documentation or create an issue in your repository.

---

**Last Updated:** February 2, 2026  
**Version:** 1.0.0
