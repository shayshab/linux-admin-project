# 05. Networking

- IPs/routes: `ip a`, `ip route`
- DNS: `resolvectl status` or check `/etc/resolv.conf`
- Listening ports: `ss -lnpt`
- Troubleshooting:
  - Reachability: `ping -c 4 host`, `mtr -rw host`
  - TLS: `openssl s_client -connect host:443 -servername host -showcerts`
  - HTTP: `curl -vk https://host -H 'Host: example.com'`

Real‑life: LB says unhealthy → ensure app binds `0.0.0.0:PORT`, security group/firewall permits, health endpoint 200.
