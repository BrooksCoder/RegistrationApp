# Jenkins Setup Guide

## Quick Start with Docker

### 1. Start Jenkins Container

```powershell
docker run -d `
  -p 8080:8080 `
  -p 50000:50000 `
  --name jenkins `
  -v jenkins_home:/var/jenkins_home `
  jenkins/jenkins:latest
```

### 2. Get Initial Admin Password

```powershell
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

Copy this password.

### 3. Access Jenkins

1. Open browser: **http://localhost:8080**
2. Paste the admin password
3. Click "Continue"
4. Choose "Install suggested plugins" (recommended)
5. Wait for plugins to install (~5 minutes)
6. Create admin user account
7. Click "Save and Continue"

## Create Your Pipeline

### Step 1: Create New Job

1. Click **New Item**
2. Enter name: `RegistrationApp-Deploy`
3. Select: **Pipeline**
4. Click **OK**

### Step 2: Configure Pipeline

1. Scroll to **Pipeline** section
2. Select: **Pipeline script from SCM**
3. SCM: **Git**
4. Repository URL: `https://github.com/BrooksCoder/RegistrationApp.git`
5. Branch: `*/main`
6. Script Path: `Jenkinsfile`
7. Click **Save**

### Step 3: Configure Azure Credentials

1. Go to **Manage Jenkins** → **Manage Credentials**
2. Click **System** → **Global credentials**
3. Click **Add Credentials** (left sidebar)
4. Kind: **Username with password**
5. Username: Your Azure service principal client ID
6. Password: Your Azure service principal client secret
7. ID: `azure-credentials`
8. Click **Create**

### Step 4: Get Azure Service Principal

Run this command to create credentials:

```powershell
az ad sp create-for-rbac --name "JenkinsDeployment" --role contributor --scopes /subscriptions/af300fa3-a715-4320-8558-efe8a549457e
```

Output example:
```json
{
  "appId": "YOUR_CLIENT_ID",
  "displayName": "JenkinsDeployment",
  "password": "YOUR_CLIENT_SECRET",
  "tenant": "YOUR_TENANT_ID"
}
```

Use:
- **appId** as Username
- **password** as Password

### Step 5: Configure Environment Variables

1. Go back to your pipeline job
2. Click **Configure**
3. Scroll to **Pipeline** section
4. Add these environment variables in the Jenkinsfile (already done):
   ```
   DOCKER_REGISTRY = 'registrationappacr.azurecr.io'
   ACR_NAME = 'registrationappacr'
   RESOURCE_GROUP = 'rg-registration-app'
   ```

### Step 6: Install Required Plugins

Go to **Manage Jenkins** → **Manage Plugins** → **Available**

Search and install:
- Docker Pipeline
- Azure Credentials
- Git

Then click **Install without restart**

### Step 7: Run Your First Pipeline

1. Go to your pipeline job: `RegistrationApp-Deploy`
2. Click **Build Now**
3. Watch the build progress in real-time
4. Check console output for any errors

## Pipeline Stages

The Jenkinsfile will:

1. **Checkout** - Clone your GitHub repository
2. **Build Backend** - Build backend Docker image
3. **Build Frontend** - Build frontend Docker image
4. **Login to ACR** - Authenticate to Azure Container Registry
5. **Push Backend** - Push backend image to ACR
6. **Push Frontend** - Push frontend image to ACR
7. **Deploy Backend** - Deploy backend to Azure Container Instances
8. **Deploy Frontend** - Deploy frontend to Azure Container Instances

## Automate Pipeline Triggers

### Option 1: GitHub Webhook (Automatic on push)

1. In Jenkins job: Click **Configure**
2. Check: **GitHub hook trigger for GITScm polling**
3. Go to GitHub: Settings → Webhooks → Add webhook
4. Payload URL: `http://YOUR_IP:8080/github-webhook/`
5. Content type: `application/json`
6. Events: `Just the push event`
7. Click **Add webhook**

### Option 2: Poll SCM (Check every 5 minutes)

1. In Jenkins job: Click **Configure**
2. Under **Build Triggers**, check: **Poll SCM**
3. Schedule: `H/5 * * * *` (check every 5 minutes)
4. Click **Save**

## Access Results

After deployment completes, your application is available at:

- **Frontend:** http://registration-frontend-prod.centralindia.azurecontainer.io/
- **Backend:** http://registration-api-prod.centralindia.azurecontainer.io/
- **API:** http://registration-api-prod.centralindia.azurecontainer.io/api/items
- **Swagger:** http://registration-api-prod.centralindia.azurecontainer.io/swagger/index.html

## Troubleshooting

### Jenkins won't start
```powershell
docker logs jenkins
```

### Pipeline fails to run
1. Check Jenkins console output
2. Verify Azure credentials are correct
3. Check Docker is running: `docker ps`

### Azure CLI not found in pipeline
```powershell
docker exec jenkins bash -c "which az"
```

If not installed, add to pipeline:
```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | bash
```

## Stop/Remove Jenkins

```powershell
# Stop
docker stop jenkins

# Remove
docker rm jenkins

# Remove volume (deletes all data)
docker volume rm jenkins_home
```

## Backup Jenkins Configuration

```powershell
docker exec jenkins tar czf /tmp/jenkins_backup.tar.gz /var/jenkins_home
docker cp jenkins:/tmp/jenkins_backup.tar.gz ./jenkins_backup.tar.gz
```

---

**Status:** ✅ Ready for production
**Cost:** Free (self-hosted)
**Build Time:** ~10-15 minutes per deployment
