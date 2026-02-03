# Azure DevOps Service Connection Setup Guide

## What You're Seeing

You're in Azure DevOps setting up a service connection to authenticate and deploy to Azure resources. Here's exactly what to select for your RegistrationApp:

---

## Configuration: Step-by-Step

### **1. Identity Type**
```
SELECT: App registration (automatic) ✅ RECOMMENDED
```
**Why?** This automatically creates an Azure Entra ID app registration for you. Azure DevOps handles everything.

**Alternative (Not recommended for beginners):**
- Managed Identity: More complex, requires manual setup in Azure
- User-assigned managed identity: Advanced scenario

---

### **2. Credential**
```
SELECT: Workload identity federation ✅ RECOMMENDED
```
**Why?** 
- More secure than password-based auth
- No secrets to manage
- Best practice for modern deployments

**Alternative (Legacy):**
- Service principal with secret: Uses passwords, less secure

---

### **3. Scope Level**
```
SELECT: Subscription ✅
```
**Why?** Gives your pipeline access to deploy to any resource in your Azure subscription.

**Alternatives:**
- Management Group: If managing multiple subscriptions
- Machine Learning Workspace: Only if deploying ML models

**For your RegistrationApp:** Keep it at **Subscription** level.

---

### **4. Subscription Selection**
```
Select your Azure subscription from the dropdown
↓
Example: "Pay-As-You-Go" or "Free Trial"
```
**What to do:**
1. Click the **Subscription** dropdown
2. Select your subscription (where you created the resources)
3. Click **Authorize** if prompted

**If subscription doesn't appear:**
```powershell
# Login to Azure in terminal to refresh
az login

# Set correct subscription
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Verify
az account show
```

Then refresh the DevOps page.

---

### **5. Resource Group** (Optional but Recommended)
```
SELECT: rg-registration-app ✅
```
**Why?** Limits the service connection to only access your specific resource group for security.

**How:**
1. Check the **Specify resource group only** checkbox (if available)
2. Select from dropdown: `rg-registration-app`

**If you want full subscription access:**
- Leave this blank

---

### **6. Service Connection Name**
```
ENTER: RegistrationApp-Azure
```
**This is the name you'll reference in your pipeline (azure-pipelines.yml):**

```yaml
# In your azure-pipelines.yml
variables:
  azureSubscription: 'RegistrationApp-Azure'  # ← Must match this name
```

**Example names:**
- `RegistrationApp-Azure`
- `RegistrationApp-Production`
- `Azure-Connection-Prod`

---

### **7. Service Management Reference** (Optional)
```
LEAVE BLANK (unless your org requires it)
```
**What it is:** Reference for external ticketing/ITSM systems.

**Leave empty unless:** Your IT organization says you need it.

---

### **8. Description** (Optional)
```
ENTER: Service connection for RegistrationApp CI/CD pipeline deployment
```

**Examples:**
- "Deploys backend to App Service"
- "CI/CD for RegistrationApp Azure resources"
- "Used by azure-pipelines.yml for automated deployment"

---

### **9. Security: Grant Access Permission**
```
CHECK THIS BOX ✅
```

**Why?** Allows all pipelines in your project to use this service connection.

**If unchecked:** You'd manually authorize each pipeline (not recommended for first-time setup).

---

## Complete Configuration Summary

```
┌─────────────────────────────────────────────┐
│ Azure Resource Manager - New Connection     │
├─────────────────────────────────────────────┤
│                                             │
│ Identity type:                              │
│ ☑ App registration (automatic)              │
│                                             │
│ Credential:                                 │
│ ☑ Workload identity federation              │
│                                             │
│ Scope level:                                │
│ ☑ Subscription                              │
│                                             │
│ Subscription: [Pay-As-You-Go]              │
│                                             │
│ Resource group:                             │
│ ☑ Specify: rg-registration-app              │
│                                             │
│ Service Connection Name:                    │
│ RegistrationApp-Azure                       │
│                                             │
│ Service Management Reference:               │
│ (empty)                                     │
│                                             │
│ Description:                                │
│ Service connection for RegistrationApp...   │
│                                             │
│ Security:                                   │
│ ☑ Grant access permission to all pipelines  │
│                                             │
│              [SAVE]                         │
└─────────────────────────────────────────────┘
```

---

## After Clicking Save

You'll see:
```
✅ Service connection 'RegistrationApp-Azure' created successfully
```

---

## Next Step: Create Second Service Connection (Docker Registry)

Once the Azure Resource Manager connection is saved, repeat the process for Docker Registry:

### **New Service Connection: Docker Registry**

```
Connection type: Docker Registry

Docker Registry:
☑ Azure Container Registry

Registry name: registrationappacr
(From your Azure resources)

Scope level: Subscription

Service Connection Name:
RegistrationApp-ACR

Security:
☑ Grant access permission to all pipelines
```

---

## Testing the Connection

After saving, you can test it:

```powershell
# In Azure DevOps terminal/pipeline
az group show --resource-group rg-registration-app

# Should return your resource group details
```

---

## Common Issues

### ❌ "Subscription not found"
```
Fix: 
1. az login (in PowerShell)
2. az account set --subscription "YOUR_SUB_ID"
3. Refresh DevOps page
```

### ❌ "Not authorized to perform action"
```
Fix: Ensure your Azure account has:
- Contributor role on the subscription
- Or Owner role on the resource group
```

### ❌ "Resource group dropdown empty"
```
Fix:
1. Leave resource group blank (don't specify)
2. Or manually type: rg-registration-app
```

---

## In Your Pipeline (azure-pipelines.yml)

Once created, reference it like this:

```yaml
trigger:
  - main

variables:
  azureSubscription: 'RegistrationApp-Azure'  # ← Your service connection name
  resourceGroupName: 'rg-registration-app'
  appServiceName: 'registration-api-2807'

stages:
  - stage: Deploy
    jobs:
      - job: DeployBackend
        pool:
          vmImage: 'ubuntu-latest'
        steps:
          - task: AzureCLI@2
            inputs:
              azureSubscription: $(azureSubscription)
              scriptType: 'pscore'
              scriptLocation: 'inlineScript'
              inlineScript: |
                az app service show --resource-group $(resourceGroupName) --name $(appServiceName)
```

---

## Security Best Practices

✅ **Do:**
- Limit scope to Resource Group only
- Use Workload Identity Federation
- Enable "Grant access to all pipelines" (easier management)
- Name connections clearly (RegistrationApp-Azure)

❌ **Don't:**
- Use Service Principal with Secret (outdated)
- Grant full subscription access unless necessary
- Share service connections between projects

---

## Summary

**Quick Checklist:**

- [ ] **Identity type:** App registration (automatic) ✅
- [ ] **Credential:** Workload identity federation ✅
- [ ] **Scope level:** Subscription ✅
- [ ] **Resource group:** rg-registration-app ✅
- [ ] **Service Connection Name:** RegistrationApp-Azure ✅
- [ ] **Description:** Added ✅
- [ ] **Grant access to all pipelines:** Checked ✅
- [ ] **Click Save** ✅

**Then create a second connection for Docker Registry with same approach.**

Done! Now you're ready to create your CI/CD pipeline. 🚀
