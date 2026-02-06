# 🚀 IMMEDIATE FIX FOR YOUR ERROR

**Your Error**: `Forbidden - Caller is not authorized`

**Reason**: Your Azure user account doesn't have permission to set secrets in `kv-registrationapp`

**Time to Fix**: 2 minutes

---

## Copy-Paste This (Right Now!)

Open PowerShell and run:

```powershell
# Get your user ID
$userId = az ad signed-in-user show --query id -o tsv

# Grant access to BOTH key vaults
az keyvault set-policy --name "kv-registrationapp" --resource-group "rg-registration-app" --object-id $userId --secret-permissions get list set delete
az keyvault set-policy --name "regsql-kv-2807" --resource-group "rg-registration-app" --object-id $userId --secret-permissions get list set delete

# Wait for permissions to apply
Start-Sleep -Seconds 5

# Now try your command again (should work!)
az keyvault secret set --vault-name kv-registrationapp --name "SqlConnectionString" --value "Server=regsql2807.database.windows.net;Database=RegistrationAppDb;User ID=sqladmin;Password=YourPassword;"
```

---

## Did It Work?

✅ **Success**: If you see secret creation output with ID and timestamp
❌ **Failed**: See "If It Didn't Work" below

---

## If It Didn't Work

Try the admin role instead:

```powershell
$userId = az ad signed-in-user show --query id -o tsv
$subId = "af300fa3-a715-4320-8558-efe8a549457e"

az role assignment create --assignee-object-id $userId --role "Key Vault Administrator" --scope /subscriptions/$subId/resourcegroups/rg-registration-app/providers/microsoft.keyvault/vaults/kv-registrationapp

Start-Sleep -Seconds 10

# Try again
az keyvault secret set --vault-name kv-registrationapp --name "SqlConnectionString" --value "Server=regsql2807.database.windows.net;Database=RegistrationAppDb;User ID=sqladmin;Password=YourPassword;"
```

---

## Still Stuck?

Read: **KEY_VAULT_ACCESS_FIX.md** (full troubleshooting guide)

Or ask the person who owns the Key Vault to grant you access.

---

**Next**: Continue with AZURE_RESOURCE_CREATION_GUIDE.md when fixed! 🚀

