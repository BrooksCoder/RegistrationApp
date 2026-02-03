# Update Azure Pipeline Variables

## Current Situation

Your pipeline has **basic variables**, but you need to add **Azure-specific variables** for deployment.

---

## What to Add

Add these variables to your `azure-pipelines.yml` file **after the existing variables section**:

### Current Variables (Keep These)
```yaml
variables:
  buildConfiguration: 'Release'
  nodeVersion: '18.x'
  dotnetVersion: '8.x'
```

### Add These Azure Variables
```yaml
variables:
  buildConfiguration: 'Release'
  nodeVersion: '18.x'
  dotnetVersion: '8.x'
  
  # ===== ADD THESE AZURE VARIABLES =====
  azureSubscription: 'RegistrationApp-Azure'
  containerRegistry: 'registrationappacr.azurecr.io'
  dockerRegistryServiceConnection: 'RegistrationApp-ACR'
  imageRepository: 'registration-api'
  acrName: 'registrationappacr'
  appServiceName: 'registration-api-2807'
  staticWebAppName: 'registration-frontend-2807'
  sqlServerName: 'regsql2807'
  resourceGroupName: 'rg-registration-app'
```

---

## Step-by-Step: Update Your Pipeline

### Step 1: Open `azure-pipelines.yml`

```powershell
# Navigate to your repo
cd c:\Users\Admin\source\repos\RegistrationApp

# Open the file
code azure-pipelines.yml
```

### Step 2: Find the Variables Section

Look for this:
```yaml
variables:
  buildConfiguration: 'Release'
  nodeVersion: '18.x'
  dotnetVersion: '8.x'
```

### Step 3: Replace With This

```yaml
variables:
  buildConfiguration: 'Release'
  nodeVersion: '18.x'
  dotnetVersion: '8.x'
  
  # Azure Resource Names
  azureSubscription: 'RegistrationApp-Azure'
  containerRegistry: 'registrationappacr.azurecr.io'
  dockerRegistryServiceConnection: 'RegistrationApp-ACR'
  imageRepository: 'registration-api'
  acrName: 'registrationappacr'
  appServiceName: 'registration-api-2807'
  staticWebAppName: 'registration-frontend-2807'
  sqlServerName: 'regsql2807'
  resourceGroupName: 'rg-registration-app'
```

### Step 4: Before You Save

**Replace these values with YOUR actual values:**

| Variable | Get From |
|----------|----------|
| `appServiceName` | `az webapp list --resource-group rg-registration-app --query "[0].name" -o tsv` |
| `staticWebAppName` | `az staticwebapp list --resource-group rg-registration-app --query "[0].name" -o tsv` |
| `sqlServerName` | `az sql server list --resource-group rg-registration-app --query "[0].name" -o tsv` |
| `acrName` | `az acr list --resource-group rg-registration-app --query "[0].name" -o tsv` |
| `containerRegistry` | `az acr show --resource-group rg-registration-app --name registrationappacr --query loginServer -o tsv` |

---

## Complete Updated File

Here's your full `azure-pipelines.yml` with the updated variables section:

```yaml
trigger:
  - main
  - develop

pr:
  - main
  - develop

pool:
  vmImage: 'ubuntu-latest'

variables:
  buildConfiguration: 'Release'
  nodeVersion: '18.x'
  dotnetVersion: '8.x'
  
  # Azure Resource Names
  azureSubscription: 'RegistrationApp-Azure'
  containerRegistry: 'registrationappacr.azurecr.io'
  dockerRegistryServiceConnection: 'RegistrationApp-ACR'
  imageRepository: 'registration-api'
  acrName: 'registrationappacr'
  appServiceName: 'registration-api-2807'
  staticWebAppName: 'registration-frontend-2807'
  sqlServerName: 'regsql2807'
  resourceGroupName: 'rg-registration-app'

stages:
  - stage: Build
    displayName: 'Build'
    jobs:
      - job: BuildFrontend
        displayName: 'Build Angular Frontend'
        steps:
          - task: NodeTool@0
            inputs:
              versionSpec: $(nodeVersion)

          - task: Npm@1
            inputs:
              command: 'ci'
              workingDir: '$(Build.SourcesDirectory)/frontend'

          - task: Npm@1
            inputs:
              command: 'custom'
              customCommand: 'run build -- --configuration production'
              workingDir: '$(Build.SourcesDirectory)/frontend'

          - task: PublishBuildArtifacts@1
            inputs:
              pathToPublish: '$(Build.SourcesDirectory)/frontend/dist'
              artifactName: 'frontend'

      - job: BuildBackend
        displayName: 'Build .NET Core Backend'
        steps:
          - task: UseDotNet@2
            inputs:
              version: $(dotnetVersion)

          - task: DotNetCoreCLI@2
            inputs:
              command: 'restore'
              projects: '$(Build.SourcesDirectory)/backend/**/*.csproj'

          - task: DotNetCoreCLI@2
            inputs:
              command: 'build'
              projects: '$(Build.SourcesDirectory)/backend/**/*.csproj'
              arguments: '--configuration $(buildConfiguration) --no-restore'

          - task: DotNetCoreCLI@2
            inputs:
              command: 'publish'
              publishWebProjects: false
              projects: '$(Build.SourcesDirectory)/backend/RegistrationApi.csproj'
              arguments: '--configuration $(buildConfiguration) --output $(Build.ArtifactStagingDirectory)'
              zipAfterPublish: true

          - task: PublishBuildArtifacts@1
            inputs:
              pathToPublish: '$(Build.ArtifactStagingDirectory)'
              artifactName: 'backend'
```

---

## How to Update the File

### Option A: Manual Edit in VS Code

1. Open `azure-pipelines.yml` in VS Code
2. Find the `variables:` section (around line 10)
3. Delete the current variables section
4. Replace with the new one above
5. Save (Ctrl+S)
6. Commit and push

### Option B: Using PowerShell

```powershell
# Get your actual values first
$appServiceName = az webapp list --resource-group rg-registration-app --query "[0].name" -o tsv
$staticWebAppName = az staticwebapp list --resource-group rg-registration-app --query "[0].name" -o tsv
$sqlServerName = az sql server list --resource-group rg-registration-app --query "[0].name" -o tsv
$acrName = az acr list --resource-group rg-registration-app --query "[0].name" -o tsv
$containerRegistry = az acr show --resource-group rg-registration-app --name registrationappacr --query loginServer -o tsv

Write-Host "appServiceName: $appServiceName"
Write-Host "staticWebAppName: $staticWebAppName"
Write-Host "sqlServerName: $sqlServerName"
Write-Host "acrName: $acrName"
Write-Host "containerRegistry: $containerRegistry"

# Copy these values and update azure-pipelines.yml
```

---

## Example of Correct Variables

If your resources are named:
- Backend App Service: `registration-api-2807`
- Frontend Static Web App: `registration-frontend-2807`
- SQL Server: `regsql2807`
- Container Registry: `registrationappacr`

Then your variables section should be:

```yaml
variables:
  buildConfiguration: 'Release'
  nodeVersion: '18.x'
  dotnetVersion: '8.x'
  azureSubscription: 'RegistrationApp-Azure'
  containerRegistry: 'registrationappacr.azurecr.io'
  dockerRegistryServiceConnection: 'RegistrationApp-ACR'
  imageRepository: 'registration-api'
  acrName: 'registrationappacr'
  appServiceName: 'registration-api-2807'
  staticWebAppName: 'registration-frontend-2807'
  sqlServerName: 'regsql2807'
  resourceGroupName: 'rg-registration-app'
```

---

## After Updating

1. **Save the file**
2. **Commit changes:**
   ```powershell
   cd c:\Users\Admin\source\repos\RegistrationApp
   git add azure-pipelines.yml
   git commit -m "Update pipeline variables for Azure deployment"
   git push origin main
   ```

3. **Pipeline will auto-trigger** (because you pushed to main)

4. **Check Azure DevOps** → **Pipelines** → Watch the build

---

## What These Variables Do

| Variable | Used For |
|----------|----------|
| `azureSubscription` | Authenticate with Azure |
| `containerRegistry` | Docker registry URL |
| `dockerRegistryServiceConnection` | ACR credentials |
| `imageRepository` | Docker image name |
| `acrName` | Container registry name |
| `appServiceName` | Backend deployment target |
| `staticWebAppName` | Frontend deployment target |
| `sqlServerName` | Database server reference |
| `resourceGroupName` | Azure resource group |

---

## Common Mistakes to Avoid

❌ **Don't:** Use placeholder names like `registration-api-2807` if your real name is different
```
Use: Your ACTUAL App Service name from Azure
```

❌ **Don't:** Forget the `.azurecr.io` suffix on container registry
```
Use: registrationappacr.azurecr.io (not just registrationappacr)
```

❌ **Don't:** Mix up service connection names
```
azureSubscription: 'RegistrationApp-Azure' (from Azure DevOps)
dockerRegistryServiceConnection: 'RegistrationApp-ACR' (from Azure DevOps)
```

---

## Next Steps

Once updated:
1. ✅ Commit and push
2. ✅ Pipeline triggers automatically
3. ✅ Build, test, and deploy stages run
4. ✅ Check pipeline status in Azure DevOps

Need help getting the exact values? Run these commands:

```powershell
az webapp list --resource-group rg-registration-app --query "[].name" -o table
az staticwebapp list --resource-group rg-registration-app --query "[].name" -o table
az sql server list --resource-group rg-registration-app --query "[].name" -o table
az acr list --resource-group rg-registration-app --query "[].name" -o table
```
