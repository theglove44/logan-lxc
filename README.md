# Logan LXC Mediaserver

Reproducible Docker Compose stack for a personal media server with an internal dashboard, monitoring, automated updates, and backups (local + Google Drive offsite).

## Overview
- Core media automation: Jellyfin, Plex, Sonarr, Radarr, SABnzbd, Prowlarr, Overseerr, Bazarr, Tautulli, Filebrowser, Dozzle.
- Observability and control plane: Prometheus, node-exporter, cAdvisor, Grafana (provisioned dashboards), Homepage dashboard.
- Operations guardrails: Watchtower (Discord notifications), borgmatic (local encrypted backups), rclone (Google Drive sync).

## Stack at a glance
| Area | Compose file | Services | Highlights |
| --- | --- | --- | --- |
| Media & requests | `compose.yml` | Jellyfin, Plex (host network), Sonarr, Radarr, SABnzbd, Prowlarr, Overseerr, Bazarr, Tautulli, Filebrowser, Dozzle | Primary automation and user-facing apps.
| Dashboards & monitoring | `homepage-stack.yml` | Homepage, Prometheus, node-exporter, cAdvisor, Grafana | Pre-provisioned dashboards and status widgets for the stack.
| Maintenance & automation | `compose.yml` & `homepage-stack.yml` | Watchtower, borgmatic, rclone sidecar | Automated updates, encrypted backups, and offsite sync to Google Drive.

## Quick start (TL;DR)
1. Prepare the host with Docker, Docker Compose, and the directories referenced in `compose.yml`.
2. Copy `.env.example` to `.env`, adjust the values for your host, and review the generated [environment variable reference](docs/env-vars.md).
3. Bring up the core stack with `docker compose up -d`, then start dashboard/monitoring addons via `docker compose -f homepage-stack.yml up -d`.
4. Install the optional `ms` helper script for day-to-day operations (see [Operations](docs/operations.md)).

Detailed guidance for each step lives in the dedicated docs below.

## Documentation
- [Setup](docs/setup.md): prerequisites, environment configuration, and stack bootstrap.
- [Operations](docs/operations.md): helper CLI usage, service URLs, monitoring, and maintenance.
- [Backups](docs/backups.md): borgmatic workflow, restore playbooks, and rclone offsite sync.
- [Environment variables](docs/env-vars.md): generated reference derived from `.env.example`.

## Keeping documentation and configuration aligned
Environment variables documented in `docs/env-vars.md` are generated directly from `.env.example`. Re-run the helper whenever `.env.example` changes:

```bash
python scripts/generate_env_docs.py
```

This ensures the configuration surface area remains accurate across the README and subpages.

## Repository highlights
- `compose.yml` — Core media and automation services.
- `homepage-stack.yml` — Dashboard and observability add-ons.
- `homepage/config/**` — Homepage tiles and widgets backed by environment variables.
- `grafana/**` — Provisioned dashboards and data sources with anonymous viewer access enabled by default.
- `backup/config/**` & `backup/rclone/**` — borgmatic configuration, schedules, and rclone cron definitions.

For day-to-day workflows, jump into the [operations guide](docs/operations.md); for protection strategies, head to the [backup runbook](docs/backups.md).
