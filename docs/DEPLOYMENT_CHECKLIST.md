# Deployment Checklist

## Pre-Deployment Preparation

### Environment Setup
- [ ] Install Node.js 18+
- [ ] Install .NET 8 SDK
- [ ] Install SQL Server 2019+
- [ ] Install Azure CLI
- [ ] Install Docker & Docker Compose (optional)
- [ ] Install Visual Studio Code
- [ ] Install SQL Server Management Studio

### Repository Setup
- [ ] Clone/download the project
- [ ] Initialize git repository
- [ ] Configure git user
- [ ] Create .gitignore (provided)

---

## Phase 1: Local Development

### Database Setup
- [ ] Verify SQL Server is running
- [ ] Open SQL Server Management Studio
- [ ] Execute database creation script
- [ ] Verify database "RegistrationAppDb" exists
- [ ] Check Items table created
- [ ] Verify stored procedures created

### Backend Setup
- [ ] Navigate to backend folder
- [ ] Run `dotnet restore`
- [ ] Update connection string in appsettings.json
- [ ] Run `dotnet ef database update`
- [ ] Verify migrations applied
- [ ] Run `dotnet run`
- [ ] Test API at http://localhost:5000
- [ ] Access Swagger at http://localhost:5000/swagger

### Frontend Setup
- [ ] Navigate to frontend folder
- [ ] Run `npm install`
- [ ] Update API URL in item.service.ts
- [ ] Run `ng serve`
- [ ] Access app at http://localhost:4200
- [ ] Test add/delete items
- [ ] Verify items appear in browser console

### Integration Testing
- [ ] Add an item from frontend
- [ ] Verify it appears in the list
- [ ] Refresh the page
- [ ] Verify item persists (from database)
- [ ] Delete an item
- [ ] Verify it's removed from database
- [ ] Test with multiple items

---

## Phase 2: Docker Deployment (Optional)

### Docker Setup
- [ ] Install Docker Desktop
- [ ] Start Docker service
- [ ] Verify docker-compose.yml
- [ ] Update SQL password in docker-compose.yml
- [ ] Run `docker-compose up`
- [ ] Wait for all containers to start
- [ ] Verify container health

### Docker Testing
- [ ] Access frontend at http://localhost
- [ ] Access backend at http://localhost:5000
- [ ] Test API endpoints
- [ ] Test frontend functionality
- [ ] Verify database persistence
- [ ] Run `docker-compose down`

---

## Phase 3: Azure Preparation

### Azure Account Setup
- [ ] Create/verify Azure subscription
- [ ] Verify subscription access
- [ ] Install Azure CLI
- [ ] Run `az login`
- [ ] Verify correct subscription selected

### Azure Infrastructure
- [ ] Edit setup script with your parameters
- [ ] Review script before running
- [ ] Run setup script
- [ ] Note resource names created
- [ ] Verify resources in Azure Portal
  - [ ] Resource Group
  - [ ] SQL Server
  - [ ] SQL Database
  - [ ] App Service Plan
  - [ ] Key Vault

### Key Vault Configuration
- [ ] Verify connection string in Key Vault
- [ ] Create deployment credentials
- [ ] Note Key Vault URI
- [ ] Grant app permissions

---

## Phase 4: Azure DevOps Setup

### DevOps Project Creation
- [ ] Go to dev.azure.com
- [ ] Create new organization (if needed)
- [ ] Create new project
- [ ] Name project "RegistrationApp"
- [ ] Set visibility to Private

### Repository Setup
- [ ] Initialize git repository locally
- [ ] Add all project files
- [ ] Commit changes
- [ ] Connect to Azure DevOps
- [ ] Push to remote

### Pipeline Configuration
- [ ] Copy azure-pipelines.yml to root
- [ ] Create new pipeline in Azure DevOps
- [ ] Select GitHub/Azure Repos
- [ ] Select this repository
- [ ] Review YAML pipeline
- [ ] Create/grant pipeline permissions
- [ ] Configure service connection
- [ ] Set pipeline variables

### Variable Groups
- [ ] Create variable group in DevOps
- [ ] Add backend app names
- [ ] Add frontend URLs
- [ ] Add SQL credentials
- [ ] Mark sensitive values as secrets
- [ ] Grant pipeline access

### Build Pipeline
- [ ] Verify YAML syntax
- [ ] Run manual build
- [ ] Check build logs
- [ ] Verify artifacts created
- [ ] Check frontend build output
- [ ] Check backend publish output

---

## Phase 5: Backend Deployment

### Prepare Backend
- [ ] Build backend: `dotnet publish -c Release`
- [ ] Verify publish folder created
- [ ] Check for all necessary files
- [ ] Verify configuration files

### Deploy to Staging
- [ ] Deploy via Azure Portal or CLI
- [ ] Configure connection string
- [ ] Set environment variables
- [ ] Apply database migrations
- [ ] Test API endpoints
- [ ] Check Application Insights logs
- [ ] Verify all CRUD operations

### Deploy to Production
- [ ] Get approval (if required)
- [ ] Deploy to production
- [ ] Run post-deployment tests
- [ ] Monitor error logs
- [ ] Verify performance
- [ ] Test high load (if applicable)

---

## Phase 6: Frontend Deployment

### Prepare Frontend
- [ ] Build frontend: `npm run build`
- [ ] Update environment.prod.ts with production API URL
- [ ] Verify dist folder created
- [ ] Check file sizes

### Deploy to Staging
- [ ] Deploy to staging Static Web App
- [ ] Test all pages
- [ ] Verify API calls work
- [ ] Check browser console for errors
- [ ] Test on multiple browsers
- [ ] Test on mobile devices

### Deploy to Production
- [ ] Deploy to production Static Web App
- [ ] Run smoke tests
- [ ] Verify custom domain (if configured)
- [ ] Check SSL certificate
- [ ] Monitor error logs

---

## Phase 7: Post-Deployment Verification

### API Testing
- [ ] Test GET /api/items
- [ ] Test POST /api/items
- [ ] Test PUT /api/items/{id}
- [ ] Test DELETE /api/items/{id}
- [ ] Test error scenarios
- [ ] Verify response formats
- [ ] Check error messages

### UI Testing
- [ ] Load frontend in browser
- [ ] Test add item functionality
- [ ] Test item list display
- [ ] Test delete item
- [ ] Test error handling
- [ ] Test loading states
- [ ] Test responsive design

### Database Testing
- [ ] Verify items in database
- [ ] Check data integrity
- [ ] Verify timestamps
- [ ] Check indexes working

### Performance Testing
- [ ] Check response times
- [ ] Monitor CPU usage
- [ ] Monitor memory usage
- [ ] Check database query times
- [ ] Verify caching working

---

## Phase 8: Monitoring & Logging

### Application Insights
- [ ] Application Insights configured
- [ ] Telemetry being collected
- [ ] Check metrics dashboard
- [ ] Review performance counters
- [ ] Check error rates

### Logging
- [ ] Backend logging working
- [ ] Frontend console logging working
- [ ] Database audit logging working
- [ ] Log levels appropriate
- [ ] No sensitive data in logs

### Alerts
- [ ] Set up error alerts
- [ ] Set up performance alerts
- [ ] Configure email notifications
- [ ] Test alert triggering

---

## Phase 9: Security Verification

### HTTPS/TLS
- [ ] All traffic is HTTPS
- [ ] No mixed content warnings
- [ ] SSL certificate valid
- [ ] Certificate auto-renewal configured

### Authentication
- [ ] CORS properly configured
- [ ] No unnecessary public endpoints
- [ ] Rate limiting working
- [ ] Input validation working

### Database Security
- [ ] Firewall rules configured
- [ ] Connection string secured
- [ ] No SQL injection vulnerabilities
- [ ] Audit logging enabled
- [ ] Encryption at rest enabled

### Key Vault
- [ ] Secrets properly stored
- [ ] Access policies configured
- [ ] Managed Identity working
- [ ] No credentials in code

---

## Phase 10: Backup & Recovery

### Backup Configuration
- [ ] SQL Database backup enabled
- [ ] Retention period set (90 days minimum)
- [ ] Geo-redundancy enabled
- [ ] Test restore procedure

### Disaster Recovery
- [ ] Recovery plan documented
- [ ] Failover procedure tested
- [ ] RTO/RPO defined
- [ ] Contact list prepared

---

## Phase 11: Documentation

### Update Documentation
- [ ] Update API documentation
- [ ] Update deployment guide
- [ ] Update security documentation
- [ ] Update troubleshooting guide
- [ ] Update team runbooks

### Team Training
- [ ] Train team on deployment process
- [ ] Document known issues
- [ ] Create troubleshooting guide
- [ ] Document support contacts

---

## Phase 12: Post-Launch

### Monitoring
- [ ] Monitor error logs (1 week)
- [ ] Monitor performance metrics (1 week)
- [ ] Monitor user feedback
- [ ] Check Application Insights daily

### Optimization
- [ ] Review slow queries
- [ ] Optimize performance
- [ ] Adjust thresholds
- [ ] Fine-tune auto-scaling

### Maintenance
- [ ] Plan regular backups
- [ ] Schedule security updates
- [ ] Plan dependency updates
- [ ] Schedule maintenance windows

---

## Rollback Procedures

### Quick Rollback
- [ ] Previous version in artifact storage
- [ ] Rollback procedure documented
- [ ] Database backup available
- [ ] Test rollback in staging first

### Communication
- [ ] Prepare rollback communication
- [ ] Alert key stakeholders
- [ ] Document issues encountered
- [ ] Schedule post-mortem

---

## Success Criteria

✅ **Must Have**
- [ ] Application accessible
- [ ] All CRUD operations working
- [ ] Database persists data
- [ ] No error messages in logs
- [ ] HTTPS working
- [ ] Responsive design working

✅ **Should Have**
- [ ] Performance acceptable
- [ ] Monitoring configured
- [ ] Security measures active
- [ ] Documentation complete
- [ ] Team trained

✅ **Nice to Have**
- [ ] Advanced monitoring
- [ ] Custom domain
- [ ] Analytics tracking
- [ ] CDN configured
- [ ] Auto-scaling optimized

---

## Sign-Off

### QA Sign-Off
- [ ] QA testing complete
- [ ] No critical issues
- [ ] Performance acceptable
- [ ] Security verified

**QA Lead:** _________________ **Date:** _________

### Operations Sign-Off
- [ ] Deployment complete
- [ ] Monitoring active
- [ ] Backup configured
- [ ] Support ready

**Ops Lead:** _________________ **Date:** _________

### Business Sign-Off
- [ ] Requirements met
- [ ] Stakeholder approval
- [ ] Go-live approved

**Business Owner:** _________________ **Date:** _________

---

## Post-Launch Support

### 24-Hour Support
- [ ] Team available
- [ ] Contact list shared
- [ ] Escalation process defined

### Weekly Reviews
- [ ] Performance review
- [ ] Error log review
- [ ] User feedback review
- [ ] Optimization planning

---

**Deployment Date:** ________________

**Deployed By:** ________________

**Notes:** _________________________________________________________________

_________________________________________________________________________

_________________________________________________________________________

---

**Congratulations on your deployment! 🎉**
