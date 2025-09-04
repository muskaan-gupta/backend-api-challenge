#!/bin/bash

# GitHub Actions deployment script
# This script runs on the VM to deploy the application

set -e

echo "Starting deployment process..."

# Configuration
APP_DIR="/opt/backend-api"
BACKUP_DIR="/opt/backend-api-backup"
SERVICE_NAME="backend-api"
VM_USER="azureuser"

# Create backup of current deployment
if [ -d "$APP_DIR" ]; then
  echo "Creating backup of current deployment..."
  sudo rm -rf $BACKUP_DIR
  sudo cp -r $APP_DIR $BACKUP_DIR
fi

# Create application directory
echo "Setting up application directory..."
sudo mkdir -p $APP_DIR
sudo chown -R $VM_USER:$VM_USER $APP_DIR

# Extract new deployment
echo "Extracting deployment package..."
cd $APP_DIR
sudo tar -xzf /tmp/backend-api-deployment.tar.gz
sudo chown -R $VM_USER:$VM_USER $APP_DIR

# Make scripts executable
chmod +x scripts/*.sh

# Setup infrastructure (only if needed)
echo "Checking infrastructure requirements..."

# Install Node.js if needed
if ! command -v node &> /dev/null; then
  echo "Installing Node.js..."
  curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi

# Install PM2 if needed
if ! command -v pm2 &> /dev/null; then
  echo "Installing PM2..."
  sudo npm install -g pm2
fi

# Install Nginx if needed
if ! command -v nginx &> /dev/null; then
  echo "Installing Nginx..."
  sudo apt-get update
  sudo apt-get install -y nginx
  
  # Configure Nginx (only on first install)
  echo "Configuring Nginx..."
  cat > /tmp/nginx-config << 'NGINX_EOF'
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 86400;
    }
}
NGINX_EOF

  sudo mv /tmp/nginx-config /etc/nginx/sites-available/backend-api
  sudo ln -sf /etc/nginx/sites-available/backend-api /etc/nginx/sites-enabled/
  sudo rm -f /etc/nginx/sites-enabled/default
  sudo nginx -t
  sudo systemctl reload nginx
fi

# Create logs directory
mkdir -p logs

# Zero-downtime deployment with PM2
echo "Deploying application with zero downtime..."

# Check if app is already running
if pm2 describe $SERVICE_NAME > /dev/null 2>&1; then
  echo "Application is running, performing graceful reload..."
  
  # Install dependencies first
  echo "Installing dependencies..."
  npm install --production
  
  # Graceful reload (zero downtime)
  pm2 reload $SERVICE_NAME --wait-ready --listen-timeout 10000
  
  echo "Graceful reload completed!"
else
  echo "Starting application for the first time..."
  
  # Install dependencies
  echo "Installing dependencies..."
  npm install --production
  
  # Start the application
  pm2 start ecosystem.config.js --env production
  echo "Application started!"
fi
pm2 save
pm2 startup | tail -n 1 | sudo bash || true

# Clean up
rm -f /tmp/backend-api-deployment.tar.gz

echo "Deployment completed successfully!"
