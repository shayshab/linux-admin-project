# 11. Containers and Orchestration

- Build: `docker build -t myorg/myapp:TAG .`
- Run locked down:
  - `docker run -d --read-only --cap-drop ALL -p 8080:8080 --name myapp myorg/myapp:TAG`
- Inspect: `docker logs -f myapp`, `docker exec -it myapp sh`
- Compose: keep a minimal `docker-compose.yml` for local dev
- K8s (quick): use Deployments, Services, Ingress; probe readiness/liveness
