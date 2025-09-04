module.exports = {
  apps: [{
    name: 'backend-api',
    script: 'server.js',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 3000  // PM2 will run on port 3000, nginx will proxy to port 80
    },
    env_production: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    log_date_format: 'YYYY-MM-DD HH:mm Z',
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
    time: true,
    // Zero-downtime deployment settings
    wait_ready: true,
    listen_timeout: 10000,
    kill_timeout: 5000,
    // Graceful shutdown
    shutdown_with_message: true,
    // Health check for reload
    health_check_grace_period: 3000
  }]
};
