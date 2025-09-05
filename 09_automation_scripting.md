# 09. Automation and Scripting

- Use repo scripts under `src/scripts/` as building blocks
- Idempotent shell template:
```
#!/usr/bin/env bash
set -euo pipefail
user="deploy"
id -u "$user" >/dev/null 2>&1 || useradd -m -s /bin/bash "$user"
grep -q "^AllowUsers.*\b$user\b" /etc/ssh/sshd_config || echo "AllowUsers $user" >> /etc/ssh/sshd_config
systemctl reload sshd
```
- Fleet scale: prefer Ansible/Terraform
