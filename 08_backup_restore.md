# 08. Backup and Restore

- Files: `rsync -aHAX --delete /data/ /backups/data/`
- LVM snapshot: `lvcreate -L 10G -s -n data_snap /dev/vgdata/lvdata`
- PostgreSQL logical backup: `pg_dump -Fc dbname > /backups/db_$(date +%F).dump`
- Practice restores on non-prod regularly

Real‑life: ransomware-like deletion → immutable backups, least-privileged creds, offline copies.
