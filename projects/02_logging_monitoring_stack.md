# Project 2: Comprehensive Logging & Monitoring Stack

**Goal**: Build a complete observability stack with Prometheus, Grafana, centralized logging, and alerting.

**Prerequisites**: Debian/Ubuntu server, sudo access, 2GB+ RAM, basic understanding of metrics and logging.

---

## Phase 1: System Metrics Collection

### 1.1 Node Exporter Installation
```bash
# Download and install node_exporter
VER=1.8.2
cd /tmp
curl -sSL -O https://github.com/prometheus/node_exporter/releases/download/v$VER/node_exporter-$VER.linux-amd64.tar.gz
sudo tar -C /usr/local/bin --strip-components=1 -xzf node_exporter-$VER.linux-amd64.tar.gz node_exporter-$VER.linux-amd64/node_exporter

# Create systemd service
sudo tee /etc/systemd/system/node_exporter.service << 'EOF'
[Unit]
Description=Prometheus Node Exporter
Documentation=https://github.com/prometheus/node_exporter
After=network.target

[Service]
Type=simple
User=nobody
Group=nogroup
ExecStart=/usr/local/bin/node_exporter \
    --web.listen-address=127.0.0.1:9100 \
    --collector.systemd \
    --collector.processes \
    --collector.cpu \
    --collector.meminfo \
    --collector.diskstats \
    --collector.filesystem \
    --collector.netdev \
    --collector.loadavg \
    --collector.time \
    --collector.uname \
    --collector.vmstat \
    --collector.textfile.directory=/var/lib/node_exporter/textfile_collector
Restart=on-failure
RestartSec=5s
StartLimitBurst=3
StartLimitIntervalSec=60

[Install]
WantedBy=multi-user.target
EOF

# Create directory for custom metrics
sudo mkdir -p /var/lib/node_exporter/textfile_collector
sudo chown nobody:nogroup /var/lib/node_exporter/textfile_collector

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter
sudo systemctl status node_exporter

# Test metrics endpoint
curl -s http://127.0.0.1:9100/metrics | head -20
```

### 1.2 Custom Metrics Collection
```bash
# Create custom metrics script
sudo tee /usr/local/bin/custom-metrics.sh << 'EOF'
#!/bin/bash
# Custom metrics for node_exporter textfile collector

METRICS_FILE="/var/lib/node_exporter/textfile_collector/custom.prom"

# Application uptime
if systemctl is-active --quiet myapp; then
    APP_UPTIME=1
else
    APP_UPTIME=0
fi

# Disk usage for specific directories
DATA_USAGE=$(df /opt/myapp 2>/dev/null | awk 'NR==2 {print $5}' | sed 's/%//' || echo "0")
LOG_USAGE=$(df /var/log 2>/dev/null | awk 'NR==2 {print $5}' | sed 's/%//' || echo "0")

# Create metrics file
cat > "$METRICS_FILE" << EOM
# HELP app_service_up Application service status (1=up, 0=down)
# TYPE app_service_up gauge
app_service_up $APP_UPTIME

# HELP disk_usage_percent Disk usage percentage
# TYPE disk_usage_percent gauge
disk_usage_percent{path="/opt/myapp"} $DATA_USAGE
disk_usage_percent{path="/var/log"} $LOG_USAGE

# HELP custom_metrics_generated_timestamp_seconds Timestamp when custom metrics were generated
# TYPE custom_metrics_generated_timestamp_seconds gauge
custom_metrics_generated_timestamp_seconds $(date +%s)
EOM

# Set proper permissions
chmod 644 "$METRICS_FILE"
EOF

sudo chmod +x /usr/local/bin/custom-metrics.sh

# Add to crontab to run every minute
echo "* * * * * /usr/local/bin/custom-metrics.sh" | sudo crontab -
```

---

## Phase 2: Prometheus Setup

### 2.1 Prometheus Installation
```bash
# Create prometheus user and directories
sudo useradd --no-create-home --shell /usr/sbin/nologin prometheus || true
sudo mkdir -p /etc/prometheus /var/lib/prometheus
sudo chown prometheus:prometheus /etc/prometheus /var/lib/prometheus

# Download Prometheus
VER=2.48.0
cd /tmp
curl -sSL -O https://github.com/prometheus/prometheus/releases/download/v$VER/prometheus-$VER.linux-amd64.tar.gz
sudo tar -C /usr/local/bin --strip-components=1 -xzf prometheus-$VER.linux-amd64.tar.gz prometheus-$VER.linux-amd64/prometheus
sudo tar -C /usr/local/bin --strip-components=1 -xzf prometheus-$VER.linux-amd64.tar.gz prometheus-$VER.linux-amd64/promtool
sudo chown prometheus:prometheus /usr/local/bin/prometheus /usr/local/bin/promtool

# Create Prometheus configuration
sudo tee /etc/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'production'
    replica: 'prometheus-01'

rule_files:
  - "alert_rules.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - localhost:9093

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['localhost:9100']
    scrape_interval: 5s
    metrics_path: /metrics

  - job_name: 'myapp'
    static_configs:
      - targets: ['localhost:5000']
    metrics_path: /metrics
    scrape_interval: 10s

  - job_name: 'nginx'
    static_configs:
      - targets: ['localhost:9113']
    scrape_interval: 10s
EOF

# Create alert rules
sudo tee /etc/prometheus/alert_rules.yml << 'EOF'
groups:
- name: system_alerts
  rules:
  - alert: HighCPUUsage
    expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High CPU usage detected"
      description: "CPU usage is above 80% for more than 5 minutes on {{ $labels.instance }}"

  - alert: HighMemoryUsage
    expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High memory usage detected"
      description: "Memory usage is above 85% for more than 5 minutes on {{ $labels.instance }}"

  - alert: DiskSpaceLow
    expr: (1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100 > 90
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Disk space is running low"
      description: "Disk usage is above 90% on {{ $labels.instance }} {{ $labels.mountpoint }}"

  - alert: ServiceDown
    expr: up == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Service is down"
      description: "{{ $labels.job }} on {{ $labels.instance }} has been down for more than 1 minute"

  - alert: AppServiceDown
    expr: app_service_up == 0
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "Application service is down"
      description: "MyApp service has been down for more than 2 minutes"
EOF

sudo chown prometheus:prometheus /etc/prometheus/alert_rules.yml

# Create systemd service
sudo tee /etc/systemd/system/prometheus.service << 'EOF'
[Unit]
Description=Prometheus
Documentation=https://prometheus.io/docs/introduction/overview/
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=prometheus
Group=prometheus
ExecStart=/usr/local/bin/prometheus \
    --config.file=/etc/prometheus/prometheus.yml \
    --storage.tsdb.path=/var/lib/prometheus \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries \
    --web.listen-address=127.0.0.1:9090 \
    --web.enable-lifecycle \
    --web.enable-admin-api \
    --storage.tsdb.retention.time=30d \
    --storage.tsdb.retention.size=10GB \
    --log.level=info
Restart=on-failure
RestartSec=5s
StartLimitBurst=3
StartLimitIntervalSec=60

[Install]
WantedBy=multi-user.target
EOF

# Enable and start Prometheus
sudo systemctl daemon-reload
sudo systemctl enable --now prometheus
sudo systemctl status prometheus

# Test Prometheus
curl -s http://127.0.0.1:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'
```

---

## Phase 3: Grafana Setup

### 3.1 Grafana Installation
```bash
# Add Grafana repository
sudo apt install -y software-properties-common
sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -

# Install Grafana
sudo apt update
sudo apt install -y grafana

# Configure Grafana
sudo tee /etc/grafana/grafana.ini << 'EOF'
[server]
http_addr = 127.0.0.1
http_port = 3000
domain = localhost
root_url = http://localhost:3000/

[security]
admin_user = admin
admin_password = admin123
secret_key = $(openssl rand -base64 32)

[users]
allow_sign_up = false
allow_org_create = false

[log]
mode = console
level = info
EOF

# Start Grafana
sudo systemctl enable --now grafana-server
sudo systemctl status grafana-server

# Wait for Grafana to start
sleep 10
curl -s http://127.0.0.1:3000/api/health
```

### 3.2 Grafana Configuration
```bash
# Create datasource configuration script
sudo tee /usr/local/bin/grafana-setup.sh << 'EOF'
#!/bin/bash
set -euo pipefail

GRAFANA_URL="http://127.0.0.1:3000"
ADMIN_USER="admin"
ADMIN_PASS="admin123"

# Wait for Grafana to be ready
until curl -s "$GRAFANA_URL/api/health" > /dev/null; do
    echo "Waiting for Grafana to start..."
    sleep 2
done

# Create Prometheus datasource
curl -X POST \
    -H "Content-Type: application/json" \
    -u "$ADMIN_USER:$ADMIN_PASS" \
    -d '{
        "name": "Prometheus",
        "type": "prometheus",
        "url": "http://127.0.0.1:9090",
        "access": "proxy",
        "isDefault": true,
        "jsonData": {
            "timeInterval": "5s"
        }
    }' \
    "$GRAFANA_URL/api/datasources"

echo "Prometheus datasource created"

# Import Node Exporter dashboard
curl -X POST \
    -H "Content-Type: application/json" \
    -u "$ADMIN_USER:$ADMIN_PASS" \
    -d '{
        "dashboard": {
            "id": null,
            "title": "Node Exporter Full",
            "tags": ["prometheus", "node-exporter"],
            "timezone": "browser",
            "panels": [],
            "time": {
                "from": "now-1h",
                "to": "now"
            },
            "refresh": "5s"
        },
        "overwrite": true
    }' \
    "$GRAFANA_URL/api/dashboards/db"

echo "Node Exporter dashboard imported"
EOF

sudo chmod +x /usr/local/bin/grafana-setup.sh
sudo /usr/local/bin/grafana-setup.sh
```

---

## Phase 4: Centralized Logging

### 4.1 Log Aggregation Setup
```bash
# Install rsyslog for log forwarding
sudo apt install -y rsyslog

# Configure rsyslog for application logs
sudo tee /etc/rsyslog.d/50-myapp.conf << 'EOF'
# Application logs
:programname, isequal, "myapp" /var/log/myapp/application.log
& stop

# Nginx logs
:programname, isequal, "nginx" /var/log/nginx/nginx.log
& stop
EOF

# Create log parsing script
sudo tee /usr/local/bin/parse-logs.sh << 'EOF'
#!/bin/bash
# Parse application logs and create metrics

LOG_FILE="/var/log/myapp/application.log"
METRICS_FILE="/var/lib/node_exporter/textfile_collector/app_metrics.prom"

# Count log levels
ERROR_COUNT=$(grep -c "ERROR" "$LOG_FILE" 2>/dev/null || echo "0")
WARN_COUNT=$(grep -c "WARN" "$LOG_FILE" 2>/dev/null || echo "0")
INFO_COUNT=$(grep -c "INFO" "$LOG_FILE" 2>/dev/null || echo "0")

# Count HTTP status codes from access logs
HTTP_200=$(grep -c " 200 " /var/log/nginx/myapp_access.log 2>/dev/null || echo "0")
HTTP_404=$(grep -c " 404 " /var/log/nginx/myapp_access.log 2>/dev/null || echo "0")
HTTP_500=$(grep -c " 500 " /var/log/nginx/myapp_access.log 2>/dev/null || echo "0")

# Create metrics file
cat > "$METRICS_FILE" << EOM
# HELP app_log_errors_total Total number of ERROR log entries
# TYPE app_log_errors_total counter
app_log_errors_total $ERROR_COUNT

# HELP app_log_warnings_total Total number of WARN log entries
# TYPE app_log_warnings_total counter
app_log_warnings_total $WARN_COUNT

# HELP app_log_info_total Total number of INFO log entries
# TYPE app_log_info_total counter
app_log_info_total $INFO_COUNT

# HELP nginx_http_requests_total Total number of HTTP requests by status code
# TYPE nginx_http_requests_total counter
nginx_http_requests_total{status="200"} $HTTP_200
nginx_http_requests_total{status="404"} $HTTP_404
nginx_http_requests_total{status="500"} $HTTP_500
EOM

chmod 644 "$METRICS_FILE"
EOF

sudo chmod +x /usr/local/bin/parse-logs.sh

# Add to crontab
echo "*/5 * * * * /usr/local/bin/parse-logs.sh" | sudo crontab -
```

---

## Phase 5: Testing and Validation

### 5.1 Load Testing for Metrics
```bash
# Install Apache Bench
sudo apt install -y apache2-utils

# Generate load to test metrics
ab -n 1000 -c 10 http://localhost/ &
ab -n 500 -c 5 http://localhost/api/status &

# Monitor metrics in real-time
watch -n 5 'curl -s http://127.0.0.1:9100/metrics | grep -E "(http_requests|app_)"'
```

### 5.2 Alert Testing
```bash
# Test high CPU alert
stress --cpu 4 --timeout 60s &

# Test disk space alert (if you have a test partition)
dd if=/dev/zero of=/tmp/testfile bs=1M count=1000 &

# Check alerts in Prometheus
curl -s http://127.0.0.1:9090/api/v1/alerts | jq '.data.alerts[] | {alertname: .labels.alertname, state: .state}'
```

---

## Troubleshooting Guide

### Common Issues and Solutions

1. **Prometheus targets down**
   ```bash
   curl -s http://127.0.0.1:9090/api/v1/targets | jq '.data.activeTargets[] | select(.health != "up")'
   ```

2. **Grafana can't connect to Prometheus**
   ```bash
   # Check Prometheus is running
   sudo systemctl status prometheus
   # Check network connectivity
   curl -s http://127.0.0.1:9090/api/v1/query?query=up
   ```

3. **Missing metrics**
   ```bash
   # Check node_exporter
   curl -s http://127.0.0.1:9100/metrics | grep node_cpu
   # Check custom metrics
   ls -la /var/lib/node_exporter/textfile_collector/
   ```

---

## Production Checklist

- [ ] All services running and healthy
- [ ] Prometheus collecting metrics from all targets
- [ ] Grafana dashboards displaying data
- [ ] Alert rules configured and tested
- [ ] Log rotation working properly
- [ ] Custom metrics being generated
- [ ] Security: services bound to localhost only
- [ ] Performance: adequate resources allocated

---

## Next Steps

1. **Add more exporters**: MySQL, PostgreSQL, Redis exporters
2. **Implement log aggregation**: ELK stack or Loki
3. **Add more dashboards**: Application-specific metrics
4. **Set up external alerting**: Slack, PagerDuty integration
5. **Implement log correlation**: Link logs with metrics
6. **Add distributed tracing**: Jaeger or Zipkin

**Outcome**: A comprehensive monitoring and logging stack providing full observability into your Linux systems and applications.