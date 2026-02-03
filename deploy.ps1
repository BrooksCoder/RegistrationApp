param([string]$Step = "all")

$resourceGroup = "rg-registration-app"
$location = "centralindia"
$acrName = "registrationappacr"
$acrServer = "$acrName.azurecr.io"
$sqlServer = "regsql2807"
$sqlDb = "RegistrationAppDb"
$sqlUser = "sqladmin"
$sqlPass = "YourSecurePassword123!@#"
$backendName = "registration-api-prod"
$frontendName = "registration-frontend-prod"

function Deploy-Sql {
    Write-Host "`n=== STEP 1: CREATE SQL DATABASE ===" -ForegroundColor Green
    
    az sql db create `
      --name $sqlDb `
      --server $sqlServer `
      --resource-group $resourceGroup `
      --edition Basic `
      --compute-model Serverless `
      --backup-storage-redundancy Local
    
    Write-Host "SQL Database ready" -ForegroundColor Green
}

function Deploy-Firewall {
    Write-Host "`n=== STEP 2: CONFIGURE FIREWALL ===" -ForegroundColor Green
    
    az sql server firewall-rule create `
      --resource-group $resourceGroup `
      --server $sqlServer `
      --name "AllowAzureServices" `
      --start-ip-address 0.0.0.0 `
      --end-ip-address 0.0.0.0
    
    Write-Host "Firewall configured" -ForegroundColor Green
}

function Deploy-Docker {
    Write-Host "`n=== STEP 3: BUILD AND PUSH DOCKER IMAGES ===" -ForegroundColor Green
    
    az acr login --name $acrName
    
    Write-Host "Building backend image..."
    docker build -f backend/Dockerfile -t "$acrServer/registration-api:v3" ./backend
    docker push "$acrServer/registration-api:v3"
    Write-Host "Backend image v3 pushed" -ForegroundColor Green
    
    Write-Host "Building frontend image..."
    docker build -f frontend/Dockerfile -t "$acrServer/registration-frontend:v3" ./frontend
    docker push "$acrServer/registration-frontend:v3"
    Write-Host "Frontend image v3 pushed" -ForegroundColor Green
}

function Deploy-Containers {
    Write-Host "`n=== STEP 4: DEPLOY TO AZURE ===" -ForegroundColor Green
    
    $acrUser = az acr credential show --resource-group $resourceGroup --name $acrName --query username -o tsv
    $acrPass = az acr credential show --resource-group $resourceGroup --name $acrName --query "passwords[0].value" -o tsv
    
    $sqlFqdn = "$sqlServer.database.windows.net"
    $connStr = "Server=tcp:$sqlFqdn,1433;Initial Catalog=$sqlDb;Persist Security Info=False;User ID=$sqlUser;Password=$sqlPass;Encrypt=True;Connection Timeout=30;"
    
    Write-Host "Deploying backend container..."
    
    az container delete --resource-group $resourceGroup --name $backendName --yes 2>$null
    
    az container create `
      --resource-group $resourceGroup `
      --name $backendName `
      --image "$acrServer/registration-api:v4" `
      --cpu 1 `
      --memory 1 `
      --os-type Linux `
      --registry-login-server $acrServer `
      --registry-username $acrUser `
      --registry-password $acrPass `
      --ports 80 `
      --dns-name-label "registration-api-prod" `
      --location $location `
      --environment-variables ASPNETCORE_ENVIRONMENT=Production "ConnectionStrings__DefaultConnection=$connStr"
    
    Write-Host "Backend deployed" -ForegroundColor Green
    Start-Sleep -Seconds 5
    
    $backendUrl = az container show --resource-group $resourceGroup --name $backendName --query ipAddress.fqdn -o tsv
    Write-Host "Backend: http://$backendUrl" -ForegroundColor Cyan
    
    Write-Host "Deploying frontend container..."
    
    az container delete --resource-group $resourceGroup --name $frontendName --yes 2>$null
    
    az container create `
      --resource-group $resourceGroup `
      --name $frontendName `
      --image "$acrServer/registration-frontend:v3" `
      --cpu 0.5 `
      --memory 0.5 `
      --os-type Linux `
      --registry-login-server $acrServer `
      --registry-username $acrUser `
      --registry-password $acrPass `
      --ports 80 `
      --dns-name-label "registration-frontend-prod" `
      --location $location `
      --environment-variables "BACKEND_URL=http://$backendUrl"
    
    Write-Host "Frontend deployed" -ForegroundColor Green
    Start-Sleep -Seconds 5
    
    $frontendUrl = az container show --resource-group $resourceGroup --name $frontendName --query ipAddress.fqdn -o tsv
    
    Write-Host "`n========== DEPLOYMENT COMPLETE ==========" -ForegroundColor Green
    Write-Host "Frontend: http://$frontendUrl" -ForegroundColor Yellow
    Write-Host "Backend:  http://$backendUrl" -ForegroundColor Yellow
    Write-Host "API:      http://$backendUrl/api/items" -ForegroundColor Yellow
    Write-Host "Swagger:  http://$backendUrl/swagger/index.html" -ForegroundColor Yellow
    Write-Host "`nCost: 25 dollars per month" -ForegroundColor Green
    Write-Host "Duration: 7 plus months on your 180 dollar budget" -ForegroundColor Green
}

Write-Host "`nDeployment starting..." -ForegroundColor Green

if ($Step -eq "all" -or $Step -eq "1") { Deploy-Sql }
if ($Step -eq "all" -or $Step -eq "2") { Deploy-Firewall }
if ($Step -eq "all" -or $Step -eq "3") { Deploy-Docker }
if ($Step -eq "all" -or $Step -eq "4") { Deploy-Containers }

Write-Host "`nDone" -ForegroundColor Green
