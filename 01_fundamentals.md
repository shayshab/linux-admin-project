# 01. Fundamentals

- Identify OS/kernel: `cat /etc/os-release`, `uname -a`
- Filesystem: `pwd`, `ls -la`, `cd -`
- Find files: `find / -name "pattern" 2>/dev/null` (or `fd`)
- View files: `less -S file`, `tail -n 200 -f file`
- Processes: `ps aux --sort=-%cpu | head`, `top`, `htop`
- Ports: `ss -lntp`
- Permissions: `ls -l`, `chmod 640 file`, `chown user:group file`
- Packages: Debian `apt install name`; RHEL `dnf install name`

Baseline on a new VM:
- `hostnamectl set-hostname app-01`
- `timedatectl set-ntp true`
- Admin: `useradd -m -s /bin/bash admin && passwd admin && usermod -aG sudo admin` (RHEL: `wheel`)
