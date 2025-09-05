# 02. Users, Groups, and sudo

- Users: `useradd -m -s /bin/bash alice`, `passwd alice`, `userdel -r alice`
- Groups: `groupadd analytics`, `usermod -aG analytics alice`, `groups alice`
- sudo: Debian `usermod -aG sudo alice`; RHEL `usermod -aG wheel alice`
- Restrict commands: `visudo` → `%deploy ALL=(root) NOPASSWD: /usr/bin/systemctl restart myapp`
- SSH keys: add to `~/.ssh/authorized_keys`; perms `700 ~/.ssh`, `600 authorized_keys`
