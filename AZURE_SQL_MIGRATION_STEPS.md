# Azure SQL Database Migration - Step by Step

## What Changed?

Your **local SQL Server database** has been updated with 3 new columns in the `Items` table:

```sql
ALTER TABLE [Items] ADD [ImageUrl] nvarchar(max) NULL;
ALTER TABLE [Items] ADD [Status] nvarchar(max) NULL;
ALTER TABLE [Items] ADD [UpdatedAt] datetime2 NULL;
```

Now you need to apply these **same changes to your Azure SQL Database**.

---

## Option 1: Automatic Migration (Easiest for Testing)

### Step 1: Update Connection String

Edit `backend/appsettings.Development.json`:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=tcp:registrationapp.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourPassword@123;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  }
}
```

**Replace these values:**
- `registrationapp` → Your Azure SQL Server name
- `sqladmin` → Your database user
- `YourPassword@123` → Your database password

### Step 2: Run the Application

```powershell
cd backend
dotnet run
```

✅ The app will automatically apply all migrations on startup (see `Program.cs` lines 90-110)

---

## Option 2: Manual SQL Script (Recommended for Production)

### Step 1: The Migration Script

The script is already generated at:
```
C:\Users\Admin\source\repos\RegistrationApp\backend\migration_complete.sql
```

**What it does:**
1. Creates Items table with 4 columns
2. Adds 3 new columns (Status, ImageUrl, UpdatedAt)
3. Records migration history in `__EFMigrationsHistory`

### Step 2: Execute in Azure SQL Database

Choose ONE of these methods:

#### **Method A: Azure Portal (Easiest)**

1. Go to **Azure Portal** → **SQL Databases** → **RegistrationAppDb**
2. Click **Query Editor** (left sidebar)
3. Login with your SQL admin credentials
4. Copy-paste the entire content of `migration_complete.sql`
5. Click **Run**

✅ Done! All columns added.

#### **Method B: Azure Data Studio**

```powershell
# Install if needed (already installed on most PCs)
# Open Azure Data Studio
# File → Open File → Select migration_complete.sql
# Connection: <SERVER_NAME>.database.windows.net
# Database: RegistrationAppDb
# Click Execute (or Ctrl+Shift+E)
```

#### **Method C: SQL Server Management Studio (SSMS)**

```powershell
# Open SSMS
# Connect to: <SERVER_NAME>.database.windows.net
# Authentication: SQL Server Authentication
# Login: sqladmin / <password>
# Database: RegistrationAppDb
# Open migration_complete.sql
# Execute (F5)
```

#### **Method D: PowerShell Script**

Save this as `apply-migration.ps1`:

```powershell
$serverName = "registrationapp"  # Your server name
$databaseName = "RegistrationAppDb"
$username = "sqladmin"
$password = "YourPassword@123"

$connectionString = "Server=tcp:$serverName.database.windows.net,1433;Initial Catalog=$databaseName;User ID=$username;Password=$password;Encrypt=True;TrustServerCertificate=False;"
$sqlScript = Get-Content "migration_complete.sql" -Raw

$connection = New-Object System.Data.SqlClient.SqlConnection
$connection.ConnectionString = $connectionString

try {
    $connection.Open()
    $command = $connection.CreateCommand()
    $command.CommandText = $sqlScript
    $command.ExecuteNonQuery()
    Write-Host "✓ Migration applied successfully!"
}
catch {
    Write-Host "✗ Error: $_"
}
finally {
    $connection.Close()
}
```

Run it:
```powershell
.\apply-migration.ps1
```

#### **Method E: Azure CLI**

```powershell
# First, get your Azure SQL connection string from Azure Portal
az sql db query --server registrationapp --database RegistrationAppDb --username sqladmin --password "YourPassword@123" --query-string @migration_complete.sql
```

---

## Step 3: Verify the Migration

After applying the script, verify the columns were added:

### In Azure Portal (Query Editor):
```sql
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Items'
ORDER BY ORDINAL_POSITION;
```

### Expected Output:
| COLUMN_NAME | DATA_TYPE | IS_NULLABLE |
|-------------|-----------|-------------|
| Id | int | NO |
| Name | nvarchar | NO |
| Description | nvarchar | NO |
| CreatedAt | datetime2 | NO |
| ImageUrl | nvarchar | YES |
| Status | nvarchar | YES |
| UpdatedAt | datetime2 | YES |

✅ If all 7 columns appear, migration was successful!

---

## Complete Migration Script

```sql
IF OBJECT_ID(N'[__EFMigrationsHistory]') IS NULL
BEGIN
    CREATE TABLE [__EFMigrationsHistory] (
        [MigrationId] nvarchar(150) NOT NULL,
        [ProductVersion] nvarchar(32) NOT NULL,
        CONSTRAINT [PK___EFMigrationsHistory] PRIMARY KEY ([MigrationId])
    );
END;
GO

BEGIN TRANSACTION;
GO

CREATE TABLE [Items] (
    [Id] int NOT NULL IDENTITY,
    [Name] nvarchar(200) NOT NULL,
    [Description] nvarchar(1000) NOT NULL,
    [CreatedAt] datetime2 NOT NULL DEFAULT (GETUTCDATE()),
    CONSTRAINT [PK_Items] PRIMARY KEY ([Id])
);
GO

INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
VALUES (N'20260202165557_InitialCreate', N'8.0.0');
GO

COMMIT;
GO

BEGIN TRANSACTION;
GO

ALTER TABLE [Items] ADD [ImageUrl] nvarchar(max) NULL;
GO

ALTER TABLE [Items] ADD [Status] nvarchar(max) NULL;
GO

ALTER TABLE [Items] ADD [UpdatedAt] datetime2 NULL;
GO

INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
VALUES (N'20260206052620_AddStatusImageUrlUpdatedAt', N'8.0.0');
GO

COMMIT;
GO
```

---

## Troubleshooting

### ❌ "Login failed for user 'sqladmin'"
- Verify username and password in connection string
- Check that user has database access permissions
- Reset password in Azure Portal if needed

### ❌ "Cannot connect to server"
- Verify server name (format: `<name>.database.windows.net`)
- Check firewall rules: Azure Portal → Firewall and virtual networks
- Allow your IP: Click "Add current client IP address"

### ❌ "Database does not exist"
- Create database in Azure Portal first, OR
- Let Option 1 (automatic) create it

### ❌ "Syntax error in migration script"
- Ensure the entire script was copied (from GO to GO)
- Check for special characters in password that need escaping

---

## After Migration

### Update `appsettings.json` to Use Azure SQL:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=tcp:registrationapp.database.windows.net,1433;Initial Catalog=RegistrationAppDb;User ID=sqladmin;Password=YourPassword@123;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  }
}
```

### Test Connection:

```powershell
cd backend
dotnet run
# Should see: "Application started. Press Ctrl+C to shut down."
```

---

## Summary

| Task | Local DB | Azure SQL |
|------|----------|-----------|
| **Schema Changes** | ✅ Applied via migrations | ⏳ Apply using script/option above |
| **New Columns** | ✅ Status, ImageUrl, UpdatedAt | ⏳ Pending |
| **Data Sync** | N/A | Optional - copy if needed |
| **Next Step** | Run application | Execute migration script |

