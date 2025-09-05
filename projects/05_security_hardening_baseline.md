# Project 5: Security Hardening Baseline

Goal: Apply a practical baseline: SSH hardening, firewall, fail2ban, updates.

## Steps
1) SSH
- In `/etc/ssh/sshd_config`: set `PermitRootLogin no`, `PasswordAuthentication no`, `AllowUsers admin deploy`.
- `systemctl reload sshd`.

2) Firewall
- UFW: `ufw allow 22,80,443/tcp && ufw enable`.
- firewalld: add ssh/http/https services and `--reload`.

3) Fail2ban
- Install package; enable `sshd` jail; verify bans with `fail2ban-client status sshd`.

4) Auto updates (security)
- Debian: `apt install unattended-upgrades` and enable.

Outcome: Reasonable baseline to reduce common attack surface.
