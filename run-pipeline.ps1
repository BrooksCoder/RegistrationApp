# Quick Jenkins Pipeline Trigger - Edit these values for your setup
# ================================================================

$JenkinsUrl = "http://your-jenkins-server:8080"  # Change this to your Jenkins URL
$JobName = "RegistrationApp"                      # Your Jenkins job name
$Username = "admin"                               # Your Jenkins username
$ApiToken = "YOUR_API_TOKEN_HERE"               # Get from: Jenkins > Your Name > Configure > API Token

# Trigger parameters
$Branch = "main"              # Git branch to build
$DeployBackend = $true        # Deploy backend container
$DeployFrontend = $true       # Deploy frontend container

# ================================================================
# Run the trigger script
# ================================================================

if ($ApiToken -eq "YOUR_API_TOKEN_HERE") {
    Write-Host "❌ Please update the API token first!" -ForegroundColor Red
    Write-Host ""
    Write-Host "How to get your Jenkins API Token:" -ForegroundColor Yellow
    Write-Host "1. Go to: $JenkinsUrl/user/$Username/configure" -ForegroundColor White
    Write-Host "2. Click 'Add new Token' under API Token section" -ForegroundColor White
    Write-Host "3. Copy the token and update the ApiToken variable above" -ForegroundColor White
    exit 1
}

Write-Host "Triggering Jenkins Pipeline..." -ForegroundColor Cyan

$params = @{
    JenkinsUrl = $JenkinsUrl
    JobName = $JobName
    Username = $Username
    ApiToken = $ApiToken
    Branch = $Branch
    DeployBackend = $DeployBackend
    DeployFrontend = $DeployFrontend
}

& ".\trigger-jenkins-pipeline.ps1" @params
