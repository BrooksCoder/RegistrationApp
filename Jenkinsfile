pipeline {
    agent any

    parameters {
        string(name: 'BRANCH', defaultValue: 'main', description: 'Git branch to build')
        booleanParam(name: 'DEPLOY_BACKEND', defaultValue: true, description: 'Deploy backend?')
        booleanParam(name: 'DEPLOY_FRONTEND', defaultValue: true, description: 'Deploy frontend?')
    }
    
    environment {
        DOCKER_REGISTRY = 'registrationappacr.azurecr.io'
        ACR_NAME = 'registrationappacr'
        RESOURCE_GROUP = 'rg-registration-app'
        DOCKER_IMAGE_BACKEND = "${DOCKER_REGISTRY}/registration-api"
        DOCKER_IMAGE_FRONTEND = "${DOCKER_REGISTRY}/registration-frontend"
        BUILD_TAG = "${BUILD_NUMBER}"
        GIT_REPO = "https://github.com/BrooksCoder/RegistrationApp.git"
        
        AZURE_CLIENT_ID = credentials('AZURE_CLIENT_ID')
        AZURE_CLIENT_SECRET = credentials('AZURE_CLIENT_SECRET')
        AZURE_TENANT_ID = credentials('AZURE_TENANT_ID')
        AZURE_SUBSCRIPTION_ID = credentials('AZURE_SUBSCRIPTION_ID')
        KEYVAULT_NAME = 'kv-registrationapp'
        
        WORKSPACE_REPO = "${WORKSPACE}/repo"
        ENV_FILE = "${WORKSPACE}/env.properties"
        DEPLOY_FILE = "${WORKSPACE}/deployment.properties"
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
    }

    stages {
        stage('Initialize') {
            steps {
                echo '════════════════════════════════════════'
                echo '▶ STAGE: Initialize Pipeline'
                echo '════════════════════════════════════════'
                sh '''
                    echo "Jenkins Workspace: ${WORKSPACE}"
                    echo "Build Number: ${BUILD_NUMBER}"
                    rm -f ${ENV_FILE} ${DEPLOY_FILE}
                    echo "✓ Initialization complete"
                '''
            }
        }

        stage('Clone Repository') {
            steps {
                echo '════════════════════════════════════════'
                echo '▶ STAGE: Clone Repository'
                echo '════════════════════════════════════════'
                sh '''
                    echo "Cloning branch: ${BRANCH}"
                    rm -rf ${WORKSPACE_REPO}
                    git clone -b ${BRANCH} https://github.com/BrooksCoder/RegistrationApp.git ${WORKSPACE_REPO}
                    cd ${WORKSPACE_REPO}
            steps {
                echo '════════════════════════════════════════'
                echo '▶ STAGE: Azure Authentication'
                echo '════════════════════════════════════════'
                sh '''
                    echo "Authenticating with Azure..."
                    az login --service-principal \
                        -u ${AZURE_CLIENT_ID} \
                        -p ${AZURE_CLIENT_SECRET} \
                        --tenant ${AZURE_TENANT_ID}
                    
                    az account set --subscription ${AZURE_SUBSCRIPTION_ID}
                    echo "✓ Successfully logged into Azure"
                '''
            }
        }

        stage('Retrieve Secrets from Key Vault') {
            steps {
                echo '════════════════════════════════════════'
                echo '▶ STAGE: Retrieve Secrets from Key Vault'
                echo '════════════════════════════════════════'
                sh '''
                    echo "Retrieving secrets from Key Vault: ${KEYVAULT_NAME}"
                    
                    SQL_CONN_STR=$(az keyvault secret show --vault-name ${KEYVAULT_NAME} --name "SqlConnectionString" --query value -o tsv)
                    echo "export SQL_CONN_STR='$SQL_CONN_STR'" >> ${ENV_FILE}
                    
                    SB_CONN_STR=$(az keyvault secret show --vault-name ${KEYVAULT_NAME} --name "ServiceBusConnectionString" --query value -o tsv)
                    echo "export SB_CONN_STR='$SB_CONN_STR'" >> ${ENV_FILE}
                    
                    COSMOS_CONN_STR=$(az keyvault secret show --vault-name ${KEYVAULT_NAME} --name "CosmosDbConnectionString" --query value -o tsv)
                    echo "export COSMOS_CONN_STR='$COSMOS_CONN_STR'" >> ${ENV_FILE}
                    
                    APP_INSIGHTS_KEY=$(az keyvault secret show --vault-name ${KEYVAULT_NAME} --name "ApplicationInsightsInstrumentationKey" --query value -o tsv)
                    echo "export APP_INSIGHTS_KEY='$APP_INSIGHTS_KEY'" >> ${ENV_FILE}
                    
                    SP_CLIENT_ID=$(az keyvault secret show --vault-name ${KEYVAULT_NAME} --name "ServicePrincipalClientId" --query value -o tsv)
                    echo "export SP_CLIENT_ID='$SP_CLIENT_ID'" >> ${ENV_FILE}
                    
                    SP_CLIENT_SECRET=$(az keyvault secret show --vault-name ${KEYVAULT_NAME} --name "ServicePrincipalClientSecret" --query value -o tsv)
                    echo "export SP_CLIENT_SECRET='$SP_CLIENT_SECRET'" >> ${ENV_FILE}
                    
                    SP_TENANT_ID=$(az keyvault secret show --vault-name ${KEYVAULT_NAME} --name "ServicePrincipalTenantId" --query value -o tsv)
                    echo "export SP_TENANT_ID='$SP_TENANT_ID'" >> ${ENV_FILE}
                    
                    echo "✓ All secrets retrieved successfully"
                '''
            }
        }

        stage('Build Backend') {
            when {
                expression { params.DEPLOY_BACKEND == true }
            }
            steps {
                echo '════════════════════════════════════════'
                echo '▶ STAGE: Build Backend Docker Image'
                echo '════════════════════════════════════════'
                sh '''
                    cd ${WORKSPACE_REPO}
                    echo "Building backend image: ${DOCKER_IMAGE_BACKEND}:${BUILD_TAG}"
                    docker build -f backend/Dockerfile \
                        -t ${DOCKER_IMAGE_BACKEND}:${BUILD_TAG} \
                        -t ${DOCKER_IMAGE_BACKEND}:latest \
                        ./backend
                    echo "✓ Backend image built successfully"
                '''
            }
        }

        stage('Build Frontend') {
            when {
                expression { params.DEPLOY_FRONTEND == true }
            }
            steps {
                echo '════════════════════════════════════════'
                echo '▶ STAGE: Build Frontend Docker Image'
                echo '════════════════════════════════════════'
                sh '''
                    cd ${WORKSPACE_REPO}
                    echo "Building frontend image: ${DOCKER_IMAGE_FRONTEND}:${BUILD_TAG}"
                    docker build -f frontend/Dockerfile \
                        --build-arg BACKEND_URL=http://registration-api-prod.centralindia.azurecontainer.io \
                        -t ${DOCKER_IMAGE_FRONTEND}:${BUILD_TAG} \
                        -t ${DOCKER_IMAGE_FRONTEND}:latest \
                        ./frontend
                    echo "✓ Frontend image built successfully"
                '''
            }
        }

        stage('Login to ACR') {
            steps {
                echo '════════════════════════════════════════'
                echo '▶ STAGE: Login to Azure Container Registry'
                echo '════════════════════════════════════════'
                sh '''
                    echo "Logging in to ACR: ${ACR_NAME}"
                    az acr login --name ${ACR_NAME}
                    echo "✓ Successfully logged into ACR"
                '''
            }
        }

        stage('Push Backend Image') {
            when {
                expression { params.DEPLOY_BACKEND == true }
            }
            steps {
                echo '════════════════════════════════════════'
                echo '▶ STAGE: Push Backend Image to ACR'
                echo '════════════════════════════════════════'
                sh '''
                    echo "Pushing backend image..."
                    docker push ${DOCKER_IMAGE_BACKEND}:${BUILD_TAG}
                    docker push ${DOCKER_IMAGE_BACKEND}:latest
                    echo "✓ Backend image pushed successfully"
                '''
            }
        }

        stage('Push Frontend Image') {
            when {
                expression { params.DEPLOY_FRONTEND == true }
            }
            steps {
                echo '════════════════════════════════════════'
                echo '▶ STAGE: Push Frontend Image to ACR'
                echo '════════════════════════════════════════'
                sh '''
                    echo "Pushing frontend image..."
                    docker push ${DOCKER_IMAGE_FRONTEND}:${BUILD_TAG}
                    docker push ${DOCKER_IMAGE_FRONTEND}:latest
                    echo "✓ Frontend image pushed successfully"
                '''
            }
        }

        stage('Deploy Backend') {
            when {
                expression { params.DEPLOY_BACKEND == true }
            }
            steps {
                echo '════════════════════════════════════════'
                echo '▶ STAGE: Deploy Backend Container'
                echo '════════════════════════════════════════'
                sh '''
                    . ${ENV_FILE}
                    
                    ACR_USER=$(az acr credential show --resource-group ${RESOURCE_GROUP} --name ${ACR_NAME} --query username -o tsv)
                    ACR_PASS=$(az acr credential show --resource-group ${RESOURCE_GROUP} --name ${ACR_NAME} --query "passwords[0].value" -o tsv)
                    
                    az container delete --resource-group ${RESOURCE_GROUP} --name registration-api-prod --yes 2>/dev/null || true
                    sleep 5
                    
                    az container create \
                        --resource-group ${RESOURCE_GROUP} \
                        --name registration-api-prod \
                        --image ${DOCKER_IMAGE_BACKEND}:${BUILD_TAG} \
                        --cpu 1 \
                        --memory 1.5 \
                        --os-type Linux \
                        --registry-login-server ${DOCKER_REGISTRY} \
                        --registry-username "$ACR_USER" \
                        --registry-password "$ACR_PASS" \
                        --ports 80 \
                        --dns-name-label "registration-api-prod" \
                        --location centralindia \
                        --restart-policy OnFailure \
                        --environment-variables \
                            ASPNETCORE_ENVIRONMENT=Production \
                            'ASPNETCORE_URLS=http://+:80' \
                            "AZURE_CLIENT_ID=$SP_CLIENT_ID" \
                            "AZURE_CLIENT_SECRET=$SP_CLIENT_SECRET" \
                            "AZURE_TENANT_ID=$SP_TENANT_ID" \
                            "ConnectionStrings__DefaultConnection=$SQL_CONN_STR" \
                            "ConnectionStrings__ServiceBus=$SB_CONN_STR" \
                            "ConnectionStrings__CosmosDb=$COSMOS_CONN_STR" \
                            'AzureKeyVault__VaultUri=https://kv-registrationapp.vault.azure.net/' \
                            "APPLICATIONINSIGHTS_INSTRUMENTATION_KEY=$APP_INSIGHTS_KEY"
                    
                    sleep 20
                    BACKEND_URL=$(az container show --resource-group ${RESOURCE_GROUP} --name registration-api-prod --query ipAddress.fqdn -o tsv)
                    echo "BACKEND_URL=$BACKEND_URL" >> ${DEPLOY_FILE}
                    echo "✓ Backend deployed at: http://$BACKEND_URL"
                '''
            }
        }

        stage('Deploy Frontend') {
            when {
                expression { params.DEPLOY_FRONTEND == true }
            }
            steps {
                echo '════════════════════════════════════════'
                echo '▶ STAGE: Deploy Frontend Container'
                echo '════════════════════════════════════════'
                sh '''
                    BACKEND_URL="registration-api-prod.centralindia.azurecontainer.io"
                    if [ -f "${DEPLOY_FILE}" ]; then
                        EXTRACTED_URL=$(grep BACKEND_URL ${DEPLOY_FILE} | cut -d'=' -f2 | tr -d '\r')
                        if [ ! -z "$EXTRACTED_URL" ]; then
                            BACKEND_URL="$EXTRACTED_URL"
                        fi
                    fi
                    
                    ACR_USER=$(az acr credential show --resource-group ${RESOURCE_GROUP} --name ${ACR_NAME} --query username -o tsv)
                    ACR_PASS=$(az acr credential show --resource-group ${RESOURCE_GROUP} --name ${ACR_NAME} --query "passwords[0].value" -o tsv)
                    
                    az container delete --resource-group ${RESOURCE_GROUP} --name registration-frontend-prod --yes 2>/dev/null || true
                    sleep 5
                    
                    az container create \
                        --resource-group ${RESOURCE_GROUP} \
                        --name registration-frontend-prod \
                        --image ${DOCKER_IMAGE_FRONTEND}:${BUILD_TAG} \
                        --cpu 0.5 \
                        --memory 1 \
                        --os-type Linux \
                        --registry-login-server ${DOCKER_REGISTRY} \
                        --registry-username "$ACR_USER" \
                        --registry-password "$ACR_PASS" \
                        --ports 80 \
                        --dns-name-label "registration-frontend-prod" \
                        --location centralindia \
                        --restart-policy OnFailure \
                        --environment-variables \
                            'NODE_ENV=production' \
                            "BACKEND_URL=http://$BACKEND_URL" \
                            "REACT_APP_BACKEND_URL=http://$BACKEND_URL" \
                            "REACT_APP_API_BASE_URL=http://$BACKEND_URL"
                    
                    sleep 20
                    FRONTEND_URL=$(az container show --resource-group ${RESOURCE_GROUP} --name registration-frontend-prod --query ipAddress.fqdn -o tsv)
                    echo "FRONTEND_URL=$FRONTEND_URL" >> ${DEPLOY_FILE}
                    echo "✓ Frontend deployed at: http://$FRONTEND_URL"
                '''
            }
        }

        stage('Verify Deployment') {
            steps {
                echo '════════════════════════════════════════'
                echo '▶ STAGE: Verify Deployment'
                echo '════════════════════════════════════════'
                sh '''
                    BACKEND_URL="registration-api-prod.centralindia.azurecontainer.io"
                    FRONTEND_URL="registration-frontend-prod.centralindia.azurecontainer.io"
                    
                    if [ -f "${DEPLOY_FILE}" ]; then
                        EXTRACTED_BACKEND=$(grep BACKEND_URL ${DEPLOY_FILE} | cut -d'=' -f2 | tr -d '\r')
                        EXTRACTED_FRONTEND=$(grep FRONTEND_URL ${DEPLOY_FILE} | cut -d'=' -f2 | tr -d '\r')
                        [ ! -z "$EXTRACTED_BACKEND" ] && BACKEND_URL="$EXTRACTED_BACKEND"
                        [ ! -z "$EXTRACTED_FRONTEND" ] && FRONTEND_URL="$EXTRACTED_FRONTEND"
                    fi
                    
                    echo "Waiting for containers to initialize (30 seconds)..."
                    sleep 30
                    
                    echo ""
                    echo "========== DEPLOYMENT SUMMARY =========="
                    echo "Frontend:  http://$FRONTEND_URL"
                    echo "Backend:   http://$BACKEND_URL"
                    echo "API:       http://$BACKEND_URL/api/Items"
                    echo "Swagger:   http://$BACKEND_URL/swagger/index.html"
                    echo "========================================"
                '''
            }
        }
    }

    post {
        always {
            echo 'Pipeline execution completed'
            sh '''
                if [ -f "${DEPLOY_FILE}" ]; then
                    echo ""
                    echo "Deployment Details:"
                    cat ${DEPLOY_FILE}
                fi
            '''
        }
        success {
            echo '✓✓✓ Pipeline completed successfully! ✓✓✓'
        }
        failure {
            echo '✗ Pipeline failed!'
            sh '''
                az container logs --resource-group ${RESOURCE_GROUP} --name registration-api-prod 2>/dev/null || true
            '''
        }
    }
}