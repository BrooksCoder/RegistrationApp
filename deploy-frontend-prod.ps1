#!/usr/bin/env pwsh

<#
.SYNOPSIS
Deploy or update the frontend container with correct backend URL
#>

param(
    [string]$ResourceGroup = "rg-registration-app",
    [string]$ContainerName = "registration-frontend-prod",
    [string]$AcrName = "registrationappacr",
    [string]$BackendUrl = "http://registration-backend-prod.centralindia.azurecontainer.io",
    [string]$Location = "centralindia"
)

function Write-Status {
    param([string]$Message, [string]$Status = "INFO")
    $colors = @{
        "INFO" = "Cyan"
        "SUCCESS" = "Green"
        "WARNING" = "Yellow"
        "ERROR" = "Red"
    }
    Write-Host "[$Status] $Message" -ForegroundColor $colors[$Status]
}

try {
    Write-Status "Frontend Deployment Script Started" "INFO"
    Write-Status "Resource Group: $ResourceGroup" "INFO"
    Write-Status "Backend URL: $BackendUrl" "INFO"
    Write-Status ""
    
    # Step 1: Check if container exists
    Write-Status "Step 1: Checking if container exists..." "INFO"
    $containerExists = az container show --resource-group $ResourceGroup --name $ContainerName 2>&1 | Select-String "ResourceNotFound"
    
    if ($null -eq $containerExists) {
        Write-Status "Container exists, deleting it..." "WARNING"
        az container delete --resource-group $ResourceGroup --name $ContainerName --yes | Out-Null
        Start-Sleep -Seconds 5
    } else {
        Write-Status "Container does not exist, creating new one..." "INFO"
    }
    
    # Step 2: Get ACR credentials
    Write-Status "Step 2: Getting ACR credentials..." "INFO"
    $acrPassword = az acr credential show --name $AcrName --query passwords[0].value -o tsv
    $acrLoginServer = "$AcrName.azurecr.io"
    
    if ([string]::IsNullOrEmpty($acrPassword)) {
        throw "Failed to retrieve ACR password"
    }
    Write-Status "ACR credentials retrieved successfully" "SUCCESS"
    
    # Step 3: Create frontend container
    Write-Status "Step 3: Creating frontend container..." "INFO"
    Write-Status "Image: $acrLoginServer/registration-frontend-prod:latest" "INFO"
    Write-Status "Environment Variables:" "INFO"
    Write-Status "  - BACKEND_URL=$BackendUrl" "INFO"
    
    az container create `
        --resource-group $ResourceGroup `
        --name $ContainerName `
        --image "$acrLoginServer/registration-frontend-prod:latest" `
        --os-type Linux `
        --cpu 1 `
        --memory 1.5 `
        --environment-variables BACKEND_URL="$BackendUrl" `
        --ports 80 `
        --registry-login-server $acrLoginServer `
        --registry-username $AcrName `
        --registry-password $acrPassword `
        --dns-name-label $ContainerName `
        --location $Location `
        --restart-policy Always | Out-Null
    
    Write-Status "Container creation initiated" "SUCCESS"
    
    # Step 4: Wait and verify
    Write-Status "Step 4: Waiting for container to start (30 seconds)..." "INFO"
    Start-Sleep -Seconds 30
    
    # Get container details
    Write-Status "Step 5: Verifying container..." "INFO"
    $container = az container show `
        --resource-group $ResourceGroup `
        --name $ContainerName `
        --query '{Name:name, Status:instanceView.state, FQDN:ipAddress.fqdn}' `
        -o json | ConvertFrom-Json
    
    if ($null -ne $container) {
        Write-Status "Container Details:" "SUCCESS"
        Write-Status "  Name: $($container.Name)" "SUCCESS"
        Write-Status "  Status: $($container.Status)" "SUCCESS"
        Write-Status "  FQDN: $($container.FQDN)" "SUCCESS"
        Write-Status ""
        Write-Status "Frontend URL: http://$($container.FQDN)" "SUCCESS"
        Write-Status "Backend URL: $BackendUrl" "SUCCESS"
        Write-Status ""
        
        # Step 6: Test API endpoints
        Write-Status "Step 6: Testing API endpoints..." "INFO"
        Start-Sleep -Seconds 10
        
        $testUrl = "http://$($container.FQDN)/api/items"
        Write-Status "Testing: $testUrl" "INFO"
        
        try {
            $response = Invoke-WebRequest -Uri $testUrl -Headers @{'Accept' = 'application/json'} -ErrorAction Stop
            Write-Status "API is responding correctly (HTTP $($response.StatusCode))" "SUCCESS"
        } catch {
            if ($_.Exception.Message -like "*502*") {
                Write-Status "Still getting 502 error - backend might not be ready" "WARNING"
                Write-Status "Possible causes:" "WARNING"
                Write-Status "  1. Backend container not running" "WARNING"
                Write-Status "  2. Backend not responding on http://registration-backend-prod.centralindia.azurecontainer.io" "WARNING"
                Write-Status "  3. Network connectivity issue between containers" "WARNING"
            } else {
                Write-Status "Error testing API: $($_.Exception.Message)" "ERROR"
            }
        }
    } else {
        Write-Status "Failed to retrieve container information" "ERROR"
    }
    
    Write-Status "Deployment completed!" "SUCCESS"
    
} catch {
    Write-Status "Error: $($_.Exception.Message)" "ERROR"
    exit 1
}
