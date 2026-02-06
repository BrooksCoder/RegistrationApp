# Quick Azure SQL Migration Reference

## 🎯 Your Situation
- **Local Database**: ✅ Already has new columns (Status, ImageUrl, UpdatedAt)
- **Azure SQL Database**: ❌ Needs same changes

## 📊 Database Changes Summary

```
Items Table:
├── Id (int) - Primary Key
├── Name (nvarchar(200)) - Required
├── Description (nvarchar(1000)) - Required  
├── CreatedAt (datetime2) - Default: GETUTCDATE()
├── Status (nvarchar(max)) - NEW ✨ Nullable
├── ImageUrl (nvarchar(max)) - NEW ✨ Nullable
└── UpdatedAt (datetime2) - NEW ✨ Nullable
```

## ⚡ Fastest Way to Apply Changes

### 1️⃣ Get Your Azure SQL Details
```
Server Name: <SERVER_NAME>.database.windows.net
Database: RegistrationAppDb
User: sqladmin
Password: [Your password]
```

### 2️⃣ Run Migration Script (2 minutes)

**Copy this SQL and run in Azure Portal → Query Editor:**

```sql
-- Add new columns to Items table
ALTER TABLE [Items] ADD [ImageUrl] nvarchar(max) NULL;
ALTER TABLE [Items] ADD [Status] nvarchar(max) NULL;
ALTER TABLE [Items] ADD [UpdatedAt] datetime2 NULL;
GO
```

**That's it!** ✅

### 3️⃣ Verify (30 seconds)

```sql
SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'Items'
```

Should show 7 columns including Status, ImageUrl, UpdatedAt.

---

## 📁 Files Generated

| File | Purpose |
|------|---------|
| `migration_complete.sql` | Full migration script (in backend folder) |
| `AZURE_SQL_MIGRATION_STEPS.md` | Detailed step-by-step guide |
| `appsettings.json` | Updated with Azure SQL connection string placeholder |

---

## 🔑 Connection Strings

### Local (Current)
```
Server=DESKTOP-KGOHIIV;Database=RegistrationAppDb;Trusted_Connection=true;Encrypt=false;
```

### Azure SQL (For Production)
```
Server=tcp:<SERVER_NAME>.database.windows.net,1433;Initial Catalog=RegistrationAppDb;User ID=sqladmin;Password=<PASSWORD>;Encrypt=True;TrustServerCertificate=False;
```

---

## ✅ Success Checklist

- [ ] Copied migration script from `migration_complete.sql`
- [ ] Ran script in Azure Portal Query Editor (or chose alternative method)
- [ ] Verified 7 columns in Items table
- [ ] Updated `appsettings.json` with Azure SQL connection string
- [ ] Tested backend with `dotnet run`
- [ ] Application connects to Azure SQL ✅

---

## 💡 Why These Changes?

- **Status**: Track item approval workflow (Pending/Approved/Rejected)
- **ImageUrl**: Store URL of uploaded image in Azure Storage
- **UpdatedAt**: Track when item was last modified

These columns enable the new image upload and approval workflow features!

