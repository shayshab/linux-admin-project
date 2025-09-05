# 03. Storage and LVM

- Inspect: `lsblk -f`, `blkid`, `fdisk -l`
- Mount:
  - Temp: `mount /dev/vdb1 /mnt/data`
  - Persist: `/dev/vdb1 /mnt/data xfs defaults,noatime 0 0` in `/etc/fstab`, then `mount -a`
- LVM:
  - `pvcreate /dev/vdb`; `vgcreate vgdata /dev/vdb`; `lvcreate -L 100G -n lvdata vgdata`
  - Format/mount: `mkfs.xfs /dev/vgdata/lvdata`, add to `/etc/fstab`
- Grow XFS: `lvextend -r -L +50G /dev/vgdata/lvdata`

Real‑life: `/var` full → create LV, `rsync -aHAX /var/ /mnt/newvar/`, update mount, restart apps.
