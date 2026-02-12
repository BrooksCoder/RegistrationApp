# Jenkins Pipeline Trigger Script
# This script triggers the RegistrationApp pipeline in Jenkins

param(
    [string]$JenkinsUrl = "http://localhost:8080",  # Change to your Jenkins URL
    [string]$JobName = "RegistrationApp",
    [string]$Username = "admin",  # Change to your Jenkins username
    [string]$ApiToken = "",  # You'll need to provide this
    [string]$Branch = "main",
    [bool]$DeployBackend = $true,
    [bool]$DeployFrontend = $true
)

# Validate inputs
if ([string]::IsNullOrWhiteSpace($ApiToken)) {
    Write-Host "❌ Error: ApiToken is required" -ForegroundColor Red
    Write-Host ""
    Write-Host "How to get your Jenkins API Token:" -ForegroundColor Yellow
    Write-Host "1. Go to: $JenkinsUrl/user/$Username/configure"
    Write-Host "2. Click 'Add new Token' under API Token section"
    Write-Host "3. Copy the token and pass it with -ApiToken parameter"
    Write-Host ""
    exit 1
}

# Build the API credentials
$auth = "$($Username):$($ApiToken)"
$encodedAuth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($auth))
$headers = @{ Authorization = "Basic $encodedAuth" }

# Build the job parameters
$params = @{
    BRANCH = $Branch
    DEPLOY_BACKEND = $DeployBackend
    DEPLOY_FRONTEND = $DeployFrontend
}

# Convert parameters to query string
$paramString = ""
foreach ($key in $params.Keys) {
    $paramString += "&$key=$($params[$key])"
}

# Build the trigger URL
$triggerUrl = "$JenkinsUrl/job/$JobName/buildWithParameters?$paramString"

Write-Host "════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "🚀 Jenkins Pipeline Trigger" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Jenkins URL:      $JenkinsUrl" -ForegroundColor White
Write-Host "Job Name:         $JobName" -ForegroundColor White
Write-Host "Username:         $Username" -ForegroundColor White
Write-Host "Branch:           $Branch" -ForegroundColor White
Write-Host "Deploy Backend:   $DeployBackend" -ForegroundColor White
Write-Host "Deploy Frontend:  $DeployFrontend" -ForegroundColor White
Write-Host ""

try {
    Write-Host "Triggering pipeline..." -ForegroundColor Yellow
    
    $response = Invoke-WebRequest -Uri $triggerUrl `
        -Method Post `
        -Headers $headers `
        -UseBasicParsing
    
    if ($response.StatusCode -eq 201 -or $response.StatusCode -eq 200) {
        Write-Host "✅ Pipeline triggered successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "View build progress at:" -ForegroundColor Cyan
        Write-Host "$JenkinsUrl/job/$JobName" -ForegroundColor Cyan
        Write-Host ""
        
        # Wait a moment and get the build queue location
        Start-Sleep -Seconds 2
        
        # Try to get the last build number
        try {
            $apiUrl = "$JenkinsUrl/job/$JobName/lastBuild/api/json"
            $buildInfo = Invoke-WebRequest -Uri $apiUrl -Headers $headers -UseBasicParsing | ConvertFrom-Json
            Write-Host "Latest Build:     #$($buildInfo.number)" -ForegroundColor Cyan
            Write-Host "Status:           $($buildInfo.result)" -ForegroundColor Cyan
        }
        catch {
            Write-Host "Build queued. Check Jenkins for status." -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "⚠️  Unexpected response: $($response.StatusCode)" -ForegroundColor Yellow
        Write-Host $response.Content
    }
}
catch {
    Write-Host "❌ Error triggering pipeline:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting steps:" -ForegroundColor Yellow
    Write-Host "1. Verify Jenkins URL is correct: $JenkinsUrl" -ForegroundColor White
    Write-Host "2. Verify username is correct: $Username" -ForegroundColor White
    Write-Host "3. Verify API token is correct" -ForegroundColor White
    Write-Host "4. Verify job name exists: $JobName" -ForegroundColor White
    Write-Host "5. Verify Jenkins is running and accessible" -ForegroundColor White
}

Write-Host ""
Write-Host "════════════════════════════════════════" -ForegroundColor Cyan
