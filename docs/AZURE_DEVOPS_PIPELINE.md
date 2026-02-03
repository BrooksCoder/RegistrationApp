# Azure DevOps Pipeline Configuration

## Complete YAML Pipeline for CI/CD

### File Location
Place this file at the root of your repository: `azure-pipelines.yml`

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
  DOTNET_SKIP_FIRST_TIME_EXPERIENCE: true
  DOTNET_CLI_TELEMETRY_OPTOUT: true

stages:
  # ==================== STAGE 1: BUILD ====================
  - stage: Build
    displayName: 'Build & Test'
    jobs:
      # ========== BUILD ANGULAR FRONTEND ==========
      - job: BuildFrontend
        displayName: 'Build Angular Frontend'
        steps:
          - task: NodeTool@0
            inputs:
              versionSpec: $(nodeVersion)
            displayName: 'Install Node.js $(nodeVersion)'

          - task: CacheBeta@1
            inputs:
              key: 'npm | "$(Agent.OS)" | $(Build.SourcesDirectory)/frontend/package-lock.json'
              restoreKeys: |
                npm | "$(Agent.OS)"
              path: '$(Build.SourcesDirectory)/frontend/node_modules'
            displayName: 'Cache npm modules'

          - task: Npm@1
            inputs:
              command: 'ci'
              workingDir: '$(Build.SourcesDirectory)/frontend'
            displayName: 'npm ci (clean install)'

          - task: Npm@1
            inputs:
              command: 'custom'
              customCommand: 'run build -- --configuration production'
              workingDir: '$(Build.SourcesDirectory)/frontend'
            displayName: 'Build Angular (Production)'

          - task: Npm@1
            inputs:
              command: 'custom'
              customCommand: 'run test'
              workingDir: '$(Build.SourcesDirectory)/frontend'
            displayName: 'Run Unit Tests'
            continueOnError: true

          - task: PublishBuildArtifacts@1
            inputs:
              pathToPublish: '$(Build.SourcesDirectory)/frontend/dist'
              artifactName: 'frontend'
              publishLocation: 'Container'
            displayName: 'Publish Frontend Artifact'

      # ========== BUILD .NET BACKEND ==========
      - job: BuildBackend
        displayName: 'Build .NET Core Backend'
        steps:
          - task: UseDotNet@2
            inputs:
              version: $(dotnetVersion)
              packageType: 'sdk'
            displayName: 'Install .NET $(dotnetVersion)'

          - task: CacheBeta@1
            inputs:
              key: 'nuget | "$(Agent.OS)" | $(Build.SourcesDirectory)/backend/RegistrationApi.csproj'
              restoreKeys: |
                nuget | "$(Agent.OS)"
              path: '$(Build.SourcesDirectory)/backend/bin'
            displayName: 'Cache NuGet packages'

          - task: DotNetCoreCLI@2
            inputs:
              command: 'restore'
              projects: '$(Build.SourcesDirectory)/backend/**/*.csproj'
            displayName: 'Restore NuGet packages'

          - task: DotNetCoreCLI@2
            inputs:
              command: 'build'
              projects: '$(Build.SourcesDirectory)/backend/**/*.csproj'
              arguments: '--configuration $(buildConfiguration) --no-restore'
            displayName: 'Build .NET Core'

          - task: DotNetCoreCLI@2
            inputs:
              command: 'test'
              projects: '$(Build.SourcesDirectory)/backend/**/*Tests.csproj'
              arguments: '--configuration $(buildConfiguration) --no-build'
            displayName: 'Run Unit Tests'
            continueOnError: true

          - task: DotNetCoreCLI@2
            inputs:
              command: 'publish'
              projects: '$(Build.SourcesDirectory)/backend/**/*.csproj'
              publishWebProjects: false
              arguments: '--configuration $(buildConfiguration) --output $(Build.ArtifactStagingDirectory) --no-restore'
              zipAfterPublish: true
            displayName: 'Publish .NET Core'

          - task: PublishBuildArtifacts@1
            inputs:
              pathToPublish: '$(Build.ArtifactStagingDirectory)'
              artifactName: 'backend'
              publishLocation: 'Container'
            displayName: 'Publish Backend Artifact'

  # ==================== STAGE 2: DEPLOY TO STAGING ====================
  - stage: DeployStaging
    displayName: 'Deploy to Staging'
    dependsOn: Build
    condition: succeeded()
    jobs:
      - deployment: DeployBackendStaging
        displayName: 'Deploy Backend to Staging'
        pool:
          vmImage: 'ubuntu-latest'
        environment: 'Staging'
        strategy:
          runOnce:
            deploy:
              steps:
                - task: DownloadBuildArtifacts@0
                  inputs:
                    artifactName: 'backend'
                    downloadPath: '$(Pipeline.Workspace)/backend'
                  displayName: 'Download Backend Artifact'

                - task: AzureWebApp@1
                  inputs:
                    azureSubscription: '$(azureServiceConnection)'
                    appType: 'webAppLinux'
                    appName: '$(backendAppNameStaging)'
                    runtimeStack: 'DOTNETCORE|8.0'
                    package: '$(Pipeline.Workspace)/backend'
                    deploymentMethod: 'zipDeploy'
                  displayName: 'Deploy to Azure App Service (Staging)'

      - deployment: DeployFrontendStaging
        displayName: 'Deploy Frontend to Staging'
        pool:
          vmImage: 'ubuntu-latest'
        environment: 'Staging'
        strategy:
          runOnce:
            deploy:
              steps:
                - task: DownloadBuildArtifacts@0
                  inputs:
                    artifactName: 'frontend'
                    downloadPath: '$(Pipeline.Workspace)/frontend'
                  displayName: 'Download Frontend Artifact'

                - task: AzureStaticWebApp@0
                  inputs:
                    azure_static_web_apps_api_token: '$(staticWebAppTokenStaging)'
                    app_location: '$(Pipeline.Workspace)/frontend'
                    output_location: 'dist'
                  displayName: 'Deploy to Azure Static Web App (Staging)'

  # ==================== STAGE 3: DEPLOY TO PRODUCTION ====================
  - stage: DeployProduction
    displayName: 'Deploy to Production'
    dependsOn: DeployStaging
    condition: succeeded()
    jobs:
      - deployment: DeployBackendProduction
        displayName: 'Deploy Backend to Production'
        pool:
          vmImage: 'ubuntu-latest'
        environment: 'Production'
        strategy:
          runOnce:
            deploy:
              steps:
                - task: DownloadBuildArtifacts@0
                  inputs:
                    artifactName: 'backend'
                    downloadPath: '$(Pipeline.Workspace)/backend'
                  displayName: 'Download Backend Artifact'

                - task: AzureWebApp@1
                  inputs:
                    azureSubscription: '$(azureServiceConnection)'
                    appType: 'webAppLinux'
                    appName: '$(backendAppNameProd)'
                    runtimeStack: 'DOTNETCORE|8.0'
                    package: '$(Pipeline.Workspace)/backend'
                    deploymentMethod: 'zipDeploy'
                  displayName: 'Deploy to Azure App Service (Production)'

      - deployment: DeployFrontendProduction
        displayName: 'Deploy Frontend to Production'
        pool:
          vmImage: 'ubuntu-latest'
        environment: 'Production'
        strategy:
          runOnce:
            deploy:
              steps:
                - task: DownloadBuildArtifacts@0
                  inputs:
                    artifactName: 'frontend'
                    downloadPath: '$(Pipeline.Workspace)/frontend'
                  displayName: 'Download Frontend Artifact'

                - task: AzureStaticWebApp@0
                  inputs:
                    azure_static_web_apps_api_token: '$(staticWebAppTokenProd)'
                    app_location: '$(Pipeline.Workspace)/frontend'
                    output_location: 'dist'
                  displayName: 'Deploy to Azure Static Web App (Production)'
```

## Azure DevOps Setup Steps

### 1. Create Build Service Connection
```powershell
# In Azure DevOps portal:
# Project Settings > Service Connections > New Service Connection > Azure Resource Manager
# Choose "Service Principal (automatic)" for simplicity

# Store the service connection name for the pipeline
```

### 2. Create Variable Groups (for sensitive values)
In Azure DevOps:
1. Pipelines > Library > Create variable group
2. Add these variables:
   - `backendAppNameStaging` = your-backend-staging
   - `backendAppNameProd` = your-backend-prod
   - `azureServiceConnection` = your-service-connection-name
   - `staticWebAppTokenStaging` = (from Azure Static Web App deployment token)
   - `staticWebAppTokenProd` = (from Azure Static Web App deployment token)

### 3. Link Variable Group to Pipeline
In `azure-pipelines.yml`:
```yaml
variables:
  - group: RegistrationAppVariables
```

### 4. Create Environments
1. Go to Pipelines > Environments
2. Create "Staging" environment
3. Create "Production" environment
4. Add approval gates for Production:
   - Settings > Approvals and checks > Approvers

### 5. Database Migrations in Pipeline

Add this step before deploying backend:
```yaml
- task: SqlAzureDacpacDeployment@1
  inputs:
    azureSubscription: '$(azureServiceConnection)'
    AuthenticationType: 'servicePrincipal'
    ServerName: '$(sqlServerName).database.windows.net'
    DatabaseName: 'RegistrationAppDb'
    SqlUsername: '$(sqlAdminUser)'
    SqlPassword: '$(sqlAdminPassword)'
    DacpacFile: '$(Pipeline.Workspace)/Database.dacpac'
  displayName: 'Apply Database Migrations'
```

Or use EF Core migrations:
```yaml
- task: DotNetCoreCLI@2
  inputs:
    command: 'custom'
    custom: 'ef'
    arguments: 'database update --project $(Build.SourcesDirectory)/backend --configuration Release'
  displayName: 'Apply EF Core Migrations'
```

## Testing in Pipeline

### Unit Tests for Backend
```yaml
- task: DotNetCoreCLI@2
  inputs:
    command: 'test'
    projects: '$(Build.SourcesDirectory)/backend/**/*Tests.csproj'
    arguments: '--configuration $(buildConfiguration) --collect:"XPlat Code Coverage"'
  displayName: 'Run Backend Tests'
```

### Code Coverage
```yaml
- task: PublishCodeCoverageResults@1
  inputs:
    codeCoverageTool: 'Cobertura'
    summaryFileLocation: '$(Agent.TempDirectory)/**/coverage.cobertura.xml'
  displayName: 'Publish Code Coverage'
```

## Notifications

### Email Notifications on Failure
1. Project Settings > Notifications > New Subscription
2. Select "Build pipeline completion"
3. Condition: "Completes successfully and fails"
4. Send to team

### Slack Integration
```yaml
- task: SlackNotification@0
  inputs:
    SlackWebhookUrl: '$(SlackWebhook)'
    message: 'Build $(Build.BuildNumber) $(Build.Repository.Name) - $(Build.SourceBranchName) - Status: $(Agent.JobStatus)'
  displayName: 'Post to Slack'
  condition: always()
```

## Best Practices

✅ **Do:**
- Use variable groups for sensitive data
- Implement approval gates for production
- Run tests in pipeline
- Use caching for faster builds
- Keep deployments atomic
- Monitor pipeline health

❌ **Don't:**
- Store secrets in YAML
- Deploy directly to production from main
- Skip testing in pipeline
- Use outdated dependencies
- Ignore build failures

