# Diagnostic script to check frontend-backend connectivity
param(
    [string]$ResourceGroup = "rg-registration-app",
    [string]$FrontendName = "registration-frontend-prod",
    [string]$BackendName = "registration-api-prod"
)

Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "🔍 Frontend-Backend Connectivity Diagnostic" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Get backend container info
Write-Host "Step 1: Checking Backend Container Status..." -ForegroundColor Yellow
$backendInfo = az container show --resource-group $ResourceGroup --name $BackendName --query "{State:instanceView.state, IP:ipAddress.ip, FQDN:ipAddress.fqdn, Ports:ipAddress.ports[0].port}" -o json | ConvertFrom-Json

Write-Host "  Backend Status: $($backendInfo.State)" -ForegroundColor White
Write-Host "  Backend IP: $($backendInfo.IP)" -ForegroundColor White
Write-Host "  Backend FQDN: $($backendInfo.FQDN)" -ForegroundColor White
Write-Host "  Backend Port: $($backendInfo.Ports)" -ForegroundColor White
Write-Host ""

# Get frontend container info
Write-Host "Step 2: Checking Frontend Container Status..." -ForegroundColor Yellow
$frontendInfo = az container show --resource-group $ResourceGroup --name $FrontendName --query "{State:instanceView.state, IP:ipAddress.ip, FQDN:ipAddress.fqdn}" -o json | ConvertFrom-Json

Write-Host "  Frontend Status: $($frontendInfo.State)" -ForegroundColor White
Write-Host "  Frontend IP: $($frontendInfo.IP)" -ForegroundColor White
Write-Host "  Frontend FQDN: $($frontendInfo.FQDN)" -ForegroundColor White
Write-Host ""

# Test backend health
Write-Host "Step 3: Testing Backend Health..." -ForegroundColor Yellow
$backendUrl = "http://$($backendInfo.FQDN)"
try {
    $health = Invoke-WebRequest -Uri "$backendUrl/health" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    Write-Host "  ✅ Backend health check: SUCCESS (Status: $($health.StatusCode))" -ForegroundColor Green
}
catch {
    Write-Host "  ❌ Backend health check: FAILED" -ForegroundColor Red
    Write-Host "     Error: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test API endpoint
Write-Host "Step 4: Testing Backend API..." -ForegroundColor Yellow
try {
    $api = Invoke-WebRequest -Uri "$backendUrl/api/items" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    Write-Host "  ✅ Backend API is responding (Status: $($api.StatusCode))" -ForegroundColor Green
    Write-Host "  Response length: $($api.Content.Length) bytes" -ForegroundColor White
}
catch {
    Write-Host "  ❌ Backend API call failed" -ForegroundColor Red
    Write-Host "     Error: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Check frontend logs
Write-Host "Step 5: Checking Frontend Container Logs..." -ForegroundColor Yellow
Write-Host ""
$logs = az container logs --resource-group $ResourceGroup --name $FrontendName
Write-Host $logs
Write-Host ""

# Check frontend nginx config
Write-Host "Step 6: Checking Frontend Nginx Config..." -ForegroundColor Yellow
Write-Host "Executing: cat /etc/nginx/conf.d/default.conf" -ForegroundColor White
Write-Host ""
$nginxConfig = az container exec `
    --resource-group $ResourceGroup `
    --name $FrontendName `
    --exec-command "/bin/sh" `
    -c "cat /etc/nginx/conf.d/default.conf" 2>&1

Write-Host $nginxConfig
Write-Host ""

# Test connectivity from frontend to backend
Write-Host "Step 7: Testing Frontend->Backend Connectivity..." -ForegroundColor Yellow
$backendIp = $backendInfo.IP
$backendFqdn = $backendInfo.FQDN

Write-Host "Attempting to reach backend from frontend container..." -ForegroundColor White
$connectivity = az container exec `
    --resource-group $ResourceGroup `
    --name $FrontendName `
    --exec-command "/bin/sh" `
    -c "wget -q -O- http://$backendFqdn/health 2>&1" 2>&1

if ($connectivity -like "*200*" -or $connectivity -like "*OK*") {
    Write-Host "  ✅ Frontend CAN reach backend" -ForegroundColor Green
    Write-Host "  Response: $connectivity" -ForegroundColor White
}
else {
    Write-Host "  ❌ Frontend CANNOT reach backend" -ForegroundColor Red
    Write-Host "  Response: $connectivity" -ForegroundColor Red
}
Write-Host ""

Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Frontend URL: http://$($frontendInfo.FQDN)" -ForegroundColor White
Write-Host "Backend URL: http://$($backendInfo.FQDN)" -ForegroundColor White
Write-Host ""
if ($backendInfo.State -eq "Running" -and $frontendInfo.State -eq "Running") {
    Write-Host "✅ Both containers are running" -ForegroundColor Green
}
else {
    Write-Host "❌ One or more containers not running" -ForegroundColor Red
}
