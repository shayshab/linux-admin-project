# 13. Troubleshooting Playbooks

- Boot issues: `systemctl rescue`, check `/var/log/boot.log`
- Network flaps: `dmesg -T | grep -iE 'link|eth|eno'`
- TLS failures: verify chain, SNI, time skew
- Intermittent app errors: correlate app logs, system metrics, and dependencies (DB, cache)
- Disk full: `du -ah / | sort -h | tail -n 50`, rotate/prune logs, move data
