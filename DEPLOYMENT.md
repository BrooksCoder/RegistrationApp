# RegistrationApp - Deployment Guide

## 🚀 Current Status

Your full-stack application is **successfully deployed and running** on Azure!

### Live URLs

| Component | URL |
|-----------|-----|
| **Frontend (Angular)** | http://registration-frontend-prod.centralindia.azurecontainer.io/ |
| **Backend API (.NET)** | http://registration-api-prod.centralindia.azurecontainer.io/ |
| **API Endpoints** | http://registration-api-prod.centralindia.azurecontainer.io/api/items |
| **Swagger UI** | http://registration-api-prod.centralindia.azurecontainer.io/swagger/index.html |

## 💰 Cost Breakdown

- **Backend Container**: $15/month (1 CPU, 1GB RAM)
- **Frontend Container**: $5/month (0.5 CPU, 0.5GB RAM)
- **SQL Database**: $5/month (Basic tier, serverless)
- **Total**: $25/month
- **Budget Duration**: 7+ months on your $180 trial credit

## 📋 Manual Deployment Process

Since Azure DevOps free tier doesn't support parallelism, use this manual deployment script:

### Prerequisites
- Docker Desktop installed and running
- Git configured
- Azure CLI installed (or use PowerShell script which handles it)
- Signed in to Azure: `az login`

### Deploy to Azure

```powershell
# Navigate to project directory
cd C:\Users\Admin\source\repos\RegistrationApp

# Run the deployment script
.\deploy.ps1 -Step 4
```

### What the script does:
1. ✅ Deletes old container instances
2. ✅ Builds backend Docker image locally
3. ✅ Builds frontend Docker image locally
4. ✅ Pushes both images to Azure Container Registry
5. ✅ Deploys backend container to Azure Container Instances
6. ✅ Deploys frontend container to Azure Container Instances
7. ✅ Displays final URLs

### Individual Steps (optional)

Deploy only specific components:

```powershell
# Step 1: Create/verify SQL Database
.\deploy.ps1 -Step 1

# Step 2: Configure Firewall
.\deploy.ps1 -Step 2

# Step 3: Build and push Docker images
.\deploy.ps1 -Step 3

# Step 4: Deploy containers
.\deploy.ps1 -Step 4

# All steps (default)
.\deploy.ps1
```

## 🔄 Workflow for Code Changes

1. **Make code changes** in the frontend or backend
2. **Test locally** (optional, but recommended)
3. **Commit and push** to GitHub:
   ```powershell
   git add .
   git commit -m "Your commit message"
   git push origin main
   ```
4. **Redeploy** using the deployment script:
   ```powershell
   .\deploy.ps1 -Step 4
   ```
5. **Access updated application** at the URLs above

## 📁 Project Structure

```
RegistrationApp/
├── backend/                 # .NET Core 8 API
│   ├── Controllers/        # API endpoints
│   ├── Models/             # Data models
│   ├── Data/               # EF Core DbContext
│   ├── Migrations/         # Database migrations
│   ├── Dockerfile          # Backend container config
│   └── Program.cs          # Startup configuration
├── frontend/               # Angular 17 UI
│   ├── src/
│   │   ├── app/           # Angular components
│   │   ├── services/      # API services
│   │   └── models/        # TypeScript interfaces
│   ├── Dockerfile          # Frontend container config
│   └── nginx.conf          # Web server config
├── deploy.ps1              # Deployment script
└── README.md               # Documentation
```

## 🔧 Azure Resources Created

- **Resource Group**: `rg-registration-app`
- **SQL Server**: `regsql2807.database.windows.net`
- **SQL Database**: `RegistrationAppDb`
- **Container Registry**: `registrationappacr.azurecr.io`
- **Backend Container**: `registration-api-prod`
- **Frontend Container**: `registration-frontend-prod`

## 🐛 Troubleshooting

### Application not accessible
```powershell
# Check container status
az container show --resource-group rg-registration-app --name registration-api-prod

# Check container logs
az container logs --resource-group rg-registration-app --name registration-api-prod
```

### Docker build fails
```powershell
# Clean up old images
docker image prune -a

# Rebuild
.\deploy.ps1 -Step 3
```

### Database connection issues
- Verify SQL Server firewall allows Azure services (already configured)
- Check connection string in deploy.ps1
- Ensure database migrations ran successfully

## 📝 API Documentation

### Available Endpoints

**GET** `/api/items` - Get all items
**GET** `/api/items/{id}` - Get item by ID
**POST** `/api/items` - Create new item
**PUT** `/api/items/{id}` - Update item
**DELETE** `/api/items/{id}` - Delete item
**GET** `/health` - Health check

### Example Request

```bash
curl http://registration-api-prod.centralindia.azurecontainer.io/api/items
```

## 🚀 Future Improvements

### To enable CI/CD pipeline:
1. Request parallelism grant: https://aka.ms/azpipelines-parallelism-request (2-3 days)
2. Once approved, the `azure-pipelines-sequential.yml` in the repo is ready to use

### Optional enhancements:
- Add authentication (JWT tokens)
- Add unit tests
- Add integration tests
- Set up monitoring/logging
- Add API rate limiting
- Implement caching strategy

## ✅ Deployment Checklist

- [x] Frontend deployed and accessible
- [x] Backend API deployed and accessible
- [x] SQL Database created and configured
- [x] Docker images built and pushed to ACR
- [x] CORS configured for frontend-backend communication
- [x] Firewall rules configured
- [x] Cost optimized for trial budget
- [x] Manual deployment process documented

## 📞 Support

For issues or questions:
1. Check container logs: `az container logs --resource-group rg-registration-app --name <container-name>`
2. Review error messages in deployment script output
3. Verify all Azure resources are created: `az resource list --resource-group rg-registration-app`

---

**Deployed on**: February 3, 2026
**Last Updated**: February 3, 2026
**Status**: ✅ Production Ready
