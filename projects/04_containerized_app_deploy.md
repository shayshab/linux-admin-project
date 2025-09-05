# Project 4: Containerized App Deploy (Docker Compose)

Goal: Run a web app and reverse proxy via Compose with least privilege.

## Steps
1) Install Docker & Compose plugin (per distro)

2) Compose file
```
mkdir -p ~/compose-app && cd ~/compose-app
cat <<'EOF' > docker-compose.yml
services:
  app:
    image: ghcr.io/stack-example/echo:latest
    read_only: true
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    ports:
      - "127.0.0.1:5000:8080"
  nginx:
    image: nginx:stable
    depends_on:
      - app
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
EOF
cat <<'EOF' > nginx.conf
server {
  listen 80;
  location / {
    proxy_pass http://app:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  }
}
EOF
```

3) Up and test
```
docker compose up -d
curl -sS http://localhost/
```

4) Logs and exec
```
docker compose logs -f
docker compose exec app sh
```

Outcome: Minimal container deployment with a hardened runtime and reverse proxy.
