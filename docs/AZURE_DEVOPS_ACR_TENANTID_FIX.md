# Azure Container Registry Connection - TenantId Error Fix

## Error Message
```
The TenantId must not be an empty guid.
```

## What's Happening

Azure DevOps is trying to auto-fill your ACR details but it's missing the Azure Tenant ID. This usually means:
1. You didn't select an Azure subscription in the form
2. The subscription dropdown is still showing "Loading Registries"
3. You skipped the subscription selection step

---

## Solution: Step-By-Step Fix

### **Step 1: Go Back and Select Subscription First**

In the form, look for:
```
Subscription: [Loading Registries] ← This is the problem
```

**Do this:**
1. Wait for "Loading Registries" to finish loading (30 seconds)
2. Click on the **Subscription** dropdown
3. Select your Azure subscription from the list
4. **WAIT** for the registries to load

---

### **Step 2: Wait for Registries to Load**

After selecting subscription, you should see:
```
Subscription: Pay-As-You-Go ✅

Azure Container Registry:
[Loading registries...]  ← Wait for this

After 30 seconds:
Azure Container Registry:
☑ registrationappacr  ← Select this
```

**Do NOT proceed until you see your registries loaded.**

---

### **Step 3: Select Your Registry**

Once registries load, select:
```
☑ registrationappacr
```

---

### **Step 4: Continue with Service Connection Details**

```
Service Connection Name: RegistrationApp-ACR
Description: Docker registry for RegistrationApp
☑ Grant access to all pipelines
```

---

### **Step 5: Click Save (Not Verify Yet)**

Click **[SAVE]** button.

---

## If You Still Get The Error

### **Workaround A: Manually Create Connection**

If the Azure UI isn't loading properly:

```powershell
# Get your Tenant ID
$tenantId = az account show --query tenantId -o tsv
Write-Host "Tenant ID: $tenantId"

# Get your subscription ID
$subscriptionId = az account show --query id -o tsv
Write-Host "Subscription ID: $subscriptionId"

# Get ACR details
az acr show --resource-group rg-registration-app --name registrationappacr --query loginServer -o tsv
# Result: registrationappacr.azurecr.io
```

Then in Azure DevOps:
1. Go to **Service connections**
2. Try creating connection again with this info
3. Or use the **Create using an existing service principal** option

---

### **Workaround B: Use Different Connection Type**

Try this alternative:

1. **New Service Connection** → **Docker Registry**
2. **Registry Type:** `Others` (instead of Azure Container Registry)
3. Fill in manually:
   ```
   Docker Registry: registrationappacr.azurecr.io
   
   Username: 
   (Get from: az acr credential show --name registrationappacr --query username -o tsv)
   
   Password:
   (Get from: az acr credential show --name registrationappacr --query "passwords[0].value" -o tsv)
   
   Email: your@email.com (optional)
   ```

**To get credentials:**
```powershell
# Get ACR username
az acr credential show --resource-group rg-registration-app --name registrationappacr --query username -o tsv
# Result: 2133adityaraj

# Get ACR password
az acr credential show --resource-group rg-registration-app --name registrationappacr --query "passwords[0].value" -o tsv
# Result: YOUR_PASSWORD_HERE
```

---

### **Workaround C: Use Authentication Instead of Service Connection**

Some teams prefer using the **managed identity** that's auto-created:

1. When creating connection, select:
   ```
   Authentication Type: Managed Identity
   ```
   (Instead of Service connection)

2. This uses the built-in Azure DevOps identity

---

## Best Solution: Clear and Retry

### **Step 1: Delete the Failed Connection**

```
Azure DevOps → Project Settings → Service connections
Find: RegistrationApp-ACR (might show as failed)
Click "..." → Delete
```

### **Step 2: Start Fresh**

1. Click **+ New service connection**
2. Select **Docker Registry**
3. Select **Azure Container Registry** (NOT "Others")
4. **IMPORTANT:** In the Subscription dropdown, select your subscription
5. **WAIT** 30 seconds for registries to load
6. Select **registrationappacr** from the list
7. Fill in service connection name: **RegistrationApp-ACR**
8. Check "Grant access to all pipelines"
9. Click **SAVE**

---

## Common Causes

| Issue | Cause | Fix |
|-------|-------|-----|
| TenantId empty | Subscription not selected | Select subscription from dropdown |
| Loading Registries stuck | Network issue | Refresh page, try again |
| Registries dropdown empty | Wrong subscription | Select correct subscription |
| "No access" error | Account permissions | Need Contributor role on ACR |

---

## Verify Your ACR Exists

Before trying again, confirm your ACR is in Azure:

```powershell
# List all ACRs in your resource group
az acr list --resource-group rg-registration-app

# Expected output:
# [
#   {
#     "name": "registrationappacr",
#     "resourceGroup": "rg-registration-app",
#     "loginServer": "registrationappacr.azurecr.io",
#     ...
#   }
# ]
```

If empty, your ACR wasn't created. Run:
```powershell
# Create ACR if missing
az acr create `
  --resource-group rg-registration-app `
  --name registrationappacr `
  --sku Basic
```

---

## Full Manual Connection Creation

If UI keeps failing, create via CLI:

```powershell
# This creates the service connection via REST API

$projectId = "YOUR_PROJECT_ID"  # Get from URL: dev.azure.com/ORG/PROJECT_ID
$orgName = "2133adityaraj"      # Your Azure DevOps org
$pat = "YOUR_PAT_TOKEN"         # Generate from User Settings

# Get ACR details
$acrName = "registrationappacr"
$subscriptionId = az account show --query id -o tsv
$tenantId = az account show --query tenantId -o tsv

# Create connection payload
$connectionPayload = @{
    name = "RegistrationApp-ACR"
    type = "dockerregistry"
    url = "https://registrationappacr.azurecr.io"
    authentication = @{
        scheme = "UsernamePassword"
        parameters = @{
            username = "2133adityaraj"
            password = "YOUR_ACR_PASSWORD"
            email = "your@email.com"
        }
    }
    isShared = $true
    description = "Docker registry for RegistrationApp"
} | ConvertTo-Json

# Create service connection
$header = @{Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat"))}
$uri = "https://dev.azure.com/$orgName/$projectId/_apis/serviceendpoint/endpoints?api-version=7.1-preview.1"

Invoke-RestMethod -Uri $uri -Method Post -ContentType "application/json" -Headers $header -Body $connectionPayload
```

---

## Quick Checklist When Retrying

- [ ] Delete failed connection first
- [ ] New connection → Docker Registry
- [ ] Select **Azure Container Registry** ✅
- [ ] **SELECT SUBSCRIPTION** from dropdown ✅
- [ ] **WAIT** for registries to load ✅
- [ ] Select **registrationappacr** ✅
- [ ] Service Connection Name: **RegistrationApp-ACR** ✅
- [ ] Description: **Docker registry for RegistrationApp** ✅
- [ ] Check "Grant access to all pipelines" ✅
- [ ] Click **SAVE** ✅

---

## Support

If still failing:

1. Check ACR exists:
   ```powershell
   az acr show --resource-group rg-registration-app --name registrationappacr
   ```

2. Check your permissions:
   ```powershell
   az role assignment list --scope /subscriptions/YOUR_SUB --query "[].{name:principalName,role:roleDefinitionName}"
   ```

3. Try the "Others" workaround with manual credentials

4. Contact Azure DevOps support if DNS/network issue
