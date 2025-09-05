#!/bin/bash
# filepath: src/scripts/system_health.sh

# Thresholds
CPU_THRESHOLD=80
MEMORY_THRESHOLD=80
DISK_THRESHOLD=90

# Check CPU Usage
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
if (( $(echo "$CPU_USAGE > $CPU_THRESHOLD" | bc -l) )); then
  echo "Warning: High CPU usage detected ($CPU_USAGE%)"
fi

# Check Memory Usage
MEMORY_USAGE=$(free | awk '/Mem/{printf("%.2f"), $3/$2*100}')
if (( $(echo "$MEMORY_USAGE > $MEMORY_THRESHOLD" | bc -l) )); then
  echo "Warning: High memory usage detected ($MEMORY_USAGE%)"
fi

# Check Disk Usage
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if (( DISK_USAGE > DISK_THRESHOLD )); then
  echo "Warning: High disk usage detected ($DISK_USAGE%)"
fi

# Check Service Status
SERVICES=("nginx" "mysql")
for SERVICE in "${SERVICES[@]}"; do
  if ! systemctl is-active --quiet "$SERVICE"; then
    echo "Warning: $SERVICE is not running"
  fi
done