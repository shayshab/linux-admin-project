# 06. Security Essentials

- SSH hardening in `sshd_config`:
  - `PasswordAuthentication no`, `PermitRootLogin no`, `AllowUsers admin deploy`
  - `chmod 700 ~/.ssh` and `chmod 600 ~/.ssh/authorized_keys`
- Firewall:
  - UFW (Ubuntu): `ufw allow 22/tcp && ufw allow 80,443/tcp && ufw enable`
  - firewalld (RHEL): `firewall-cmd --add-service=ssh --permanent && firewall-cmd --add-service=http --add-service=https --permanent && firewall-cmd --reload`
- Fail2ban: enable `sshd` jail to mitigate brute-force
- Secrets: store outside repos, `chmod 600`, consider a secrets manager

Real‑life: rotate leaked API key → revoke, issue, update `/etc/myapp.env`, `systemctl restart myapp`, audit logs.
