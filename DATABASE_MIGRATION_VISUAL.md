# 📊 Database Migration - Visual Summary

## Current State

```
┌─────────────────────────────────────┐
│   Local SQL Server Database         │
│   (DESKTOP-KGOHIIV)                 │
├─────────────────────────────────────┤
│  Items Table:                       │
│  ✅ Id                              │
│  ✅ Name                            │
│  ✅ Description                     │
│  ✅ CreatedAt                       │
│  ✅ Status (NEW)                    │
│  ✅ ImageUrl (NEW)                  │
│  ✅ UpdatedAt (NEW)                 │
│                                     │
│  Status: MIGRATED ✅                │
└─────────────────────────────────────┘
           ↓↓↓ SYNC NEEDED ↓↓↓
┌─────────────────────────────────────┐
│   Azure SQL Database                │
│   (registrationapp.database.windows │
│    .net)                            │
├─────────────────────────────────────┤
│  Items Table:                       │
│  ✅ Id                              │
│  ✅ Name                            │
│  ✅ Description                     │
│  ✅ CreatedAt                       │
│  ❌ Status (MISSING)                │
│  ❌ ImageUrl (MISSING)              │
│  ❌ UpdatedAt (MISSING)             │
│                                     │
│  Status: NEEDS UPDATE ⏳            │
└─────────────────────────────────────┘
```

---

## 🔄 Migration Flow

```
1. LOCAL DATABASE (Already Done)
   ├─ Migration 1: 20260202165557_InitialCreate
   │  └─ Created Items table with 4 columns
   └─ Migration 2: 20260206052620_AddStatusImageUrlUpdatedAt
      └─ Added Status, ImageUrl, UpdatedAt columns
                    ↓
2. GENERATE SCRIPT
   └─ dotnet ef migrations script (Creates migration_complete.sql)
                    ↓
3. APPLY TO AZURE SQL
   ├─ Option A: Azure Portal Query Editor (Click & Run)
   ├─ Option B: SQL Server Management Studio
   ├─ Option C: Azure Data Studio
   ├─ Option D: PowerShell Script
   └─ Option E: Azure CLI
                    ↓
4. VERIFY IN AZURE SQL
   └─ Run SELECT * FROM INFORMATION_SCHEMA.COLUMNS
      (Should show 7 columns)
                    ↓
5. ✅ COMPLETE
   └─ Both databases now have identical schema
```

---

## 📝 What Gets Executed

### Migration Script Content

```
CREATE TABLE [Items] (
    [Id] int IDENTITY,
    [Name] nvarchar(200) NOT NULL,
    [Description] nvarchar(1000) NOT NULL,
    [CreatedAt] datetime2 DEFAULT (GETUTCDATE())
);

ALTER TABLE [Items] ADD [ImageUrl] nvarchar(max) NULL;
ALTER TABLE [Items] ADD [Status] nvarchar(max) NULL;
ALTER TABLE [Items] ADD [UpdatedAt] datetime2 NULL;
```

---

## 🎯 End Result

After migration, both databases will have:

| Database | Id | Name | Desc | Created | Status | Image | Updated |
|----------|---|------|------|---------|--------|-------|---------|
| Local | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Azure | ✅ | ✅ | ✅ | ✅ | ⏳ | ⏳ | ⏳ |

**After applying script:**

| Database | Id | Name | Desc | Created | Status | Image | Updated |
|----------|---|------|------|---------|--------|-------|---------|
| Local | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Azure | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

---

## 🚀 Next Steps

```
STEP 1: Copy migration script
  ├─ File: backend/migration_complete.sql
  └─ Action: Copy entire contents

STEP 2: Run in Azure SQL
  ├─ Go to: Azure Portal → RegistrationAppDb → Query Editor
  ├─ Paste: The copied SQL script
  └─ Click: Run ▶️

STEP 3: Verify
  ├─ Run: SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Items'
  └─ Check: You see 7 columns including Status, ImageUrl, UpdatedAt

STEP 4: Configure
  ├─ Update: appsettings.json with Azure SQL connection string
  └─ Result: App will use Azure SQL instead of local

STEP 5: Test
  ├─ Run: dotnet run
  └─ Check: Application starts successfully and connects to Azure SQL
```

---

## ❓ Common Questions

**Q: Do I have to do this?**
A: Only if you want to use Azure SQL in production. For local development, local SQL Server works fine.

**Q: Will this delete my data?**
A: No, it only adds columns. Existing data is safe.

**Q: Can I rollback if something goes wrong?**
A: Yes, you can run:
```sql
ALTER TABLE [Items] DROP COLUMN [ImageUrl], [Status], [UpdatedAt];
```

**Q: How long does it take?**
A: Usually less than 1 minute for this small schema change.

**Q: Do I need to restart anything?**
A: No. Just update your connection string in appsettings.json and run the app.

---

## 📚 Resources

- Full Guide: `AZURE_SQL_MIGRATION_STEPS.md`
- Quick Ref: `QUICK_AZURE_SQL_REFERENCE.md`
- Migration Script: `backend/migration_complete.sql`

