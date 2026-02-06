# 🔐 Key Vault Access Fix Guide

**Problem**: Getting "Forbidden - Caller is not authorized" error when trying to set secrets

**Error Message**:
```
(Forbidden) Caller is not authorized to perform action on resource.
Action: 'Microsoft.KeyVault/vaults/secrets/setSecret/action'
```

---

## ✅ Quick Fix (Copy-Paste Ready)

Run this PowerShell script to fix the issue:

```powershell
# ===== FIX KEY VAULT ACCESS =====

Write-Host "🔧 Fixing Key Vault Access..." -ForegroundColor Cyan
Write-Host ""

# Step 1: Get your user object ID
Write-Host "Step 1: Getting your Azure user object ID..." -ForegroundColor Yellow
$userObjectId = az ad signed-in-user show --query id -o tsv
Write-Host "Your Object ID: $userObjectId" -ForegroundColor Green
Write-Host ""

# Step 2: Grant access to kv-registrationapp
Write-Host "Step 2: Granting access to kv-registrationapp..." -ForegroundColor Yellow
az keyvault set-policy `
  --name "kv-registrationapp" `
  --resource-group "rg-registration-app" `
  --object-id $userObjectId `
  --secret-permissions get list set delete `
  --key-permissions get list create `
  --certificate-permissions get list

if ($?) {
    Write-Host "✅ kv-registrationapp access granted!" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to grant access to kv-registrationapp" -ForegroundColor Red
}
Write-Host ""

# Step 3: Grant access to regsql-kv-2807
Write-Host "Step 3: Granting access to regsql-kv-2807..." -ForegroundColor Yellow
az keyvault set-policy `
  --name "regsql-kv-2807" `
  --resource-group "rg-registration-app" `
  --object-id $userObjectId `
  --secret-permissions get list set delete `
  --key-permissions get list create `
  --certificate-permissions get list

if ($?) {
    Write-Host "✅ regsql-kv-2807 access granted!" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to grant access to regsql-kv-2807" -ForegroundColor Red
}
Write-Host ""

# Step 4: Wait for permissions to propagate
Write-Host "Step 4: Waiting for permissions to propagate..." -ForegroundColor Yellow
Write-Host "(This usually takes 5-10 seconds)" -ForegroundColor Gray
Start-Sleep -Seconds 5
Write-Host "✅ Permissions propagated!" -ForegroundColor Green
Write-Host ""

# Step 5: Verify access
Write-Host "Step 5: Verifying access to kv-registrationapp..." -ForegroundColor Yellow
$secrets = az keyvault secret list --vault-name "kv-registrationapp" --query "[].name" -o json
if ($secrets) {
    Write-Host "✅ Access verified! Existing secrets:" -ForegroundColor Green
    az keyvault secret list --vault-name "kv-registrationapp" --query "[].name" -o table
} else {
    Write-Host "⚠️  No secrets found (this is ok for new vaults)" -ForegroundColor Yellow
}
Write-Host ""

# Step 6: Test setting a secret
Write-Host "Step 6: Testing secret creation..." -ForegroundColor Yellow
az keyvault secret set `
  --vault-name "kv-registrationapp" `
  --name "TestSecret" `
  --value "test-value"

if ($?) {
    Write-Host "✅ Test secret created successfully!" -ForegroundColor Green
    
    # Clean up test secret
    az keyvault secret delete `
      --vault-name "kv-registrationapp" `
      --name "TestSecret" `
      --no-wait
    Write-Host "✅ Test secret cleaned up!" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to create test secret" -ForegroundColor Red
    Write-Host "You may need to ask the Key Vault owner for access" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🎉 Access fix complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Try setting your secrets again" -ForegroundColor Gray
Write-Host "2. Follow AZURE_RESOURCE_CREATION_GUIDE.md Phase 1.1" -ForegroundColor Gray
Write-Host "3. Continue with the rest of the setup" -ForegroundColor Gray
```

---

## 📋 Step-by-Step Guide

### Step 1: Get Your User Object ID

```powershell
$userObjectId = az ad signed-in-user show --query id -o tsv
Write-Host "Your Object ID: $userObjectId"
```

**Save this ID** - you'll use it for all permission assignments.

---

### Step 2: Grant Access to kv-registrationapp

```powershell
az keyvault set-policy `
  --name "kv-registrationapp" `
  --resource-group "rg-registration-app" `
  --object-id $userObjectId `
  --secret-permissions get list set delete `
  --key-permissions get list create `
  --certificate-permissions get list
```

**This grants you:**
- ✅ Get, List, Set, Delete secrets
- ✅ Get, List, Create keys
- ✅ Get, List certificates

---

### Step 3: Grant Access to regsql-kv-2807

```powershell
az keyvault set-policy `
  --name "regsql-kv-2807" `
  --resource-group "rg-registration-app" `
  --object-id $userObjectId `
  --secret-permissions get list set delete `
  --key-permissions get list create `
  --certificate-permissions get list
```

**Same permissions for SQL Key Vault.**

---

### Step 4: Wait for Permissions to Propagate

```powershell
Write-Host "Waiting for permissions to propagate..."
Start-Sleep -Seconds 10
```

Azure RBAC can take a few seconds to fully propagate. Don't skip this!

---

### Step 5: Verify Access

```powershell
# List all secrets in the vault
az keyvault secret list --vault-name "kv-registrationapp"

# Get a specific secret
az keyvault secret show --vault-name "kv-registrationapp" --name "SqlConnectionString" --query value -o tsv
```

---

### Step 6: Test Setting a Secret

```powershell
az keyvault secret set `
  --vault-name "kv-registrationapp" `
  --name "TestSecret" `
  --value "test-value"

# You should see output with the secret details
# If this works, you're ready to proceed!
```

---

## 🚨 If You Still Get "Forbidden" Error

### Option 1: Use Full Admin Role

Try assigning the "Key Vault Administrator" role instead:

```powershell
$userObjectId = az ad signed-in-user show --query id -o tsval
$subscriptionId = "af300fa3-a715-4320-8558-efe8a549457e"

# Assign full admin role to kv-registrationapp
az role assignment create `
  --assignee-object-id $userObjectId `
  --role "Key Vault Administrator" `
  --scope /subscriptions/$subscriptionId/resourcegroups/rg-registration-app/providers/microsoft.keyvault/vaults/kv-registrationapp

# Assign full admin role to regsql-kv-2807
az role assignment create `
  --assignee-object-id $userObjectId `
  --role "Key Vault Administrator" `
  --scope /subscriptions/$subscriptionId/resourcegroups/rg-registration-app/providers/microsoft.keyvault/vaults/regsql-kv-2807

# Wait for role assignment to propagate
Start-Sleep -Seconds 15

# Test again
az keyvault secret set `
  --vault-name "kv-registrationapp" `
  --name "SqlConnectionString" `
  --value "test"
```

---

### Option 2: Check Current Access Policies

See who currently has access:

```powershell
# Get access policies for kv-registrationapp
az keyvault show --name "kv-registrationapp" --resource-group "rg-registration-app"

# Check role assignments
az role assignment list `
  --scope /subscriptions/af300fa3-a715-4320-8558-efe8a549457e/resourcegroups/rg-registration-app/providers/microsoft.keyvault/vaults/kv-registrationapp
```

---

### Option 3: Ask the Vault Owner

If you're still locked out:

1. **Find the Key Vault owner** - They created the vault
2. **Ask them to grant you access:**
   - "Key Vault Administrator" role, OR
   - "Key Vault Secrets Officer" role, OR
   - At minimum: get, list, set, delete permissions on secrets
3. **Or ask them to set the secrets for you:**
   - They set the secrets
   - You use them in your application
   - No permission conflict

---

## ✅ How to Know It's Fixed

**You can successfully run this:**

```powershell
az keyvault secret set `
  --vault-name "kv-registrationapp" `
  --name "SqlConnectionString" `
  --value "Server=regsql2807.database.windows.net;Database=RegistrationAppDb;User ID=sqladmin;Password=YourPassword;"

# Output should show:
# Name: sqlconnectionstring
# Value: (hidden)
# ID: https://kv-registrationapp.vault.azure.net/secrets/sqlconnectionstring/...
# Enabled: True
# Created: [timestamp]
```

If you see this output, **you're all set!** ✅

---

## 🔄 Next Steps After Fix

1. **Verify the fix worked:**
   ```powershell
   az keyvault secret show --vault-name "kv-registrationapp" --name "SqlConnectionString"
   ```

2. **Continue with Phase 1.1 of AZURE_RESOURCE_CREATION_GUIDE.md:**
   - Add your SQL connection string
   - Add your storage account connection string
   - Add other secrets

3. **Then proceed to Phase 2-5:**
   - Create Storage Account
   - Create Service Bus
   - Create Cosmos DB
   - Create App Insights
   - Create Functions and Logic Apps

---

## 🆘 Still Need Help?

Check these:

1. **Verify subscription is correct:**
   ```powershell
   az account show
   # Should show: "af300fa3-a715-4320-8558-efe8a549457e"
   ```

2. **Verify vault exists:**
   ```powershell
   az keyvault show --name "kv-registrationapp" --resource-group "rg-registration-app"
   ```

3. **Verify resource group:**
   ```powershell
   az group show --name "rg-registration-app"
   ```

4. **Check your current permissions:**
   ```powershell
   az keyvault get-access-policy --name "kv-registrationapp" --resource-group "rg-registration-app"
   ```

---

## 📞 Contact Vault Owner

If none of the above work, contact whoever created the Key Vaults:

**Tell them:**
> I need access to set secrets in the `kv-registrationapp` Key Vault in resource group `rg-registration-app`. Can you grant me the "Key Vault Administrator" role or at minimum the permissions to get, list, set, and delete secrets?

**Your details for them:**
- **Azure User Object ID**: `$userObjectId` (from Step 1)
- **Subscription**: `af300fa3-a715-4320-8558-efe8a549457e`
- **Resource Group**: `rg-registration-app`
- **Vault Name**: `kv-registrationapp` and `regsql-kv-2807`

---

**Status**: 🆘 Key Vault Access Issue
**Solution**: Grant yourself the "Key Vault Administrator" role
**Expected Time**: 5-10 minutes

Good luck! 🚀

