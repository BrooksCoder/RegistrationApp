# Docker Registry Service Connection Setup

## What You're Seeing

You're setting up a connection to push/pull Docker images from Azure Container Registry. Here's what to select:

---

## Configuration: Step-by-Step

### **1. Registry Type**
```
SELECT: Azure Container Registry ✅
```

**Why?** Your Docker images are stored in Azure Container Registry (ACR), created during infrastructure setup.

**Alternatives (not for you):**
- Docker Hub: Public images only
- Others: Private Docker registries
- Docker Registry: Manual URL entry

---

### **2. Docker Registry**
```
The dropdown will show:
☑ Azure Container Registry ✅ (Already selected from step 1)
```

This auto-fills based on your choice above.

---

### **3. Registry Name** (Key Setting)
```
SELECT: registrationappacr
```

**How to find this:**
1. Go to Azure Portal → Search "registrationappacr"
2. Or run in PowerShell:
   ```powershell
   az acr list --resource-group rg-registration-app --query "[].name" -o tsv
   ```

**What you'll see in dropdown:**
- registrationappacr (select this one)

---

### **4. Azure Subscription**
```
SELECT: Your Azure subscription (same as before)
```

**Example:** "Pay-As-You-Go" or "Free Trial"

This is the same subscription where your ACR is located.

---

### **5. Service Connection Name**
```
ENTER: RegistrationApp-ACR
```

**Why?** This is how you'll reference it in your pipeline:

```yaml
# In your azure-pipelines.yml
variables:
  dockerRegistryServiceConnection: 'RegistrationApp-ACR'  # ← This name
```

**Must match:** Connection name exactly as typed here.

---

### **6. Description** (Optional)
```
ENTER: Docker Registry for RegistrationApp container images
```

**Examples:**
- "ACR for pushing backend and frontend images"
- "Container registry for CI/CD pipeline"
- "Stores Docker images for RegistrationApp"

---

### **7. Security: Grant Access Permission**
```
CHECK THIS BOX ✅
```

**Why?** Allows all pipelines in your project to use this ACR connection.

**If unchecked:** You'd manually authorize each pipeline.

---

## Complete Configuration Summary

```
┌──────────────────────────────────────────────┐
│ Docker Registry - New Connection             │
├──────────────────────────────────────────────┤
│                                              │
│ Registry type:                               │
│ ☑ Azure Container Registry                   │
│                                              │
│ Docker Registry:                             │
│ ☑ Azure Container Registry                   │
│                                              │
│ Registry name:                               │
│ [registrationappacr]    (Dropdown)           │
│                                              │
│ Azure subscription:                          │
│ [Pay-As-You-Go]         (Dropdown)           │
│                                              │
│ Service Connection Name:                     │
│ RegistrationApp-ACR                          │
│                                              │
│ Description:                                 │
│ Docker Registry for RegistrationApp...       │
│                                              │
│ Security:                                    │
│ ☑ Grant access permission to all pipelines   │
│                                              │
│              [SAVE]                          │
└──────────────────────────────────────────────┘
```

---

## What NOT to Select

❌ **Don't select Docker Hub** unless your images are on Docker Hub (they're not).

❌ **Don't select Others** unless using a private Docker registry outside of Azure.

❌ **Don't manually enter URL** like `https://index.docker.io/v1/` (that's for Docker Hub).

---

## After Clicking Save

You should see:
```
✅ Service connection 'RegistrationApp-ACR' created successfully
```

---

## Verify It Works

In Azure DevOps Pipeline, you can test:

```yaml
trigger:
  - main

variables:
  dockerRegistryServiceConnection: 'RegistrationApp-ACR'
  containerRegistry: 'registrationappacr.azurecr.io'
  imageRepository: 'registration-api'
  imageTag: '$(Build.BuildId)'

stages:
  - stage: Build
    jobs:
      - job: BuildAndPush
        pool:
          vmImage: 'ubuntu-latest'
        steps:
          - task: Docker@2
            inputs:
              command: 'build'
              repository: '$(imageRepository)'
              dockerfile: 'backend/Dockerfile'
              containerRegistry: '$(dockerRegistryServiceConnection)'
              tags: '$(imageTag)'
```

---

## How It Works

**Pipeline Flow:**

```
1. Code committed to repo
   ↓
2. Pipeline triggered
   ↓
3. Docker image built from backend/Dockerfile
   ↓
4. Image tagged: registrationappacr.azurecr.io/registration-api:123
   ↓
5. Uses RegistrationApp-ACR service connection (credentials)
   ↓
6. Pushed to Azure Container Registry
   ↓
7. App Service pulls image and deploys
```

---

## Now You Have Both Service Connections

After this step, you should have:

✅ **RegistrationApp-Azure**
- For deploying to App Service
- For managing Azure resources
- Scope: rg-registration-app

✅ **RegistrationApp-ACR**
- For pushing Docker images
- For container deployments
- Registry: registrationappacr

---

## Next Steps

1. **Click Save** on this Docker Registry connection
2. Go to **Pipelines** → **Create Pipeline**
3. Select your repository with `azure-pipelines.yml`
4. Update the pipeline YAML with your service connection names
5. Click **Save and run**

---

## Troubleshooting

### ❌ "Registry name not in dropdown"
```
Fix:
1. Verify ACR exists:
   az acr list --resource-group rg-registration-app
2. Ensure you selected correct Azure subscription
3. Refresh the page
```

### ❌ "Access denied to ACR"
```
Fix:
1. Your Azure account needs Contributor role on ACR
2. Check: az role assignment list --scope /subscriptions/YOUR_SUB/resourceGroups/rg-registration-app
```

### ❌ "Connection test failed"
```
Fix:
1. Verify registry name is correct: registrationappacr
2. Ensure Azure subscription is selected
3. Try: az acr show --resource-group rg-registration-app --name registrationappacr
```

---

## Important: Update azure-pipelines.yml

Make sure these variables in your pipeline match your service connection names:

```yaml
variables:
  azureSubscription: 'RegistrationApp-Azure'  # ← From step 1
  containerRegistry: 'registrationappacr.azurecr.io'
  dockerRegistryServiceConnection: 'RegistrationApp-ACR'  # ← From this step
  imageRepository: 'registration-api'
  imageTag: '$(Build.BuildId)'
```

---

## Quick Checklist

- [ ] **Registry type:** Azure Container Registry ✅
- [ ] **Registry name:** registrationappacr ✅
- [ ] **Azure subscription:** Selected ✅
- [ ] **Service Connection Name:** RegistrationApp-ACR ✅
- [ ] **Description:** Added (optional) ✅
- [ ] **Grant access to all pipelines:** Checked ✅
- [ ] **Click Save** ✅

**Result:** You now have both service connections ready for CI/CD! 🎉
