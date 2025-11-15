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

## Prerequisites
- Docker + Docker Compose (v2.20+ recommended for `include:` support)
- Host directories from the compose files exist (e.g. `/opt/mediaserver`, `/mnt/storage/data`, `/mnt/backup`)
- A `.env` file with your user IDs, timezone, and API keys (see below)

## Quick Start
1) Clone
```
git clone git@github.com:theglove44/logan-lxc.git
cd logan-lxc
```
2) Configure env
```
cp .env.example .env
# edit .env to set PUID/PGID/TZ/UMASK, HOST_LAN, and API keys
```
3) Bring up the main stack
```
docker compose up -d
```
4) Bring up the dashboard/monitoring addons
```
docker compose -f homepage-stack.yml up -d
```
5) Bootstrap Sonarr/Radarr/SABnzbd/Prowlarr wiring
```
./scripts/bootstrap-mediaserver.sh
```
This script waits for the apps to become reachable, prompts for their API keys, and wires up SABnzbd folders/categories, Sonarr/Radarr root folders + download clients, and Prowlarr applications that sync to Sonarr/Radarr.

### Compose combinations

The compose files under `docker/` are split into logical modules so you can tailor the deployment. The root `compose.yml` uses the Compose `include:` directive to load all modules (base defaults + core + automation + monitoring). To start specific slices, combine the fragments explicitly:

| Scenario | Command |
| --- | --- |
| Core media apps only | `docker compose -f docker/base.yml -f docker/core.yml up -d` |
| Core + automation (backups, watchtower) | `docker compose -f docker/base.yml -f docker/core.yml -f docker/automation.yml up -d` |
| Core + monitoring/security | `docker compose -f docker/base.yml -f docker/core.yml -f docker/monitoring.yml up -d` |
| Full stack (equivalent to `docker compose up -d`) | `docker compose -f docker/base.yml -f docker/core.yml -f docker/automation.yml -f docker/monitoring.yml up -d` |

Compose merges the files in the order given, so always list `docker/base.yml` first to register shared anchors, labels, and volume helpers used by other modules.

## Mediaserver CLI (ms)
To simplify day-to-day operations, use the `ms` helper script.

Install once
```
sudo ln -s /opt/mediaserver/scripts/ms /usr/local/bin/ms
# or add to PATH: echo 'export PATH=/opt/mediaserver/scripts:$PATH' >> ~/.bashrc && exec $SHELL
```

Common usage
```
# Start/stop stacks
ms up core|homepage|all
ms down core|homepage|all

# Status
ms ps all

# Service ops
ms restart sonarr
ms logs radarr
ms shell prowlarr            # interactive shell (bash or sh)
ms exec sonarr curl -s localhost:8989

# Updates
ms pull core                 # or homepage/all or a single service name
ms update all                # pull + recreate

# Jobs
ms recyclarr                 # run recyclarr sync once
ms backup                    # run a borgmatic backup once
ms watchtower                # trigger a one-time watchtower scan
```

Help
```
ms help
```

## Services & URLs (defaults)
- Homepage: http://HOST_LAN:3000 (stack: `homepage-stack.yml`)
- Jellyfin: http://HOST_LAN:8096
- Plex: http://HOST_LAN:32400 (host network)
- Overseerr: http://HOST_LAN:5155 (container 5055)
- SABnzbd: http://HOST_LAN:8080
- Sonarr: http://HOST_LAN:8989
- Radarr: http://HOST_LAN:7878
- Prowlarr: http://HOST_LAN:9696
- Bazarr: http://HOST_LAN:6767
- Tautulli: http://HOST_LAN:8181
- Filebrowser: http://HOST_LAN:8081
- Dozzle (logs): http://HOST_LAN:9999
- Prometheus: http://HOST_LAN:9090
- Grafana: http://HOST_LAN:3001 (admin/admin by default; anon viewer enabled)
- node-exporter: http://HOST_LAN:9100/metrics
- cAdvisor: http://HOST_LAN:8082

## Plex: official image and claiming
This stack uses the official Plex image for the server to ensure timely updates and compatibility with mobile and TV apps.

- Image: `plexinc/pms-docker:public` (stable/public builds)
- Runs with host networking for best discovery and remote access
- Maps `/config`, `/transcode`, and media paths as defined in `compose.yml`

Claiming the server (first run or after auth resets)
- Get a claim token while logged into Plex: https://plex.tv/claim
- Set `PLEX_CLAIM=claim-XXXX` in `.env` temporarily
- Restart just Plex: `docker compose up -d plex`
- Once claimed, clear `PLEX_CLAIM` in `.env` and restart Plex again

Keeping Plex updated
- The `public` tag fetches current stable builds when the container is restarted. Watchtower will also recreate the container on its schedule.
- If you have Plex Pass and want bleeding-edge builds, switch to `plexinc/pms-docker:beta` in `compose.yml`.

Permissions
- Plex runs as your host user/group by setting `PLEX_UID`/`PLEX_GID` from `.env` so it can read/write your media and metadata.

## Configuration
- `.env` (not committed)
  - PUID, PGID, TZ, UMASK
  - HOST_LAN (LAN IP/hostname of the host)
  - HOMEPAGE_VAR_HOST_LAN (same as HOST_LAN for dashboard links)
  - HOMEPAGE_VAR_SONARR_API_KEY, HOMEPAGE_VAR_RADARR_API_KEY, HOMEPAGE_VAR_SAB_API_KEY
  - HOMEPAGE_VAR_PLEX_TOKEN (auto-detected and saved)
  - HOMEPAGE_VAR_TAUTULLI_API_KEY (auto-detected by Tautulli)
  - HOMEPAGE_VAR_GRAFANA_USERNAME=admin, HOMEPAGE_VAR_GRAFANA_PASSWORD=admin (optional; anon viewer is enabled)
  - BORG_PASSPHRASE (encryption passphrase for Borg repository)

- Homepage config (`homepage/config/`)
  - `services.yaml` controls tiles and widgets; uses `{{HOMEPAGE_VAR_*}}` env vars
  - To apply changes: `docker compose -f homepage-stack.yml up -d homepage`

- Grafana
  - Provisioned dashboards and datasources under `grafana/`
  - Anonymous viewer access enabled; admin user is `admin/admin` (change it!)

## Monitoring
- Prometheus scrapes: node-exporter, cAdvisor, and any configured exporters
- Grafana dashboards included: system overview, cAdvisor, Homepage status
- Homepage shows live status via widgets for Sonarr/Radarr/SAB and Grafana

## Backups (local)
Tooling: borgmatic (encrypted, deduplicated)

- Container: `mediaserver-backup` (ghcr.io/borgmatic-collective/borgmatic)
- Repository: `/mnt/backup/mediaserver` (mounted from host)
- Schedule: 03:30 daily via container crond (see `backup/config/crontab.txt`)
- Config: `backup/config/config.yaml` (tracked in Git)
- Excludes: `backup/config/excludes.txt`
- Hooks: SQLite snapshot before backup (`backup/config/hooks.d/pre-backup.sh`)

Common operations
```
# Validate config
docker exec mediaserver-backup borgmatic config validate

# Run a backup now
docker exec mediaserver-backup borgmatic -v 0 --stats

# List archives / repo info
docker exec mediaserver-backup borgmatic list
docker exec mediaserver-backup borgmatic info
```

Restore (example)
```
# List archives and pick one
docker exec -it mediaserver-backup borgmatic list

# Extract a path from an archive to /restore (bind-mount as needed)
docker exec -it mediaserver-backup sh -lc \
  'borgmatic extract --archive latest --destination /restore --path home/…'
```
Important: Keep your `BORG_PASSPHRASE` safe. For repokey mode, export the Borg key and store it offline.

## Offsite backup (Google Drive)
Tooling: rclone sidecar with cron

- Container: `rclone_backup` (Alpine + crond + rclone)
- Schedule: 04:10 daily (`backup/rclone/crontab.txt`)
- Local path synced: `/mnt/backup/mediaserver` → `gdrive:mediaserver-borg`
- Configure rclone (one-time):
```
docker run -it --rm \
  -v /opt/mediaserver/backup/rclone:/config/rclone \
  rclone/rclone config
```
Verify and test
```
docker exec rclone_backup rclone about gdrive:
docker exec rclone_backup rclone size gdrive:mediaserver-borg
docker exec -it rclone_backup sh -lc 'rclone sync /data gdrive:mediaserver-borg --progress'
```

## Automated updates (Watchtower)
- Container: `watchtower` (Discord notifications via Shoutrrr)
- Schedule: 04:00 daily, rolling restarts, cleans old images
- Notifications: Daily summary and update reports to Discord
- Scope: All containers by default; to restrict by label, add `--label-enable` and label services with `com.centurylinklabs.watchtower.enable=true`

## Repository layout
- `compose.yml` — Aggregates the media stack modules via Compose `include:`
- `docker/base.yml` — Shared anchors, volumes, and network defaults
- `docker/core.yml` — Core media applications
- `docker/automation.yml` — Automation & maintenance jobs (recyclarr, watchtower, backups)
- `docker/monitoring.yml` — Monitoring and security helpers (tautulli, fail2ban)
- `homepage-stack.yml` — Homepage + monitoring add-ons
- `homepage/config/**` — Dashboard config (tracked)
- `grafana/**` — Provisioning and dashboards
- `prometheus/prometheus.yml` — Prometheus config
- `backup/config/**` — borgmatic config, excludes, hooks (tracked)
- `backup/rclone/crontab.txt` — rclone schedule (tracked)
- `.env` — secrets and instance values (ignored)

## Version control policy
- Tracked: compose files, Homepage configs, Grafana provisioning, `backup/config/**`, `backup/rclone/crontab.txt`
- Ignored: `.env`, appdata (service config dirs), `prometheus/data/`, Borg repo contents (`/mnt/backup`), `backup/rclone/rclone.conf` (rclone credentials)

## Maintenance cheatsheet
```
# Update images now (in addition to Watchtower schedule)
docker compose pull && docker compose up -d
docker compose -f homepage-stack.yml pull && docker compose -f homepage-stack.yml up -d

# Restart a single service
docker compose up -d sonarr

# View logs
docker logs -f sonarr
docker logs -f watchtower

# Same operations via the helper
ms update all
ms restart sonarr
ms logs radarr
```

## Notes
- Internal-only access: Homepage tiles use `HOMEPAGE_VAR_HOST_LAN`; links are LAN URLs.
- Grafana admin defaults are for local use; change the password or disable anonymous viewer for stricter access.
- Backups focus on app configuration and databases. Large media libraries are typically not backed up here (re-acquirable).
