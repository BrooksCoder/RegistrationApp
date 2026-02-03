# Azure Trial Subscription - Quota Limit Issue

## What's Happening

Your Azure trial subscription has **zero quota for Basic VMs (B2 tier)**.

```
Error: Operation cannot be completed without additional quota
Current Limit (Basic VMs): 0
Amount required: 1
```

---

## Solution Options

### Option 1: Use Free Tier (Recommended for Trial) ✅

The **Free tier is completely free** and works for development:

```powershell
$resourceGroup = "rg-registration-app"
$suffix = "2807"
$location = "eastus"

# Create FREE App Service Plan (no B2, just use Free)
az appservice plan create `
  --name "registration-api-plan-$suffix" `
  --resource-group $resourceGroup `
  --location $location `
  --sku FREE `
  --is-linux

# Rest of commands stay the same...
az webapp create `
  --name "registration-api-$suffix" `
  --resource-group $resourceGroup `
  --plan "registration-api-plan-$suffix" `
  --runtime "DOTNET|8.0"
```

**Pros:** Free, no quota needed
**Cons:** Slower performance, not for production

---

### Option 2: Request Quota Increase (Takes 24-48 hours)

#### Step 1: Go to Azure Portal
1. Open: https://portal.azure.com
2. Search for: **"Quotas"**
3. Click: **Quotas**

#### Step 2: Find Compute Quotas
1. Select: **Compute**
2. Filter by location: Your region (eastus)
3. Find: **"Cores - Basic VMs"** or **"App Service Plans"**

#### Step 3: Request Increase
1. Check the checkbox next to it
2. Click: **"Request quota increase"**
3. Set new limit: **1** (or higher)
4. Click: **"Submit"**

You'll get an email when approved (usually 24-48 hours).

---

### Option 3: Use B1 Tier (Cheapest Paid - ~$12/month)

If free tier is too slow:

```powershell
# Use B1 instead of B2
az appservice plan create `
  --name "registration-api-plan-$suffix" `
  --resource-group $resourceGroup `
  --location $location `
  --sku B1 `
  --is-linux
```

This might work if you have B1 quota available.

---

## Quick Fix: Use Free Tier

Replace the B2 command with:

```powershell
$resourceGroup = "rg-registration-app"
$suffix = "2807"
$location = "eastus"

Write-Host "Creating resources with FREE tier..." -ForegroundColor Green

# 1. App Service Plan - FREE tier
az appservice plan create `
  --name "registration-api-plan-$suffix" `
  --resource-group $resourceGroup `
  --location $location `
  --sku FREE `
  --is-linux

Write-Host "✅ App Service Plan created (FREE)"

# 2. App Service
az webapp create `
  --name "registration-api-$suffix" `
  --resource-group $resourceGroup `
  --plan "registration-api-plan-$suffix" `
  --runtime "DOTNET|8.0"

Write-Host "✅ App Service created"

# 3. Static Web App - FREE tier
az staticwebapp create `
  --name "registration-frontend-$suffix" `
  --resource-group $resourceGroup `
  --location $location `
  --sku Free

Write-Host "✅ Static Web App created"

# 4. SQL Server
az sql server create `
  --name "regsql$suffix" `
  --resource-group $resourceGroup `
  --location $location `
  --admin-user "sqladmin" `
  --admin-password "YourSecurePassword123!@#"

Write-Host "✅ SQL Server created"

# 5. SQL Database - Basic tier (usually free quota)
az sql db create `
  --name "RegistrationAppDb" `
  --server "regsql$suffix" `
  --resource-group $resourceGroup `
  --sku Basic

WriteHost "✅ SQL Database created"

# 6. Firewall
az sql server firewall-rule create `
  --resource-group $resourceGroup `
  --server "regsql$suffix" `
  --name "AllowAzureServices" `
  --start-ip-address 0.0.0.0 `
  --end-ip-address 0.0.0.0

Write-Host "✅ Firewall configured"

# 7. Configure App Service
$connString = "Server=tcp:regsql$suffix.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourSecurePassword123!@#;Encrypt=True;Connection Timeout=30;"
az webapp config appsettings set `
  --resource-group $resourceGroup `
  --name "registration-api-$suffix" `
  --settings `
    ConnectionStrings__DefaultConnection="$connString" `
    ASPNETCORE_ENVIRONMENT="Production"

Write-Host "✅ All resources created successfully!"
```

---

## Available Tiers for Trial Subscription

| Tier | Cost | Quota Issue | Use Case |
|------|------|-------------|----------|
| **FREE** | $0 | ✅ No quota limit | Development, Trial |
| **B1** | ~$12/month | ⚠️ May need quota | Light production |
| **B2** | ~$50/month | ❌ Quota limited | Standard production |
| **B3** | ~$100/month | ❌ Quota limited | Heavy production |

---

## Trial Subscription Limits

Your trial account has:
- **Compute quota:** Limited (that's the issue)
- **Total spending limit:** $200 credit
- **Duration:** 12 months

**Best approach:** Use FREE tier for development on trial!

---

## Free Tier Limitations

```
FREE App Service Plan:

✅ Can do:
- Run Angular + .NET Core apps
- Use SQL Database
- Deploy Docker containers
- Use 1 GB storage
- 60 minutes of compute per day

❌ Cannot do:
- Custom domains (only *.azurewebsites.net)
- SSL certificates
- Always-on deployment
- Scaling to multiple instances
```

For your development needs, FREE tier is perfect! 🚀

---

## Complete Solution: Use FREE + SQL Basic

```powershell
# This will work on trial subscription
$resourceGroup = "rg-registration-app"
$suffix = "2807"
$location = "eastus"

# All commands with FREE/compatible tiers
az appservice plan create --name "registration-api-plan-$suffix" --resource-group $resourceGroup --location $location --sku FREE --is-linux
az webapp create --name "registration-api-$suffix" --resource-group $resourceGroup --plan "registration-api-plan-$suffix" --runtime "DOTNET|8.0"
az staticwebapp create --name "registration-frontend-$suffix" --resource-group $resourceGroup --location $location --sku Free
az sql server create --name "regsql$suffix" --resource-group $resourceGroup --location $location --admin-user "sqladmin" --admin-password "YourSecurePassword123!@#"
az sql db create --name "RegistrationAppDb" --server "regsql$suffix" --resource-group $resourceGroup --sku Basic
az sql server firewall-rule create --resource-group $resourceGroup --server "regsql$suffix" --name "AllowAzureServices" --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0

$connString = "Server=tcp:regsql$suffix.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourSecurePassword123!@#;Encrypt=True;Connection Timeout=30;"
az webapp config appsettings set --resource-group $resourceGroup --name "registration-api-$suffix" --settings ConnectionStrings__DefaultConnection="$connString" ASPNETCORE_ENVIRONMENT="Production"

Write-Host "✅ All resources created with FREE/Basic tiers!"
```

---

## After Resources Are Created

1. Get the resource names
2. Update `azure-pipelines.yml`
3. Commit and push
4. Pipeline deploys (FREE tier works fine for CI/CD testing)

---

## When You Upgrade

When you move from trial to paid subscription:
1. You get full quota
2. Upgrade App Service Plan to B1/B2
3. Better performance and always-on

For now, **FREE tier is perfect for development!** ✅

---

## Verify Trial Subscription

```powershell
# Check your subscription
az account show --query "{Name:name, SubscriptionId:id, OfferingId:id}"

# See your quota
az vm list-usage --location eastus --output table
```

---

## Summary

**For Trial Subscription:**
- ✅ Use FREE tier (no quota issues)
- ✅ Use Basic SQL (no quota issues)
- ✅ Perfect for development/testing
- ⏭️ Upgrade to paid for better performance

**Copy the command above and run it!** 🚀
