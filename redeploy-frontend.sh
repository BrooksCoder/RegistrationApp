#!/bin/bash
# Quick deployment script for frontend with correct backend URL

set -e

echo "🚀 Redeploying Frontend with Backend URL Configuration"
echo "======================================================"
echo ""

# Configuration
RESOURCE_GROUP="YourResourceGroup"  # CHANGE THIS
CONTAINER_NAME="registration-frontend-prod"
IMAGE_NAME="registrationapp.azurecr.io/registration-frontend:latest"  # CHANGE THIS
REGISTRY_SERVER="registrationapp.azurecr.io"  # CHANGE THIS
REGISTRY_USERNAME="<YOUR_USERNAME>"  # CHANGE THIS
REGISTRY_PASSWORD="<YOUR_PASSWORD>"  # CHANGE THIS

# Ask for backend URL
echo "What is your backend API URL?"
echo "Example: https://registration-api-prod.centralindia.azurecontainer.io"
read -p "Backend URL: " BACKEND_URL

if [ -z "$BACKEND_URL" ]; then
    echo "❌ Backend URL is required"
    exit 1
fi

echo ""
echo "Configuration:"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Container Name: $CONTAINER_NAME"
echo "  Backend URL: $BACKEND_URL"
echo ""
echo "⏳ Stopping existing container..."

# Stop existing container
az container delete \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CONTAINER_NAME" \
  --yes 2>/dev/null || true

echo "✓ Creating new container with backend URL..."
echo ""

# Create container with backend URL
az container create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CONTAINER_NAME" \
  --image "$IMAGE_NAME" \
  --cpu 1 \
  --memory 1 \
  --ports 80 \
  --environment-variables BACKEND_URL="$BACKEND_URL" \
  --registry-login-server "$REGISTRY_SERVER" \
  --registry-username "$REGISTRY_USERNAME" \
  --registry-password "$REGISTRY_PASSWORD" \
  --restart-policy Always

echo ""
echo "✅ Container deployed successfully!"
echo ""
echo "Frontend URL: http://registration-frontend-prod.centralindia.azurecontainer.io/"
echo "Backend URL: $BACKEND_URL"
echo ""
echo "⏱️  Waiting for container to start (30 seconds)..."
sleep 30

echo ""
echo "✓ Deployment complete!"
echo "✓ Frontend is now pointing to: $BACKEND_URL"
echo ""
echo "Test the application:"
echo "  1. Open: http://registration-frontend-prod.centralindia.azurecontainer.io/"
echo "  2. Check browser console (F12)"
echo "  3. Items should load from the backend"
