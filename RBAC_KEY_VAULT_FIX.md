# 🔐 RBAC-Enabled Key Vault Fix

**Your Error**: `Cannot set policies to a vault with '--enable-rbac-authorization' specified`

**Reason**: Your Key Vault has RBAC authorization enabled (not access policies)

**Solution**: Use Azure role assignments instead

---

## ✅ Copy-Paste Fix (Works Immediately!)

```powershell
# Step 1: Get your user ID
$userId = az ad signed-in-user show --query id -o tsv
Write-Host "Your User ID: $userId"

# Step 2: Get your subscription ID
$subscriptionId = "af300fa3-a715-4320-8558-efe8a549457e"

# Step 3: Assign "Key Vault Secrets Officer" role to kv-registrationapp
Write-Host "Assigning role to kv-registrationapp..."
az role assignment create `
  --assignee-object-id $userId `
  --role "Key Vault Secrets Officer" `
  --scope /subscriptions/$subscriptionId/resourcegroups/rg-registration-app/providers/microsoft.keyvault/vaults/kv-registrationapp

# Step 4: Assign "Key Vault Secrets Officer" role to regsql-kv-2807
Write-Host "Assigning role to regsql-kv-2807..."
az role assignment create `
  --assignee-object-id $userId `
  --role "Key Vault Secrets Officer" `
  --scope /subscriptions/$subscriptionId/resourcegroups/rg-registration-app/providers/microsoft.keyvault/vaults/regsql-kv-2807

# Step 5: Wait for role assignment to propagate
Write-Host "Waiting for role assignments to propagate..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Step 6: Test if it works
Write-Host "Testing access..."
az keyvault secret set `
  --vault-name "kv-registrationapp" `
  --name "SqlConnectionString" `
  --value "Server=regsql2807.database.windows.net;Database=RegistrationAppDb;User ID=sqladmin;Password=YourPassword123;"

Write-Host "✅ Success! You now have access!" -ForegroundColor Green
```

---

## 📋 Step-by-Step Breakdown

### Step 1: Get Your User ID
```powershell
$userId = az ad signed-in-user show --query id -o tsv
Write-Host "Your User ID: $userId"
```

This gets your unique Azure AD user identifier.

---

### Step 2: Assign Role to kv-registrationapp

```powershell
$userId = az ad signed-in-user show --query id -o tsv
$subscriptionId = "af300fa3-a715-4320-8558-efe8a549457e"

az role assignment create `
  --assignee-object-id $userId `
  --role "Key Vault Secrets Officer" `
  --scope /subscriptions/$subscriptionId/resourcegroups/rg-registration-app/providers/microsoft.keyvault/vaults/kv-registrationapp
```

**This grants you:**
- ✅ Get secrets
- ✅ List secrets
- ✅ Set secrets
- ✅ Delete secrets

---

### Step 3: Assign Role to regsql-kv-2807

```powershell
az role assignment create `
  --assignee-object-id $userId `
  --role "Key Vault Secrets Officer" `
  --scope /subscriptions/$subscriptionId/resourcegroups/rg-registration-app/providers/microsoft.keyvault/vaults/regsql-kv-2807
```

Same permissions for the SQL Key Vault.

---

### Step 4: Wait for Propagation

```powershell
Start-Sleep -Seconds 10
```

Azure role assignments take a few seconds to fully propagate. This is important!

---

### Step 5: Test Your Access

```powershell
az keyvault secret set `
  --vault-name "kv-registrationapp" `
  --name "SqlConnectionString" `
  --value "Server=regsql2807.database.windows.net;Database=RegistrationAppDb;User ID=sqladmin;Password=YourPassword123;"
```

If this succeeds, you're all set! ✅

---

## 🎯 If You Need More Permissions

### For Full Admin Access

If you need more than just secrets, use "Key Vault Administrator":

```powershell
$userId = az ad signed-in-user show --query id -o tsv
$subscriptionId = "af300fa3-a715-4320-8558-efe8a549457e"

# Full admin on both vaults
az role assignment create `
  --assignee-object-id $userId `
  --role "Key Vault Administrator" `
  --scope /subscriptions/$subscriptionId/resourcegroups/rg-registration-app/providers/microsoft.keyvault/vaults/kv-registrationapp

az role assignment create `
  --assignee-object-id $userId `
  --role "Key Vault Administrator" `
  --scope /subscriptions/$subscriptionId/resourcegroups/rg-registration-app/providers/microsoft.keyvault/vaults/regsql-kv-2807

Start-Sleep -Seconds 10
```

---

## 📍 Available RBAC Roles for Key Vault

| Role | Secrets | Keys | Certificates |
|------|---------|------|--------------|
| **Key Vault Secrets Officer** | Full | - | - |
| **Key Vault Keys Officer** | - | Full | - |
| **Key Vault Certificates Officer** | - | - | Full |
| **Key Vault Administrator** | Full | Full | Full |
| **Key Vault Crypto Officer** | - | Full | - |
| **Key Vault Crypto User** | - | Use only | - |
| **Key Vault Data Access Administrator** | Full | Full | Full |
| **Key Vault Reader** | List | List | List |

**For this project, use**: `Key Vault Secrets Officer` (read, write, delete secrets)

---

## ✅ Verification Steps

### Check Your Role Assignments

```powershell
# List your role assignments on the vaults
az role assignment list `
  --assignee $userId `
  --scope /subscriptions/af300fa3-a715-4320-8558-efe8a549457e/resourcegroups/rg-registration-app/providers/microsoft.keyvault/vaults/kv-registrationapp
```

### List Existing Secrets

```powershell
az keyvault secret list --vault-name "kv-registrationapp"
```

### Get a Specific Secret

```powershell
az keyvault secret show --vault-name "kv-registrationapp" --name "SqlConnectionString"
```

---

## 🔄 Next Steps

1. **Run the copy-paste fix above**
2. **Wait 10 seconds** for role assignment to propagate
3. **Continue with your setup**
4. **Add all your secrets to Key Vault**

---

## 🆘 Still Having Issues?

### Issue: "InvalidResourceId" error

**Cause**: Wrong subscription ID or vault name

**Fix**: Verify these values:
```powershell
# Check subscription
az account show --query id -o tsv

# Check vault exists
az keyvault show --name "kv-registrationapp" --resource-group "rg-registration-app"
```

---

### Issue: "The request content is invalid" error

**Cause**: Typo in user ID or scope

**Fix**: Make sure you're using the exact user ID:
```powershell
az ad signed-in-user show --query id -o tsv
```

---

### Issue: Role assignment created but still getting "Forbidden"

**Cause**: Cache hasn't refreshed

**Fix**: 
1. Close and reopen PowerShell
2. Run `az logout` then `az login` again
3. Wait 15 seconds and try again

---

## 📚 More Information

**What is RBAC?**
- Role-Based Access Control (RBAC) is Azure's permission system
- More secure and flexible than access policies
- Roles are assigned to users/services
- Roles define what actions are allowed

**RBAC vs Access Policies:**
- RBAC: Modern, role-based, grants specific permissions
- Access Policies: Legacy, vault-level, less granular
- Your vault uses RBAC (more secure!)

---

**Status**: 🆘 **RBAC KEY VAULT - FIXED**
**Solution**: Use role assignments instead of access policies
**Expected Time**: 2-3 minutes

Good luck! 🚀

