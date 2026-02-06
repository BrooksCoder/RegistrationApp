# Azure SQL Database Migration Guide

## Summary of Database Changes

Your local SQL Server database now has these schema changes via Entity Framework Core migrations:

### **New Columns Added to `Items` Table:**
1. **Status** (nvarchar(max), nullable) - Item approval status (Pending/Approved/Rejected)
2. **ImageUrl** (nvarchar(max), nullable) - URL to uploaded image in Azure Storage
3. **UpdatedAt** (datetime2, nullable) - Last update timestamp

### **Existing Columns:**
- Id (int, primary key)
- Name (nvarchar(200), required)
- Description (nvarchar(1000), required)
- CreatedAt (datetime2, default: GETUTCDATE())

---

## How to Apply Changes to Azure SQL DB

### **Option 1: Automatic Migration (Development/Testing)**

**Step 1:** Update `appsettings.Development.json` to use Azure SQL

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=tcp:<YOUR_SERVER_NAME>.database.windows.net,1433;Initial Catalog=RegistrationAppDb;User ID=<USERNAME>;Password=<PASSWORD>;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  }
}
```

**Step 2:** Run in development environment
```powershell
cd backend
dotnet run
```

The `Program.cs` automatically applies migrations on startup (with retry logic).

---

### **Option 2: Manual Migration (Production - Recommended)**

**Step 1:** Generate migration script
```powershell
cd C:\Users\Admin\source\repos\RegistrationApp\backend

# Generate SQL script
dotnet ef migrations script -o migration.sql
```

**Step 2:** Review the generated `migration.sql` file

**Step 3:** Execute in Azure SQL Database using one of these methods:

#### **Method A: Azure Portal**
1. Go to Azure Portal → SQL Databases → RegistrationAppDb
2. Click "Query Editor" (or "Data Editor")
3. Login with your admin credentials
4. Copy-paste the SQL script from `migration.sql`
5. Click "Run"

#### **Method B: Azure Data Studio**
```powershell
# Install Azure Data Studio if needed
# Open Azure Data Studio
# Connect to: <SERVER_NAME>.database.windows.net
# Open migration.sql
# Execute
```

#### **Method C: SQLCMD (Command Line)**
```powershell
sqlcmd -S <SERVER_NAME>.database.windows.net -U <USERNAME> -P "<PASSWORD>" -d RegistrationAppDb -i migration.sql
```

#### **Method D: PowerShell**
```powershell
$connectionString = "Server=tcp:<SERVER_NAME>.database.windows.net,1433;Initial Catalog=RegistrationAppDb;User ID=<USERNAME>;Password=<PASSWORD>;Encrypt=True;"
$sqlScript = Get-Content "migration.sql" -Raw

$connection = New-Object System.Data.SqlClient.SqlConnection
$connection.ConnectionString = $connectionString
$connection.Open()

$command = $connection.CreateCommand()
$command.CommandText = $sqlScript
$command.ExecuteNonQuery()

$connection.Close()
```

---

## Migration Script Preview

The EF Core migration creates these T-SQL commands:

```sql
-- Add Status column
ALTER TABLE [Items] ADD [Status] nvarchar(max) NULL;

-- Add ImageUrl column
ALTER TABLE [Items] ADD [ImageUrl] nvarchar(max) NULL;

-- Add UpdatedAt column
ALTER TABLE [Items] ADD [UpdatedAt] datetime2 NULL;
```

---

## Verification Steps

### **After Migration, Verify in Azure Portal:**

1. Go to SQL Database → RegistrationAppDb → Query Editor
2. Run this query:
   ```sql
   SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
   FROM INFORMATION_SCHEMA.COLUMNS
   WHERE TABLE_NAME = 'Items'
   ORDER BY ORDINAL_POSITION;
   ```
3. You should see all 7 columns:
   - Id
   - Name
   - Description
   - Status (NEW)
   - ImageUrl (NEW)
   - CreatedAt
   - UpdatedAt (NEW)

---

## Configuration for Production

### **Update `appsettings.json` for Azure SQL:**

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=tcp:YOUR_SERVER_NAME.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=YOUR_USERNAME;Password=YOUR_PASSWORD;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  }
}
```

### **Or Use Azure Key Vault (Recommended):**

1. Store credentials in Azure Key Vault
2. Use `DefaultAzureCredential` in your app
3. Reference from Key Vault in `appsettings.json`

---

## Troubleshooting

### **Issue: "Cannot connect to Azure SQL"**
- Verify server is accessible: `Test-NetConnection -ComputerName <SERVER>.database.windows.net -Port 1433`
- Check firewall rules: Azure Portal → Firewall and virtual networks
- Allow your IP: Click "Add current client IP address"

### **Issue: "Login failed for user"**
- Verify username and password
- Check if user has database access
- Password may contain special characters - ensure it's properly escaped

### **Issue: "Database does not exist"**
- Create database in Azure Portal first
- Or let migration create it (if user has CREATE DATABASE permissions)

---

## Quick Reference Commands

| Task | Command |
|------|---------|
| Generate migration script | `dotnet ef migrations script -o migration.sql` |
| Apply migrations locally | `dotnet run` (automatic in Program.cs) |
| View pending migrations | `dotnet ef migrations list` |
| Create new migration | `dotnet ef migrations add <MigrationName>` |
| Rollback last migration | `dotnet ef migrations remove` |

---

## Summary

✅ **Local SQL Server**: Already has all changes via EF Core migrations  
✅ **Azure SQL DB**: Needs migration script applied  
✅ **Next Step**: Choose Option 1 (automatic) or Option 2 (manual script)

