#!/bin/sh
set -e

# Get backend URL from environment variables
BACKEND_URL="${BACKEND_URL:-http://localhost:5000}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 CONFIGURING NGINX"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Backend URL: $BACKEND_URL"
echo ""

# Check if template exists
if [ ! -f /etc/nginx/conf.d/default.conf.template ]; then
    echo "ERROR: Template not found!"
    ls -la /etc/nginx/conf.d/
    exit 1
fi

# Use printf and sed to escape the URL properly
ESCAPED_URL=$(printf '%s\n' "$BACKEND_URL" | sed -e 's|[/\\&]|\\&|g')

echo "Generating nginx config..."

# Replace the placeholder with the actual backend URL
cat /etc/nginx/conf.d/default.conf.template | sed "s|BACKEND_URL_PLACEHOLDER|$ESCAPED_URL|g" > /etc/nginx/conf.d/default.conf

# Verify the config was created
if [ ! -f /etc/nginx/conf.d/default.conf ]; then
    echo "ERROR: Failed to create nginx config!"
    exit 1
fi

echo "✅ Config generated"
echo ""

# Show what we configured
echo "Proxy configuration:"
grep -A 2 "location /api" /etc/nginx/conf.d/default.conf | head -3
echo ""

# Test nginx config
echo "Testing nginx configuration..."
if nginx -t 2>&1; then
    echo "✅ Config is valid"
else
    echo "❌ Config test failed! Here's the config:"
    cat /etc/nginx/conf.d/default.conf
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 STARTING NGINX"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

exec nginx -g "daemon off;"
