# Docker Infrastructure Stack

[![Docker](https://img.shields.io/badge/Docker-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![Prometheus](https://img.shields.io/badge/Prometheus-E6522C?logo=prometheus&logoColor=white)](https://prometheus.io/)
[![Grafana](https://img.shields.io/badge/Grafana-F46800?logo=grafana&logoColor=white)](https://grafana.com/)

Production‑ready container infrastructure with built‑in observability. This stack standardizes how services are packaged, configured, deployed, and monitored using Docker, Prometheus, and Grafana.

## Business Value

- Faster delivery: consistent, repeatable deployments using containers and declarative configs
- Lower risk: observability by default (metrics, dashboards, alerts) reduces blind spots
- Operational efficiency: shared tooling and patterns across environments (dev/staging/prod)
- Cost visibility: usage metrics and capacity dashboards inform rightsizing decisions

## Quantifiable Results (targets/examples)

- Provisioning time: < 5 minutes from zero to dashboards available
- MTTR: < 15 minutes with actionable alerts and runbooks
- Uptime: 99.9% SLO for core services (tracked via Grafana)
- Cost: 20–30% reduction via consolidation and rightsizing (when applied)

Update these with your measured outcomes once baseline data is collected.

## Architecture Overview

- Containers: application services run in Docker with environment‑specific configuration
- Networking: isolated Docker networks per domain; optional ingress via reverse proxy
- Observability:
  - Prometheus scrapes exporters (cAdvisor/node‑exporter/app metrics) on a dedicated network
  - Alertmanager routes alerts (e.g., Slack, email) from Prometheus rules
  - Grafana provides curated dashboards and SLO views
- Storage: named volumes for stateful components; retention and backup strategy documented in `docs/`

Common ports: Prometheus `9090`, Grafana `3000`, Alertmanager `9093`.

## Repository Structure

- `docs/` — Architecture, ADRs, and runbooks
- `configs/` — Base and environment‑specific configuration (dev/staging/prod)
- `infra/` — IaC entry points (Terraform, Ansible, Kubernetes, etc.)
- `scripts/` — Helper scripts (bootstrap, lint, validate)
- `.github/` — Issue and PR templates

## Quick Start

Prerequisites: Docker Engine 24+, Docker Compose v2, and access to your container registry (if used).

1. Review `docs/architecture.md` and adapt to your environment.
2. Add service definitions (e.g., `docker-compose.yml`) and exporters you need (cAdvisor, node‑exporter).
3. Configure environment values under `configs/base/` and `configs/env/<env>/`.
4. Bring up the stack for your environment:
   - Example: `docker compose up -d` (adjust to your compose files)
5. Access observability:
   - Prometheus: [http://localhost:9090](http://localhost:9090)
   - Grafana: [http://localhost:3000](http://localhost:3000) (default creds: `admin` / set via env or secret)

## Configuration

- Base defaults live in `configs/base/`, with overrides in `configs/env/dev|staging|prod/`
- Do not commit secrets; use `*.example` files and a secrets manager or `.env` (excluded by `.gitignore`)
- Standardize labels/annotations for service discovery and dashboards

## Operations

- Lint/validate: `scripts/lint.sh`, `scripts/validate.sh`
- Runbooks: see `docs/runbooks/` for incident response and common tasks
- Dashboards: curate Grafana dashboards per service and publish IDs/URLs in `docs/`
- Alerts: maintain Prometheus rules with ownership and escalation paths

## Security

- Principle of least privilege for container users and volumes
- Network segmentation between app and observability networks
- Secrets managed out‑of‑band (vault/SSM/KMS). Avoid plain‑text credentials
- Regular base‑image and dependency updates; track CVEs

## Roadmap

- Add GitHub Actions for `terraform validate`, `yamllint`, `ansible-lint`
- Package observability into a reusable compose profile or Helm chart
- Prebuilt Grafana dashboards and Prometheus rules per service type

## Contributing

See `CONTRIBUTING.md` for branching, commit style, and PR workflow.

