# Project 1: Web Server Stack (Nginx + App + TLS)

**Goal**: Build a production-ready web server stack with reverse proxy, TLS, monitoring, and automated deployments.

**Prerequisites**: Debian/Ubuntu server, sudo access, domain name (for TLS), basic Linux knowledge.

---

## Phase 1: Foundation Setup

### 1.1 System Preparation
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y curl wget git vim htop tree jq

# Set hostname
sudo hostnamectl set-hostname webapp-01

# Create application user
sudo useradd -m -s /bin/bash app
sudo mkdir -p /opt/myapp /var/log/myapp
sudo chown -R app:app /opt/myapp /var/log/myapp
```

### 1.2 Application Development
```bash
# Install Python and dependencies
sudo apt install -y python3 python3-venv python3-pip

# Create virtual environment
sudo -u app python3 -m venv /opt/myapp/venv
sudo -u app /opt/myapp/venv/bin/pip install --upgrade pip
sudo -u app /opt/myapp/venv/bin/pip install flask gunicorn psutil

# Create application code
sudo -u app tee /opt/myapp/app.py << 'EOF'
from flask import Flask, jsonify, request
import psutil
import os
import time
from datetime import datetime

app = Flask(__name__)

@app.route('/')
def index():
    return '''
    <h1>MyApp Status Dashboard</h1>
    <ul>
        <li><a href="/health">Health Check</a></li>
        <li><a href="/metrics">System Metrics</a></li>
        <li><a href="/api/status">API Status</a></li>
    </ul>
    '''

@app.route('/health')
def health():
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'uptime': time.time() - psutil.boot_time()
    })

@app.route('/metrics')
def metrics():
    return jsonify({
        'cpu_percent': psutil.cpu_percent(interval=1),
        'memory_percent': psutil.virtual_memory().percent,
        'disk_usage': psutil.disk_usage('/').percent,
        'load_average': os.getloadavg()
    })

@app.route('/api/status')
def api_status():
    return jsonify({
        'app': 'MyApp',
        'version': '1.0.0',
        'environment': os.getenv('ENVIRONMENT', 'development'),
        'pid': os.getpid()
    })

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5000, debug=False)
EOF

# Create configuration file
sudo -u app tee /opt/myapp/config.py << 'EOF'
import os

class Config:
    SECRET_KEY = os.environ.get('SECRET_KEY') or 'dev-secret-key-change-in-production'
    ENVIRONMENT = os.environ.get('ENVIRONMENT', 'development')
    LOG_LEVEL = os.environ.get('LOG_LEVEL', 'INFO')
    WORKERS = int(os.environ.get('WORKERS', '2'))
EOF

# Create environment file
sudo tee /etc/myapp.env << 'EOF'
ENVIRONMENT=production
LOG_LEVEL=INFO
WORKERS=4
SECRET_KEY=your-super-secret-key-here
EOF
sudo chmod 600 /etc/myapp.env
```

---

## Phase 2: Service Management

### 2.1 systemd Service Configuration
```bash
# Create systemd service
sudo tee /etc/systemd/system/myapp.service << 'EOF'
[Unit]
Description=MyApp Flask Web Application
Documentation=https://flask.palletsprojects.com/
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=notify
User=app
Group=app
WorkingDirectory=/opt/myapp
EnvironmentFile=/etc/myapp.env
ExecStart=/opt/myapp/venv/bin/gunicorn \
    --bind 127.0.0.1:5000 \
    --workers 4 \
    --worker-class sync \
    --worker-connections 1000 \
    --max-requests 1000 \
    --max-requests-jitter 50 \
    --timeout 30 \
    --keep-alive 2 \
    --access-logfile /var/log/myapp/access.log \
    --error-logfile /var/log/myapp/error.log \
    --log-level info \
    --preload \
    app:app
ExecReload=/bin/kill -s HUP $MAINPID
Restart=on-failure
RestartSec=5s
StartLimitBurst=3
StartLimitIntervalSec=60
KillMode=mixed
KillSignal=SIGTERM
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable myapp
sudo systemctl start myapp
sudo systemctl status myapp
```

### 2.2 Service Monitoring and Management
```bash
# Check service status
sudo systemctl status myapp

# View logs
sudo journalctl -u myapp -f
sudo journalctl -u myapp --since "1 hour ago"

# Test service restart
sudo systemctl restart myapp

# Check if service is listening
sudo ss -tlnp | grep :5000
curl -s http://127.0.0.1:5000/health | jq
```

---

## Phase 3: Reverse Proxy Setup

### 3.1 Nginx Installation and Configuration
```bash
# Install Nginx
sudo apt install -y nginx

# Remove default site
sudo rm -f /etc/nginx/sites-enabled/default

# Create application configuration
sudo tee /etc/nginx/sites-available/myapp << 'EOF'
# Rate limiting
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=general:10m rate=30r/s;

# Upstream configuration
upstream myapp_backend {
    server 127.0.0.1:5000;
    keepalive 32;
}

server {
    listen 80;
    server_name _;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Logging
    access_log /var/log/nginx/myapp_access.log;
    error_log /var/log/nginx/myapp_error.log;
    
    # Health check endpoint
    location /healthz {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    # API endpoints with rate limiting
    location /api/ {
        limit_req zone=api burst=20 nodelay;
        proxy_pass http://myapp_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
    
    # Main application
    location / {
        limit_req zone=general burst=50 nodelay;
        proxy_pass http://myapp_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
}
EOF

# Enable site and test configuration
sudo ln -sf /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 3.2 Nginx Optimization
```bash
# Optimize Nginx configuration
sudo tee -a /etc/nginx/nginx.conf << 'EOF'

# Worker optimization
worker_processes auto;
worker_rlimit_nofile 65535;

events {
    worker_connections 4096;
    use epoll;
    multi_accept on;
}

http {
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    
    # Connection optimization
    keepalive_timeout 65;
    keepalive_requests 100;
    
    # Buffer sizes
    client_body_buffer_size 128k;
    client_max_body_size 10m;
    client_header_buffer_size 1k;
    large_client_header_buffers 4 4k;
}
EOF

sudo nginx -t && sudo systemctl reload nginx
```

---

## Phase 4: SSL/TLS Configuration

### 4.1 Let's Encrypt Setup
```bash
# Install Certbot
sudo apt install -y certbot python3-certbot-nginx

# Obtain SSL certificate (replace with your domain)
sudo certbot --nginx -d your-domain.com --non-interactive --agree-tos -m your-email@example.com

# Test certificate renewal
sudo certbot renew --dry-run

# Set up automatic renewal
echo "0 12 * * * /usr/bin/certbot renew --quiet" | sudo crontab -
```

### 4.2 SSL Configuration Enhancement
```bash
# Update Nginx configuration for better SSL
sudo tee /etc/nginx/sites-available/myapp << 'EOF'
# Rate limiting
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=general:10m rate=30r/s;

# Upstream configuration
upstream myapp_backend {
    server 127.0.0.1:5000;
    keepalive 32;
}

# HTTP to HTTPS redirect
server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}

# HTTPS server
server {
    listen 443 ssl http2;
    server_name your-domain.com;
    
    # SSL configuration
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Logging
    access_log /var/log/nginx/myapp_access.log;
    error_log /var/log/nginx/myapp_error.log;
    
    # Health check endpoint
    location /healthz {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    # API endpoints with rate limiting
    location /api/ {
        limit_req zone=api burst=20 nodelay;
        proxy_pass http://myapp_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
    
    # Main application
    location / {
        limit_req zone=general burst=50 nodelay;
        proxy_pass http://myapp_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
}
EOF

sudo nginx -t && sudo systemctl reload nginx
```

---

## Phase 5: Logging and Monitoring

### 5.1 Log Rotation Setup
```bash
# Configure logrotate for application logs
sudo tee /etc/logrotate.d/myapp << 'EOF'
/var/log/myapp/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 app app
    sharedscripts
    postrotate
        systemctl reload myapp > /dev/null 2>&1 || true
    endscript
}

/var/log/nginx/myapp_*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 www-data www-data
    sharedscripts
    postrotate
        systemctl reload nginx > /dev/null 2>&1 || true
    endscript
}
EOF

# Test logrotate configuration
sudo logrotate -d /etc/logrotate.d/myapp
```

### 5.2 Monitoring Script
```bash
# Create monitoring script
sudo tee /usr/local/bin/myapp-monitor.sh << 'EOF'
#!/bin/bash
set -euo pipefail

APP_URL="http://localhost"
LOG_FILE="/var/log/myapp/monitor.log"

# Function to log with timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Check if service is running
if ! systemctl is-active --quiet myapp; then
    log "ERROR: MyApp service is not running"
    systemctl restart myapp
    log "INFO: Attempted to restart MyApp service"
    exit 1
fi

# Check if application is responding
if ! curl -sf "$APP_URL/healthz" > /dev/null; then
    log "ERROR: Application health check failed"
    exit 1
fi

# Check system resources
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.2f", $3/$2 * 100.0}')

if (( $(echo "$CPU_USAGE > 80" | bc -l) )); then
    log "WARNING: High CPU usage: ${CPU_USAGE}%"
fi

if (( $(echo "$MEMORY_USAGE > 80" | bc -l) )); then
    log "WARNING: High memory usage: ${MEMORY_USAGE}%"
fi

log "INFO: Health check passed - CPU: ${CPU_USAGE}%, Memory: ${MEMORY_USAGE}%"
EOF

sudo chmod +x /usr/local/bin/myapp-monitor.sh

# Add to crontab for monitoring every 5 minutes
echo "*/5 * * * * /usr/local/bin/myapp-monitor.sh" | sudo crontab -
```

---

## Phase 6: Testing and Validation

### 6.1 Load Testing
```bash
# Install Apache Bench for load testing
sudo apt install -y apache2-utils

# Basic load test
ab -n 1000 -c 10 http://localhost/

# Test with SSL
ab -n 1000 -c 10 https://your-domain.com/

# Test API endpoints
ab -n 500 -c 5 http://localhost/api/status
```

### 6.2 Security Testing
```bash
# Test SSL configuration
curl -I https://your-domain.com/
openssl s_client -connect your-domain.com:443 -servername your-domain.com

# Test rate limiting
for i in {1..20}; do curl -s http://localhost/api/status; done

# Test security headers
curl -I https://your-domain.com/ | grep -i "x-frame-options\|x-content-type-options\|strict-transport-security"
```

---

## Phase 7: Deployment Automation

### 7.1 Deployment Script
```bash
# Create deployment script
sudo tee /usr/local/bin/deploy-myapp.sh << 'EOF'
#!/bin/bash
set -euo pipefail

APP_DIR="/opt/myapp"
BACKUP_DIR="/opt/myapp-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create backup
sudo mkdir -p "$BACKUP_DIR"
sudo cp -r "$APP_DIR" "$BACKUP_DIR/myapp_$TIMESTAMP"

# Pull latest code (if using git)
cd "$APP_DIR"
sudo -u app git pull origin main

# Install/update dependencies
sudo -u app /opt/myapp/venv/bin/pip install -r requirements.txt

# Restart service
sudo systemctl restart myapp

# Wait for service to be ready
sleep 5

# Health check
if curl -sf http://localhost/healthz > /dev/null; then
    echo "Deployment successful"
    # Clean up old backups (keep last 5)
    sudo find "$BACKUP_DIR" -name "myapp_*" -type d | sort | head -n -5 | sudo xargs rm -rf
else
    echo "Deployment failed, rolling back"
    sudo rm -rf "$APP_DIR"
    sudo mv "$BACKUP_DIR/myapp_$TIMESTAMP" "$APP_DIR"
    sudo systemctl restart myapp
    exit 1
fi
EOF

sudo chmod +x /usr/local/bin/deploy-myapp.sh
```

---

## Troubleshooting Guide

### Common Issues and Solutions

1. **Service won't start**
   ```bash
   sudo journalctl -u myapp -n 50
   sudo systemctl status myapp
   ```

2. **Nginx configuration errors**
   ```bash
   sudo nginx -t
   sudo journalctl -u nginx -n 20
   ```

3. **SSL certificate issues**
   ```bash
   sudo certbot certificates
   sudo certbot renew --dry-run
   ```

4. **High memory usage**
   ```bash
   sudo systemctl status myapp
   sudo journalctl -u myapp --since "1 hour ago" | grep -i memory
   ```

5. **Database connection issues** (if added later)
   ```bash
   sudo -u app /opt/myapp/venv/bin/python -c "import psycopg2; print('DB OK')"
   ```

---

## Production Checklist

- [ ] SSL certificate installed and auto-renewing
- [ ] Firewall configured (UFW: `ufw allow 22,80,443/tcp`)
- [ ] Log rotation configured
- [ ] Monitoring script running
- [ ] Backup strategy implemented
- [ ] Security headers configured
- [ ] Rate limiting enabled
- [ ] Service auto-starts on boot
- [ ] Health checks responding
- [ ] Load testing completed

---

## Next Steps

1. **Add Database**: Integrate PostgreSQL or MySQL
2. **Implement Caching**: Add Redis for session storage
3. **Set up Monitoring**: Deploy Prometheus + Grafana
4. **Containerize**: Convert to Docker containers
5. **CI/CD Pipeline**: Automate deployments with GitHub Actions
6. **Load Balancing**: Add multiple app instances behind Nginx

**Outcome**: A production-ready web application stack with proper security, monitoring, and deployment automation.
