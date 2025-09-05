# 12. SELinux/AppArmor

- SELinux mode: `getenforce` (Enforcing/Permissive)
- Audit denials: `ausearch -m avc -ts recent` or view `/var/log/audit/audit.log`
- Prefer fixing labels/policies over disabling
- AppArmor: check profiles under `/etc/apparmor.d/` and logs under `dmesg`/`/var/log/kern.log`
