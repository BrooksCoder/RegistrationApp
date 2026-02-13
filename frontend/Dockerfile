# Dockerfile for Angular Frontend

# Build stage
FROM node:18-alpine AS build

ARG BACKEND_URL=http://localhost:5000
ENV BACKEND_URL=$BACKEND_URL

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

# Runtime stage
FROM nginx:alpine

RUN rm /etc/nginx/conf.d/default.conf

COPY --from=build /app/dist/registration-app /usr/share/nginx/html

# Simple nginx config for Angular routing
COPY <<EOF /etc/nginx/conf.d/default.conf
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
EOF

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]