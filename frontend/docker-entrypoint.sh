#!/bin/sh
set -e

# Get backend URL from either BACKEND_URL or BACKEND_API_URL environment variables
BACKEND_URL=${BACKEND_URL:-${BACKEND_API_URL:-"http://localhost:5000"}}

echo "🔧 Configuring nginx with BACKEND_URL: $BACKEND_URL"

# Use sed to replace environment variables in nginx config
# Escape the BACKEND_URL for use in sed replacement (escape special chars)
ESCAPED_BACKEND_URL=$(printf '%s\n' "$BACKEND_URL" | sed -e 's/[\/&]/\\&/g')

# Replace the placeholder in nginx config
sed "s|\${BACKEND_URL}|$ESCAPED_BACKEND_URL|g" /etc/nginx/conf.d/default.conf.template > /etc/nginx/conf.d/default.conf

# Verify nginx config syntax
nginx -t || (echo "Nginx config test failed" && cat /etc/nginx/conf.d/default.conf && exit 1)

# Start nginx
exec nginx -g "daemon off;"
