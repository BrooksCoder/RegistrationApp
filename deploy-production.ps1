#!/usr/bin/env pwsh
# One-click deployment script for RegistrationApp backend to Azure Container Instances

param(
    [switch]$SkipBuild,
    [switch]$SkipPush,
    [switch]$SkipRestart,
    [string]$ImageTag = "latest"
)

$ErrorActionPreference = "Stop"

# Configuration
$ResourceGroup = "rg-registration-app"
$ContainerName = "registration-api-prod"
$AcrName = "registrationappacr"
$AcrUrl = "$AcrName.azurecr.io"
$ImageName = "registration-api"
$FullImageName = "$AcrUrl/$ImageName`:$ImageTag"
$BackendPath = "c:\Users\Admin\source\repos\RegistrationApp\backend"

Write-Host ""
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "         REGISTRATION APP - PRODUCTION DEPLOYMENT" -ForegroundColor Cyan
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Verify Azure Login
Write-Host "[1/6] Verifying Azure Login..." -ForegroundColor Yellow
$currentAccount = az account show --query "name" -o tsv
if (-not $currentAccount) {
    Write-Host "FAILED: Not logged into Azure. Run 'az login' first." -ForegroundColor Red
    exit 1
}
Write-Host "SUCCESS: Logged in as: $currentAccount" -ForegroundColor Green

# Step 2: Build Docker Image
if (-not $SkipBuild) {
    Write-Host ""
    Write-Host "[2/6] Building Docker Image..." -ForegroundColor Yellow
    Push-Location $BackendPath
    try {
        docker build --no-cache -t $FullImageName .
        if ($LASTEXITCODE -ne 0) {
            Write-Host "FAILED: Docker build failed" -ForegroundColor Red
            exit 1
        }
        Write-Host "SUCCESS: Docker image built: $FullImageName" -ForegroundColor Green
    }
    finally {
        Pop-Location
    }
} else {
    Write-Host ""
    Write-Host "[2/6] Skipping Docker build (flag set)" -ForegroundColor Cyan
}

# Step 3: Push to ACR
if (-not $SkipPush) {
    Write-Host ""
    Write-Host "[3/6] Pushing Image to Azure Container Registry..." -ForegroundColor Yellow
    
    Write-Host "   Logging into ACR..." -ForegroundColor Cyan
    az acr login --name $AcrName
    
    Write-Host "   Pushing image..." -ForegroundColor Cyan
    docker push $FullImageName
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAILED: Docker push failed" -ForegroundColor Red
        exit 1
    }
    Write-Host "SUCCESS: Image pushed to ACR" -ForegroundColor Green
    
} else {
    Write-Host ""
    Write-Host "[3/6] Skipping ACR push (flag set)" -ForegroundColor Cyan
}

# Step 4: Delete Old Container
Write-Host ""
Write-Host "[4/6] Cleaning up old container instance..." -ForegroundColor Yellow
$existingContainer = az container show --resource-group $ResourceGroup --name $ContainerName --query "id" -o tsv 2>/dev/null
if ($existingContainer) {
    Write-Host "   Deleting existing container..." -ForegroundColor Cyan
    az container delete --resource-group $ResourceGroup --name $ContainerName --yes
    Write-Host "   Waiting for cleanup..." -ForegroundColor Cyan
    Start-Sleep -Seconds 5
    Write-Host "SUCCESS: Old container deleted" -ForegroundColor Green
} else {
    Write-Host "INFO: No existing container found (first deployment)" -ForegroundColor Cyan
}

# Step 5: Get ACR Credentials
Write-Host ""
Write-Host "[5/6] Retrieving ACR credentials..." -ForegroundColor Yellow
$acrUsername = az acr credential show --resource-group $ResourceGroup --name $AcrName --query "username" -o tsv
$acrPassword = az acr credential show --resource-group $ResourceGroup --name $AcrName --query "passwords[0].value" -o tsv

if (-not $acrUsername -or -not $acrPassword) {
    Write-Host "FAILED: Could not retrieve ACR credentials" -ForegroundColor Red
    exit 1
}
Write-Host "SUCCESS: ACR credentials retrieved" -ForegroundColor Green

# Step 6: Create New Container Instance
if (-not $SkipRestart) {
    Write-Host ""
    Write-Host "[6/6] Creating new container instance..." -ForegroundColor Yellow
    
    Write-Host "   Configuration:" -ForegroundColor Cyan
    Write-Host "     - Name: $ContainerName" -ForegroundColor Cyan
    Write-Host "     - Image: $FullImageName" -ForegroundColor Cyan
    Write-Host "     - Region: centralindia" -ForegroundColor Cyan
    Write-Host "     - CPU: 1 vCPU" -ForegroundColor Cyan
    Write-Host "     - Memory: 1 GB" -ForegroundColor Cyan
    
    Write-Host "   Creating container..." -ForegroundColor Cyan
    
    az container create `
        --resource-group $ResourceGroup `
        --name $ContainerName `
        --image $FullImageName `
        --cpu 1 `
        --memory 1 `
        --registry-login-server $AcrUrl `
        --registry-username $acrUsername `
        --registry-password $acrPassword `
        --ports 80 `
        --dns-name-label "registration-api-prod" `
        --environment-variables ASPNETCORE_ENVIRONMENT="Production" ASPNETCORE_URLS="http://+:80" `
        --secure-environment-variables "ConnectionStrings__DefaultConnection=Server=tcp:regsql2807.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourSecurePassword123!@#;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;" `
        --location centralindia `
        --restart-policy OnFailure
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAILED: Container creation failed" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "SUCCESS: Container created" -ForegroundColor Green
    
    Write-Host "   Waiting for container startup (30 seconds)..." -ForegroundColor Cyan
    Start-Sleep -Seconds 30
    
    # Get container details
    $containerInfo = az container show --resource-group $ResourceGroup --name $ContainerName
    $containerObj = $containerInfo | ConvertFrom-Json
    
    if ($containerObj.instanceView.state -eq "Running") {
        Write-Host "SUCCESS: Container is running" -ForegroundColor Green
        $fqdn = $containerObj.ipAddress.fqdn
        Write-Host "   FQDN: $fqdn" -ForegroundColor Yellow
        Write-Host "   API URL: http://$fqdn/api/items" -ForegroundColor Yellow
    } else {
        Write-Host "WARNING: Container state is $($containerObj.instanceView.state)" -ForegroundColor Yellow
    }
} else {
    Write-Host ""
    Write-Host "[6/6] Skipping container restart (flag set)" -ForegroundColor Cyan
}

# Summary
Write-Host ""
Write-Host "=====================================================================" -ForegroundColor Green
Write-Host "                   DEPLOYMENT COMPLETE" -ForegroundColor Green
Write-Host "=====================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Check logs: az container logs --resource-group $ResourceGroup --name $ContainerName" -ForegroundColor Cyan
Write-Host "  2. Test API: Invoke-WebRequest -Uri 'http://registration-api-prod.centralindia.azurecontainer.io/api/items'" -ForegroundColor Cyan
Write-Host "  3. View status: az container show --resource-group $ResourceGroup --name $ContainerName" -ForegroundColor Cyan
Write-Host ""
Write-Host "API Endpoint: http://registration-api-prod.centralindia.azurecontainer.io" -ForegroundColor Yellow
Write-Host ""
