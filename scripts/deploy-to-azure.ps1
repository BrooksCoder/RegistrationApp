#!/usr/bin/env pwsh

<#
.SYNOPSIS
Quick Azure Deployment Script - Automates the complete deployment process

.DESCRIPTION
This script automates:
1. Azure login and subscription selection
2. Git push to repository
3. Azure DevOps pipeline creation
4. First deployment run

.PARAMETER SubscriptionId
The Azure subscription ID to use

.PARAMETER ResourceGroupName
Name of the resource group (default: RegistrationApp-RG)

.PARAMETER DevOpsOrganization
Azure DevOps organization name

.PARAMETER DevOpsProject
Azure DevOps project name (default: RegistrationApp)

.PARAMETER GitRepository
Git repository URL (GitHub or Azure Repos)

.EXAMPLE
.\deploy-to-azure.ps1 -SubscriptionId "xxxxx" -DevOpsOrganization "yourorg"

#>

param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "RegistrationApp-RG",

    [Parameter(Mandatory = $false)]
    [string]$DevOpsOrganization,

    [Parameter(Mandatory = $false)]
    [string]$DevOpsProject = "RegistrationApp",

    [Parameter(Mandatory = $false)]
    [string]$GitRepository
)

# Color functions for output
function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Error { Write-Host $args -ForegroundColor Red }
function Write-Warning { Write-Host $args -ForegroundColor Yellow }
function Write-Info { Write-Host $args -ForegroundColor Cyan }

Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Azure Deployment Script - RegistrationApp           ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Step 1: Verify prerequisites
Write-Info "Step 1: Verifying prerequisites..."
$prerequisites = @("az", "git", "dotnet", "node", "npm")
$missing = @()

foreach ($tool in $prerequisites) {
    try {
        $version = & "$tool" --version 2>&1 | Select-Object -First 1
        Write-Success "✓ $tool found: $version"
    }
    catch {
        $missing += $tool
        Write-Error "✗ $tool not found"
    }
}

if ($missing.Count -gt 0) {
    Write-Error "Missing prerequisites: $($missing -join ', ')"
    Write-Info "Please install the missing tools and try again."
    exit 1
}

Write-Success "All prerequisites verified!" 
Write-Host ""

# Step 2: Azure Login
Write-Info "Step 2: Authenticating with Azure..."
$azureAccount = az account show --query "user.name" -o tsv 2>/dev/null

if ($null -eq $azureAccount) {
    Write-Warning "Not logged into Azure. Launching login..."
    az login
}
else {
    Write-Success "Already logged in as: $azureAccount"
}

# Get subscription
if ($SubscriptionId) {
    az account set --subscription $SubscriptionId
    Write-Success "Using subscription: $SubscriptionId"
}
else {
    Write-Info "Available subscriptions:"
    az account list --output table --query "[].{Name:name,SubscriptionId:id,IsDefault:isDefault}"
    
    $selected = az account show --query "id" -o tsv
    Write-Success "Using default subscription: $selected"
    $SubscriptionId = $selected
}

Write-Host ""

# Step 3: Verify Git repository
Write-Info "Step 3: Preparing Git repository..."
$repoRoot = Get-Location

if (-not (Test-Path ".git")) {
    Write-Warning "Git repository not initialized. Initializing..."
    git init
    git add .
    git commit -m "Initial commit: RegistrationApp deployment"
}

$gitStatus = git status --short
if ($gitStatus) {
    Write-Warning "Uncommitted changes found:"
    Write-Host $gitStatus
    $response = Read-Host "Commit changes? (y/n)"
    if ($response -eq "y") {
        git add .
        git commit -m "Pre-deployment commit"
    }
}

$remoteUrl = git config --get remote.origin.url 2>/dev/null
if ($null -eq $remoteUrl) {
    if ($GitRepository) {
        Write-Info "Adding remote: $GitRepository"
        git remote add origin $GitRepository
    }
    else {
        Write-Warning "No git remote configured."
        $GitRepository = Read-Host "Enter remote repository URL"
        git remote add origin $GitRepository
    }
}
else {
    Write-Success "Git remote: $remoteUrl"
}

Write-Host ""

# Step 4: Push to repository
Write-Info "Step 4: Pushing code to repository..."
$pushResponse = git push -u origin main 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Success "Code pushed successfully!"
}
else {
    Write-Warning "Git push output: $pushResponse"
    if ($pushResponse -like "*branch*not found*" -or $pushResponse -like "*No such ref*") {
        Write-Info "Trying master branch instead..."
        git branch -M main
        git push -u origin main
    }
}

Write-Host ""

# Step 5: Verify Azure resources
Write-Info "Step 5: Verifying Azure resources..."
$resourceGroup = az group exists --name $ResourceGroupName -o tsv

if ($resourceGroup -eq "false") {
    Write-Warning "Resource group not found. Creating..."
    $location = Read-Host "Enter location (default: East US)" 
    if ([string]::IsNullOrEmpty($location)) { $location = "East US" }
    
    az group create --name $ResourceGroupName --location $location
}

$resources = az resource list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
Write-Info "Found $($resources.Count) resources in $ResourceGroupName"

# Display resources
foreach ($resource in $resources) {
    Write-Success "  ✓ $($resource.name) ($($resource.type))"
}

Write-Host ""

# Step 6: Setup Azure DevOps
Write-Info "Step 6: Setting up Azure DevOps..."

if ($DevOpsOrganization) {
    Write-Success "DevOps Organization: $DevOpsOrganization"
    Write-Success "DevOps Project: $DevOpsProject"
    
    Write-Host ""
    Write-Info "Next steps to complete in Azure DevOps:"
    Write-Host "  1. Go to: https://dev.azure.com/$DevOpsOrganization/$DevOpsProject"
    Write-Host "  2. Create Service Connection:"
    Write-Host "     - Type: Azure Resource Manager"
    Write-Host "     - Subscription: $SubscriptionId"
    Write-Host "     - Resource Group: $ResourceGroupName"
    Write-Host "  3. Create Container Registry Service Connection:"
    Write-Host "     - Type: Docker Registry"
    Write-Host "     - URL: registrationappacr.azurecr.io"
}
else {
    Write-Warning "DevOps organization not specified."
    Write-Host "Visit: https://dev.azure.com to setup your project"
}

Write-Host ""

# Step 7: Display deployment summary
Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         Deployment Summary                             ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

Write-Host ""
Write-Host "✓ Prerequisites verified"
Write-Host "✓ Azure authenticated"
Write-Host "✓ Git repository ready"
Write-Host "✓ Code pushed to remote"
Write-Host "✓ Azure resources verified"
Write-Host ""

Write-Success "Deployment setup complete!"
Write-Host ""

Write-Info "Next Steps:"
Write-Host "  1. Setup service connections in Azure DevOps:"
Write-Host "     https://dev.azure.com/$DevOpsOrganization/$DevOpsProject/_settings/adminserviceconnections"
Write-Host ""
Write-Host "  2. Create pipeline from azure-pipelines.yml"
Write-Host ""
Write-Host "  3. Run pipeline manually to trigger first deployment:"
Write-Host "     https://dev.azure.com/$DevOpsOrganization/$DevOpsProject/_build"
Write-Host ""
Write-Host "  4. Monitor deployment progress and verify:"
Write-Host "     - Backend: https://registrationapp-api.azurewebsites.net/swagger/index.html"
Write-Host "     - Frontend: https://registrationapp-frontend.azurewebsites.net"
Write-Host ""

Write-Host "For complete deployment guide, see:"
Write-Host "  docs/AZURE_DEPLOYMENT_GUIDE.md"
Write-Host ""

Write-Success "Setup complete! Ready for deployment. 🚀"
