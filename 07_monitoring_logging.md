# 07. Monitoring and Logging

- System metrics: `top/htop`, `vmstat 1`, `iostat -xz 1`, `sar -u 1 5`
- Journald: `journalctl -xe`, `journalctl -u myapp -S today`
- App logs: `tail -F /var/log/myapp/*.log`
- Log rotation with logrotate:
```
/var/log/myapp/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 0640 app app
    sharedscripts
    postrotate
        systemctl kill -s HUP myapp || true
    endscript
}
```
- Centralize: rsyslog/fluent-bit/vector

Real‑life: high CPU at night → capture `top` batch output, inspect `journalctl -u myapp -S -1h`, correlate with deploys.
