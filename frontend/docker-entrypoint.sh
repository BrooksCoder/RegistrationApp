#!/bin/sh
set -e

# Default backend URL if not provided
BACKEND_URL=${BACKEND_URL:-"http://localhost:5000"}

# Use sed to replace environment variables in nginx config
# Escape the BACKEND_URL for use in sed replacement (escape special chars)
ESCAPED_BACKEND_URL=$(printf '%s\n' "$BACKEND_URL" | sed -e 's/[\/&]/\\&/g')

# Replace the placeholder in nginx config
sed "s|\${BACKEND_URL}|$ESCAPED_BACKEND_URL|g" /etc/nginx/conf.d/default.conf.template > /etc/nginx/conf.d/default.conf

# Verify nginx config syntax
nginx -t || (echo "Nginx config test failed" && cat /etc/nginx/conf.d/default.conf && exit 1)

# Start nginx
exec nginx -g "daemon off;"
