#!/bin/bash

# Rollback script for emergency situations
# This script will restore the previous version if deployment fails

set -e

echo "🔄 Starting rollback process..."

APP_DIR="/opt/backend-api"
BACKUP_DIR="/opt/backend-api-backup"
SERVICE_NAME="backend-api"

# Check if backup exists
if [ ! -d "$BACKUP_DIR" ]; then
    echo "❌ No backup found! Cannot rollback."
    exit 1
fi

# Rollback with zero downtime using PM2 reload
echo "📁 Restoring from backup..."
sudo rm -rf $APP_DIR
sudo mv $BACKUP_DIR $APP_DIR
sudo chown -R azureuser:azureuser $APP_DIR

# Zero-downtime rollback
echo "🔄 Performing zero-downtime rollback..."
cd $APP_DIR

# Check if service is running
if pm2 describe $SERVICE_NAME > /dev/null 2>&1; then
    echo "Service is running, performing graceful rollback..."
    pm2 reload $SERVICE_NAME --wait-ready --listen-timeout 10000
else
    echo "Service not running, starting from backup..."
    pm2 start ecosystem.config.js --env production
fi

# Verify rollback
echo "🔍 Verifying rollback..."
sleep 5

if pm2 list | grep -q "backend-api.*online"; then
    echo "✅ Rollback completed successfully!"
else
    echo "❌ Rollback failed!"
    exit 1
fi

echo "🎉 Rollback completed!"
