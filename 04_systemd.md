# 04. systemd Services

- Manage: `systemctl status nginx`, `systemctl enable --now nginx`, `journalctl -u nginx -f`
- Service `/etc/systemd/system/myapp.service`:
```
[Unit]
Description=My App
After=network.target

[Service]
User=app
Group=app
EnvironmentFile=/etc/myapp.env
ExecStart=/usr/local/bin/myapp --config /etc/myapp.yaml
Restart=on-failure
RestartSec=5s
StartLimitBurst=3
StartLimitIntervalSec=60

[Install]
WantedBy=multi-user.target
```
- Reload/start: `systemctl daemon-reload && systemctl enable --now myapp`
