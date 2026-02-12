#!/bin/sh
set -e

# Get backend URL from environment variables
# Try BACKEND_URL first, then BACKEND_API_URL, default to localhost
BACKEND_URL="${BACKEND_URL:-${BACKEND_API_URL:-http://localhost:5000}}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 NGINX CONFIGURATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Backend URL: $BACKEND_URL"
echo ""

# Check if template file exists
if [ ! -f /etc/nginx/conf.d/default.conf.template ]; then
    echo "❌ ERROR: Template file not found at /etc/nginx/conf.d/default.conf.template"
    echo "Available files in /etc/nginx/conf.d/:"
    ls -la /etc/nginx/conf.d/
    exit 1
fi

# Escape special characters in the URL for sed
ESCAPED_URL=$(printf '%s\n' "$BACKEND_URL" | sed -e 's/[\/&]/\\&/g')

echo "Substituting backend URL in nginx config..."

# Replace the placeholder - handle both ${BACKEND_URL} and BACKEND_URL_PLACEHOLDER
sed -e "s|BACKEND_URL_PLACEHOLDER|$ESCAPED_URL|g" \
    -e "s|\${BACKEND_URL}|$ESCAPED_URL|g" \
    /etc/nginx/conf.d/default.conf.template > /etc/nginx/conf.d/default.conf

echo "✅ Nginx configuration generated"
echo ""

# Show the proxy_pass line for debugging
echo "Configured proxy_pass:"
grep "proxy_pass" /etc/nginx/conf.d/default.conf || echo "⚠️  No proxy_pass found"
echo ""

# Verify nginx config syntax
echo "Testing nginx configuration..."
if nginx -t; then
    echo "✅ Nginx configuration is valid"
else
    echo "❌ Nginx configuration test failed!"
    echo "Generated config:"
    cat /etc/nginx/conf.d/default.conf
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Starting NGINX..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Start nginx in foreground mode
exec nginx -g "daemon off;"
