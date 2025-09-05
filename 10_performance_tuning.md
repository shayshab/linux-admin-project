# 10. Performance and Tuning

- Filesystems: prefer `noatime` where safe; XFS for large files
- sysctl (validate first): `vm.swappiness=10`, `net.core.somaxconn=1024`, `net.ipv4.tcp_tw_reuse=1`
- App-specific: enable GC/JIT flags; Python `gunicorn` workers ≈ `2-4 * CPU cores`

Real‑life: slow disk I/O → `iostat -xz 1`, check `avgqu-sz` and `await`, move hot data or upgrade storage.
