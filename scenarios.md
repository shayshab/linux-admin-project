# Real‑Life Scenarios

- Blue‑green deployment on a single VM
  1) Run `myapp.service` on 8080 and `myapp-next.service` on 8081
  2) Nginx upstream flips between 8080/8081
  3) Health‑check new version, switch, drain old

- Zero‑downtime log rotation
  1) `/etc/logrotate.d/myapp` with `copytruncate` if app can’t `HUP`
  2) Validate with `logrotate -d /etc/logrotate.conf`, then force run

- Expanding disk on cloud VM (LVM)
  1) Extend volume in cloud console
  2) `echo 1 > /sys/class/block/sda/device/rescan`, grow partition, `pvresize`, `lvextend -r`
