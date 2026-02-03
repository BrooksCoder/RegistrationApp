# Quick Start Guide

## Prerequisites Installation

### Windows PowerShell Commands

```powershell
# Install Chocolatey (if not already installed)
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install Node.js
choco install nodejs -y

# Install .NET 8 SDK
choco install dotnet-sdk -y

# Install SQL Server Express (optional)
choco install sql-server-express -y

# Install SQL Server Management Studio
choco install sql-server-management-studio -y

# Install Angular CLI
npm install -g @angular/cli

# Install Azure CLI
choco install azure-cli -y

# Install Git
choco install git -y
```

## Local Development Quick Start

### 1. Clone/Navigate to Project
```powershell
cd c:\Users\Admin\source\repos\RegistrationApp
```

### 2. Start Backend
```powershell
cd backend

# Install Entity Framework tools (first time only)
dotnet tool install --global dotnet-ef

# Create database and apply migrations
dotnet ef database update

# Run the API
dotnet run
# Backend available at: https://localhost:5001 or http://localhost:5000
```

### 3. Start Frontend (in new terminal)
```powershell
cd frontend

# Install dependencies (first time only)
npm install

# Start development server
ng serve
# Frontend available at: http://localhost:4200
```

### 4. Test the Application
1. Open browser: `http://localhost:4200`
2. Fill in "Item Name" and "Description"
3. Click "Add Item"
4. Verify item appears in the list
5. Check browser console for errors (F12)

## Common Commands

### Frontend
```powershell
cd frontend

# Development
npm start              # Start dev server
ng serve             # Same as above
npm run build        # Build for production
npm run test         # Run tests
npm audit            # Check for vulnerabilities
npm install -g @angular/cli  # Update Angular CLI
```

### Backend
```powershell
cd backend

dotnet restore       # Restore dependencies
dotnet build         # Build project
dotnet run          # Run application
dotnet publish      # Publish for deployment
dotnet ef migrations add <name>    # Create migration
dotnet ef database update          # Apply migrations
```

### Database
```powershell
# Connect to SQL Server
sqlcmd -S localhost -U sa -P "Your Password"

# Then execute SQL:
# :r c:\path\to\database\script.sql
```

## Troubleshooting

### Port Already in Use
```powershell
# Find process on port 5000
netstat -ano | findstr :5000

# Kill process (replace PID)
taskkill /PID <PID> /F

# Or change Angular port
ng serve --port 4201
```

### Database Connection Issues
```powershell
# Test SQL Server connection
sqlcmd -S localhost -U sa

# Check connection string in appsettings.json
# Verify SQL Server is running
Get-Service "MSSQL*"
```

### Dependency Conflicts
```powershell
# Clear npm cache
npm cache clean --force

# Delete node_modules and package-lock.json
rm -r node_modules package-lock.json

# Reinstall
npm install
```

## Useful Resources

- [Angular Documentation](https://angular.io/docs)
- [ASP.NET Core Docs](https://docs.microsoft.com/aspnet/core)
- [Entity Framework Core](https://docs.microsoft.com/ef/core)
- [SQL Server Docs](https://docs.microsoft.com/sql)
- [Azure Documentation](https://docs.microsoft.com/azure)

