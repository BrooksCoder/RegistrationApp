# Dockerfile for Angular Frontend

# Build stage
FROM node:18-alpine AS build

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy source
COPY . .

# Build Angular app
RUN npm run build

# Runtime stage - serve with nginx
FROM nginx:alpine

# Copy built application from build stage
COPY --from=build /app/dist/registration-app /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
