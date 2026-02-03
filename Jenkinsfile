pipeline {
    agent {
        docker {
            image 'docker:latest'
            args '-v /var/run/docker.sock:/var/run/docker.sock'
        }
    }

    environment {
        DOCKER_REGISTRY = 'registrationappacr.azurecr.io'
        ACR_NAME = 'registrationappacr'
        RESOURCE_GROUP = 'rg-registration-app'
        DOCKER_IMAGE_BACKEND = "${DOCKER_REGISTRY}/registration-api"
        DOCKER_IMAGE_FRONTEND = "${DOCKER_REGISTRY}/registration-frontend"
        BUILD_TAG = "${BUILD_NUMBER}"
    }

    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out code...'
                checkout scm
            }
        }

        stage('Build Backend') {
            steps {
                echo 'Building backend Docker image...'
                script {
                    sh '''
                        docker build -f backend/Dockerfile \
                            -t ${DOCKER_IMAGE_BACKEND}:${BUILD_TAG} \
                            -t ${DOCKER_IMAGE_BACKEND}:latest \
                            ./backend
                        echo "Backend image built: ${DOCKER_IMAGE_BACKEND}:${BUILD_TAG}"
                    '''
                }
            }
        }

        stage('Build Frontend') {
            steps {
                echo 'Building frontend Docker image...'
                script {
                    sh '''
                        docker build -f frontend/Dockerfile \
                            -t ${DOCKER_IMAGE_FRONTEND}:${BUILD_TAG} \
                            -t ${DOCKER_IMAGE_FRONTEND}:latest \
                            ./frontend
                        echo "Frontend image built: ${DOCKER_IMAGE_FRONTEND}:${BUILD_TAG}"
                    '''
                }
            }
        }

        stage('Login to ACR') {
            steps {
                echo 'Logging into Azure Container Registry...'
                script {
                    sh '''
                        az acr login --name ${ACR_NAME}
                    '''
                }
            }
        }

        stage('Push Backend Image') {
            steps {
                echo 'Pushing backend image to ACR...'
                script {
                    sh '''
                        docker push ${DOCKER_IMAGE_BACKEND}:${BUILD_TAG}
                        docker push ${DOCKER_IMAGE_BACKEND}:latest
                        echo "Backend image pushed successfully"
                    '''
                }
            }
        }

        stage('Push Frontend Image') {
            steps {
                echo 'Pushing frontend image to ACR...'
                script {
                    sh '''
                        docker push ${DOCKER_IMAGE_FRONTEND}:${BUILD_TAG}
                        docker push ${DOCKER_IMAGE_FRONTEND}:latest
                        echo "Frontend image pushed successfully"
                    '''
                }
            }
        }

        stage('Deploy Backend') {
            steps {
                echo 'Deploying backend container...'
                script {
                    sh '''
                        # Get ACR credentials
                        ACR_USER=$(az acr credential show --resource-group ${RESOURCE_GROUP} --name ${ACR_NAME} --query username -o tsv)
                        ACR_PASS=$(az acr credential show --resource-group ${RESOURCE_GROUP} --name ${ACR_NAME} --query "passwords[0].value" -o tsv)
                        
                        # Delete old container
                        az container delete --resource-group ${RESOURCE_GROUP} --name registration-api-prod --yes 2>/dev/null || true
                        
                        # Deploy new container
                        az container create \
                            --resource-group ${RESOURCE_GROUP} \
                            --name registration-api-prod \
                            --image ${DOCKER_IMAGE_BACKEND}:${BUILD_TAG} \
                            --cpu 1 \
                            --memory 1 \
                            --os-type Linux \
                            --registry-login-server ${DOCKER_REGISTRY} \
                            --registry-username $ACR_USER \
                            --registry-password $ACR_PASS \
                            --ports 80 \
                            --dns-name-label "registration-api-prod" \
                            --location centralindia \
                            --environment-variables ASPNETCORE_ENVIRONMENT=Production "ConnectionStrings__DefaultConnection=Server=tcp:regsql2807.database.windows.net,1433;Initial Catalog=RegistrationAppDb;Persist Security Info=False;User ID=sqladmin;Password=YourSecurePassword123!@#;Encrypt=True;Connection Timeout=30;"
                        
                        sleep 5
                        BACKEND_URL=$(az container show --resource-group ${RESOURCE_GROUP} --name registration-api-prod --query ipAddress.fqdn -o tsv)
                        echo "Backend deployed at: http://$BACKEND_URL"
                    '''
                }
            }
        }

        stage('Deploy Frontend') {
            steps {
                echo 'Deploying frontend container...'
                script {
                    sh '''
                        # Get ACR credentials
                        ACR_USER=$(az acr credential show --resource-group ${RESOURCE_GROUP} --name ${ACR_NAME} --query username -o tsv)
                        ACR_PASS=$(az acr credential show --resource-group ${RESOURCE_GROUP} --name ${ACR_NAME} --query "passwords[0].value" -o tsv)
                        
                        # Get backend URL
                        BACKEND_URL=$(az container show --resource-group ${RESOURCE_GROUP} --name registration-api-prod --query ipAddress.fqdn -o tsv)
                        
                        # Delete old container
                        az container delete --resource-group ${RESOURCE_GROUP} --name registration-frontend-prod --yes 2>/dev/null || true
                        
                        # Deploy new container
                        az container create \
                            --resource-group ${RESOURCE_GROUP} \
                            --name registration-frontend-prod \
                            --image ${DOCKER_IMAGE_FRONTEND}:${BUILD_TAG} \
                            --cpu 0.5 \
                            --memory 0.5 \
                            --os-type Linux \
                            --registry-login-server ${DOCKER_REGISTRY} \
                            --registry-username $ACR_USER \
                            --registry-password $ACR_PASS \
                            --ports 80 \
                            --dns-name-label "registration-frontend-prod" \
                            --location centralindia \
                            --environment-variables "BACKEND_URL=http://$BACKEND_URL"
                        
                        sleep 5
                        FRONTEND_URL=$(az container show --resource-group ${RESOURCE_GROUP} --name registration-frontend-prod --query ipAddress.fqdn -o tsv)
                        
                        echo ""
                        echo "========== DEPLOYMENT COMPLETE =========="
                        echo "Frontend: http://$FRONTEND_URL"
                        echo "Backend:  http://$BACKEND_URL"
                        echo "API:      http://$BACKEND_URL/api/items"
                        echo "Swagger:  http://$BACKEND_URL/swagger/index.html"
                    '''
                }
            }
        }
    }

    post {
        always {
            echo 'Cleaning up...'
        }
        success {
            echo '✓ Pipeline completed successfully!'
        }
        failure {
            echo '✗ Pipeline failed!'
        }
    }
}
