# 🔧 Azure SQL Migration - Exact Commands

## Option 1: Azure Portal (Easiest - No Tools Needed)

### Step 1: Open Azure Portal
```
Go to: https://portal.azure.com
Search: "RegistrationAppDb"
Select: Your database
```

### Step 2: Open Query Editor
```
Left Sidebar → Query Editor
Login: sqladmin / <Your Password>
```

### Step 3: Copy & Paste These Commands

```sql
-- ===== ITEMS TABLE WITH NEW COLUMNS =====

-- Create Items table if it doesn't exist
IF OBJECT_ID(N'[Items]') IS NULL
BEGIN
    CREATE TABLE [Items] (
        [Id] int NOT NULL IDENTITY(1,1),
        [Name] nvarchar(200) NOT NULL,
        [Description] nvarchar(1000) NOT NULL,
        [CreatedAt] datetime2 NOT NULL DEFAULT (GETUTCDATE()),
        CONSTRAINT [PK_Items] PRIMARY KEY ([Id])
    );
END;
GO

-- Add Status column (for approval workflow)
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
              WHERE TABLE_NAME = 'Items' AND COLUMN_NAME = 'Status')
BEGIN
    ALTER TABLE [Items] ADD [Status] nvarchar(max) NULL;
END;
GO

-- Add ImageUrl column (for uploaded images)
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
              WHERE TABLE_NAME = 'Items' AND COLUMN_NAME = 'ImageUrl')
BEGIN
    ALTER TABLE [Items] ADD [ImageUrl] nvarchar(max) NULL;
END;
GO

-- Add UpdatedAt column (for audit trail)
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
              WHERE TABLE_NAME = 'Items' AND COLUMN_NAME = 'UpdatedAt')
BEGIN
    ALTER TABLE [Items] ADD [UpdatedAt] datetime2 NULL;
END;
GO

-- ===== VERIFY COLUMNS =====
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Items'
ORDER BY ORDINAL_POSITION;
GO
```

### Step 4: Click Run ▶️

**Expected Output:**
```
(7 rows affected)
```

---

## Option 2: SQL Server Management Studio (SSMS)

### Connection Settings
```
Server:     <SERVER_NAME>.database.windows.net
Port:       1433
Username:   sqladmin
Password:   <Your Password>
Database:   RegistrationAppDb
```

### Paste & Execute Same Script Above

---

## Option 3: PowerShell Script

Create `apply-azure-migration.ps1`:

```powershell
# ============================================
# Azure SQL Database Migration Script
# ============================================

param(
    [string]$ServerName = "registrationapp",
    [string]$DatabaseName = "RegistrationAppDb",
    [string]$Username = "sqladmin",
    [string]$Password
)

if (-not $Password) {
    $Password = Read-Host "Enter SQL password" -AsSecureString
    $Password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))
}

$connectionString = "Server=tcp:$ServerName.database.windows.net,1433;Initial Catalog=$DatabaseName;User ID=$Username;Password=$Password;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

$sqlScript = @"
-- Add Status column
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
              WHERE TABLE_NAME = 'Items' AND COLUMN_NAME = 'Status')
BEGIN
    ALTER TABLE [Items] ADD [Status] nvarchar(max) NULL;
    PRINT 'Added Status column';
END
ELSE
BEGIN
    PRINT 'Status column already exists';
END;
GO

-- Add ImageUrl column
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
              WHERE TABLE_NAME = 'Items' AND COLUMN_NAME = 'ImageUrl')
BEGIN
    ALTER TABLE [Items] ADD [ImageUrl] nvarchar(max) NULL;
    PRINT 'Added ImageUrl column';
END
ELSE
BEGIN
    PRINT 'ImageUrl column already exists';
END;
GO

-- Add UpdatedAt column
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
              WHERE TABLE_NAME = 'Items' AND COLUMN_NAME = 'UpdatedAt')
BEGIN
    ALTER TABLE [Items] ADD [UpdatedAt] datetime2 NULL;
    PRINT 'Added UpdatedAt column';
END
ELSE
BEGIN
    PRINT 'UpdatedAt column already exists';
END;
GO

-- Verify
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Items'
ORDER BY ORDINAL_POSITION;
"@

Write-Host "Connecting to $ServerName/$DatabaseName..." -ForegroundColor Cyan

try {
    $connection = New-Object System.Data.SqlClient.SqlConnection
    $connection.ConnectionString = $connectionString
    $connection.Open()
    
    Write-Host "✓ Connected successfully!" -ForegroundColor Green
    
    $command = $connection.CreateCommand()
    $command.CommandText = $sqlScript
    $command.CommandTimeout = 300
    
    Write-Host "Executing migration script..." -ForegroundColor Yellow
    $command.ExecuteNonQuery() | Out-Null
    
    Write-Host "✓ Migration completed successfully!" -ForegroundColor Green
}
catch {
    Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    if ($connection.State -eq 'Open') {
        $connection.Close()
    }
}
```

### Run It
```powershell
.\apply-azure-migration.ps1 -ServerName "registrationapp" -Username "sqladmin" -Password "YourPassword"
```

---

## Option 4: Azure CLI

```powershell
# Install Azure CLI if needed: https://aka.ms/cli

# Login to Azure
az login

# Create script file
@"
ALTER TABLE [Items] ADD [Status] nvarchar(max) NULL;
ALTER TABLE [Items] ADD [ImageUrl] nvarchar(max) NULL;
ALTER TABLE [Items] ADD [UpdatedAt] datetime2 NULL;
"@ | Out-File -FilePath "migrate.sql"

# Execute
az sql db query --resource-group "your-resource-group" `
                --server "registrationapp" `
                --database "RegistrationAppDb" `
                --username "sqladmin" `
                --password "YourPassword" `
                --query-string @migrate.sql
```

---

## Option 5: Minimal SQL (If Columns Don't Exist)

If you just want to add the columns (skipping the checks):

```sql
ALTER TABLE [Items] ADD [Status] nvarchar(max) NULL;
ALTER TABLE [Items] ADD [ImageUrl] nvarchar(max) NULL;
ALTER TABLE [Items] ADD [UpdatedAt] datetime2 NULL;
GO
```

---

## Verify Success

Run this query in Azure Portal Query Editor:

```sql
SELECT 
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    ORDINAL_POSITION
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Items'
ORDER BY ORDINAL_POSITION;
```

**Should see 7 rows:**
| COLUMN_NAME | DATA_TYPE | IS_NULLABLE | ORDINAL_POSITION |
|-------------|-----------|-------------|------------------|
| Id | int | NO | 1 |
| Name | nvarchar | NO | 2 |
| Description | nvarchar | NO | 3 |
| CreatedAt | datetime2 | NO | 4 |
| Status | nvarchar | YES | 5 |
| ImageUrl | nvarchar | YES | 6 |
| UpdatedAt | datetime2 | YES | 7 |

✅ If you see all 7, migration is complete!

---

## Troubleshooting Commands

### Check if table exists
```sql
SELECT * FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_NAME = 'Items';
```

### Check specific column
```sql
SELECT * FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Items' AND COLUMN_NAME = 'Status';
```

### See all columns in Items
```sql
SP_COLUMNS Items;
```

### Drop column if needed (rollback)
```sql
ALTER TABLE Items DROP COLUMN [Status];
```

### See table definition
```sql
EXEC sp_help Items;
```

---

## Configuration After Migration

Update your `appsettings.json`:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=tcp:registrationapp.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourPassword@123;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  }
}
```

Update your `appsettings.Development.json` to use the same or local connection string.

---

## Test Connection from .NET

In your `Program.cs`, the app already tests the connection and applies migrations:

```csharp
// This runs on startup and applies any pending migrations
var retryCount = 0;
const int maxRetries = 10;

while (retryCount < maxRetries)
{
    try
    {
        using (var scope = app.Services.CreateScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            dbContext.Database.Migrate();
            Console.WriteLine("✓ Database migrations applied successfully");
            break;
        }
    }
    catch (Exception ex)
    {
        // ... retry logic
    }
}
```

So just update the connection string and run `dotnet run` - it will automatically apply any pending migrations!

