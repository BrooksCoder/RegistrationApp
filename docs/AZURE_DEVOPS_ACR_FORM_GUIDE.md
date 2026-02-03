# Azure Container Registry Connection - Complete Form Guide

## What Changed

When you select **Azure Container Registry**, the form simplifies. You see fewer fields because Azure DevOps auto-detects your ACR settings.

---

## Form Fields Explained

### **1. Registry Type**
```
☑ Azure Container Registry ✅ (Already selected)
```
This is locked in, you're good.

---

### **2. Authentication Type** (NEW FIELD)
```
SELECT: Service connection ✅
```

**Why?** You want to use a pre-configured service connection (easier, more secure).

**Alternative (not recommended):**
- Managed Identity: For advanced scenarios
- Service Principal: Older method

**For first-time setup:** Keep it on **Service connection**.

---

### **3. Registry Connection** (Auto-populated)
```
If using "Service connection" authentication:
The form will show a dropdown to SELECT YOUR ACR

Or it might ask:
- Azure subscription: [Your subscription]
- Azure container registry: [registrationappacr]
```

**How to fill:**
1. **Azure subscription:** Select from dropdown (same as before)
2. **Azure container registry:** Select `registrationappacr` from dropdown

**If dropdowns don't appear:**
- The system will auto-detect from your Azure subscription
- Just select your subscription first

---

### **4. Service Connection Details**

#### **Service Connection Name**
```
ENTER: RegistrationApp-ACR
```

**Must match in pipeline:**
```yaml
# azure-pipelines.yml
dockerRegistryServiceConnection: 'RegistrationApp-ACR'
```

**Format tips:**
- Use clear, descriptive names
- No spaces (use hyphens: RegistrationApp-ACR)
- Same name for consistency across org

---

### **5. Description** (Optional)
```
ENTER: Docker registry for RegistrationApp container images
```

**Examples:**
- "ACR connection for CI/CD pipeline"
- "Stores and manages Docker images"
- "Azure Container Registry - RegistrationApp"

---

### **6. Security: Grant Access Permission**
```
☑ CHECK THIS BOX ✅
```

**What it does:**
- Allows all pipelines in your project to use this connection
- Recommended for team/shared projects

**If unchecked:**
- Each pipeline needs manual authorization
- More secure but more work

---

## Complete Form (What You'll See)

```
┌──────────────────────────────────────────────┐
│ New Azure Container Registry Connection      │
├──────────────────────────────────────────────┤
│                                              │
│ Registry Type:                               │
│ ☑ Azure Container Registry                   │
│                                              │
│ Authentication Type:                         │
│ ☑ Service connection                         │
│                                              │
│ Azure Subscription:                          │
│ [Pay-As-You-Go]            (Dropdown)        │
│                                              │
│ Azure Container Registry:                    │
│ [registrationappacr]       (Dropdown)        │
│                                              │
│ ─────────────────────────────────────────── │
│ Service Connection Details:                  │
│                                              │
│ Service Connection Name:                     │
│ RegistrationApp-ACR                          │
│                                              │
│ Description:                                 │
│ Docker registry for RegistrationApp...       │
│                                              │
│ ─────────────────────────────────────────── │
│ Security:                                    │
│ ☑ Grant access permission to all pipelines   │
│                                              │
│              [VERIFY]  [SAVE]                │
└──────────────────────────────────────────────┘
```

---

## Step-By-Step: Fill It Out

**Step 1:** Registry Type is already set to **Azure Container Registry** ✅

**Step 2:** For **Authentication Type**, select:
```
☑ Service connection
```

**Step 3:** From the dropdowns, select:
```
Azure Subscription: [Your subscription name]
Azure Container Registry: registrationappacr
```

**Step 4:** For **Service Connection Name**, enter:
```
RegistrationApp-ACR
```

**Step 5:** For **Description**, enter:
```
Docker registry for RegistrationApp container images
```

**Step 6:** Check the box:
```
☑ Grant access permission to all pipelines
```

**Step 7:** Click **[VERIFY]** to test the connection

**Step 8:** If successful, click **[SAVE]**

---

## What "Verify" Does

When you click **Verify**, Azure DevOps will:

```
1. Connect to your Azure subscription
2. Access the container registry: registrationappacr
3. Check if it can pull/push images
4. Return: ✅ Connection successful
   or ❌ Connection failed (with error)
```

**If verification fails:**
- Check Azure subscription is correct
- Verify registrationappacr exists in that subscription
- Ensure your account has permissions

---

## Important: The Difference

### **OLD WAY** (Docker Hub or Others)
```
Registry type: Docker Hub
↓
Docker ID: your.username
↓
Docker Password: your.password
↓
Email: optional
```
(Not what you're doing)

### **NEW WAY** (Azure Container Registry)
```
Registry type: Azure Container Registry
↓
Authentication: Service connection
↓
Azure subscription: [Auto-selected]
↓
Registry: registrationappacr [Auto-detected]
↓
Service Connection Name: RegistrationApp-ACR
```
(This is what you're doing - BETTER!)

---

## After You Save

You'll see:
```
✅ Service connection 'RegistrationApp-ACR' created successfully
```

---

## Now You Have 2 Service Connections

### Connection #1: RegistrationApp-Azure
- Type: Azure Resource Manager
- Purpose: Deploy to App Service, manage Azure resources
- Used by: Azure CLI tasks in pipeline

### Connection #2: RegistrationApp-ACR
- Type: Azure Container Registry
- Purpose: Push/pull Docker images
- Used by: Docker@2 tasks in pipeline

---

## In Your Pipeline (azure-pipelines.yml)

```yaml
trigger:
  - main

variables:
  azureSubscription: 'RegistrationApp-Azure'  # Connection #1
  dockerRegistryServiceConnection: 'RegistrationApp-ACR'  # Connection #2
  containerRegistry: 'registrationappacr.azurecr.io'
  imageRepository: 'registration-api'
  imageTag: '$(Build.BuildId)'

stages:
  - stage: Build
    jobs:
      - job: BuildAndPushDocker
        pool:
          vmImage: 'ubuntu-latest'
        steps:
          # Use RegistrationApp-ACR to push Docker image
          - task: Docker@2
            inputs:
              command: 'build'
              repository: '$(imageRepository)'
              dockerfile: 'backend/Dockerfile'
              containerRegistry: '$(dockerRegistryServiceConnection)'  # ← Uses ACR connection
              tags: |
                $(imageTag)
                latest

  - stage: Deploy
    dependsOn: Build
    jobs:
      - job: DeployToAzure
        pool:
          vmImage: 'ubuntu-latest'
        steps:
          # Use RegistrationApp-Azure to deploy
          - task: AzureCLI@2
            inputs:
              azureSubscription: '$(azureSubscription)'  # ← Uses Azure connection
              scriptType: 'pscore'
              scriptLocation: 'inlineScript'
              inlineScript: |
                # Deploy commands here
```

---

## Quick Checklist

- [ ] **Registry Type:** Azure Container Registry ✅
- [ ] **Authentication Type:** Service connection ✅
- [ ] **Azure Subscription:** Selected from dropdown ✅
- [ ] **Azure Container Registry:** registrationappacr ✅
- [ ] **Service Connection Name:** RegistrationApp-ACR ✅
- [ ] **Description:** Added (optional) ✅
- [ ] **Grant access to all pipelines:** Checked ✅
- [ ] **Click Verify:** Test connection ✅
- [ ] **Click Save:** Create connection ✅

---

## Troubleshooting

### ❌ "Azure Container Registry dropdown is empty"
```
Fix:
1. Verify you selected the correct Azure subscription first
2. Verify registrationappacr exists in that subscription:
   az acr list --resource-group rg-registration-app --query "[].name" -o tsv
3. If still empty, refresh the page and try again
```

### ❌ "Verify failed - Connection test failed"
```
Fix:
1. Check your Azure subscription is correct
2. Verify your account has Contributor role on ACR:
   az role assignment list --scope /subscriptions/YOUR_SUB/resourceGroups/rg-registration-app
3. Ensure network connectivity to Azure
```

### ❌ "Service Connection Name already exists"
```
Fix:
Use a different name:
- RegistrationApp-ACR-1
- RegistrationApp-ACR-Prod
- RegistrationApp-Container-Registry
```

---

## Summary

**What you're creating:** A trusted connection between Azure DevOps and your Azure Container Registry so your pipeline can securely push Docker images.

**What you need to fill:**
1. Leave Authentication Type as: **Service connection** ✅
2. Select your **Azure subscription** from dropdown ✅
3. Select **registrationappacr** from registry dropdown ✅
4. Enter Service Connection Name: **RegistrationApp-ACR** ✅
5. Add optional description ✅
6. Check "Grant access to all pipelines" ✅
7. Click **Verify** then **Save** ✅

Done! Ready for CI/CD! 🚀
