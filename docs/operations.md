# Operations

Day-to-day workflows, service entry points, and helper tooling for the mediaserver stack.

## Mediaserver CLI (`ms`)
The `ms` helper script wraps common Docker Compose actions and bespoke jobs.

### Installation recap
```bash
sudo ln -s /opt/mediaserver/scripts/ms /usr/local/bin/ms
# or add /opt/mediaserver/scripts to your PATH
```

### Common usage
```bash
# Start/stop stacks
ms up core|homepage|all
ms down core|homepage|all

# Status
ms ps all

# Service operations
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

# Help
ms help
```

## Service endpoints (defaults)
- Homepage: <http://HOST_LAN:3000> (`homepage-stack.yml`)
- Jellyfin: <http://HOST_LAN:8096>
- Plex: <http://HOST_LAN:32400> (host network)
- Overseerr: <http://HOST_LAN:5155> (container 5055)
- SABnzbd: <http://HOST_LAN:8080>
- Sonarr: <http://HOST_LAN:8989>
- Radarr: <http://HOST_LAN:7878>
- Prowlarr: <http://HOST_LAN:9696>
- Bazarr: <http://HOST_LAN:6767>
- Tautulli: <http://HOST_LAN:8181>
- Filebrowser: <http://HOST_LAN:8081>
- Dozzle (logs): <http://HOST_LAN:9999>
- Prometheus: <http://HOST_LAN:9090>
- Grafana: <http://HOST_LAN:3001> (admin/admin by default; anonymous viewer enabled)
- node-exporter: <http://HOST_LAN:9100/metrics>
- cAdvisor: <http://HOST_LAN:8082>

## Plex: official image and claiming
- Image: `plexinc/pms-docker:public` (stable/public builds).
- Host networking for best discovery and remote access.
- Maps `/config`, `/transcode`, and media paths as defined in `compose.yml`.

### Claim the server
1. Obtain a claim token while logged into Plex: <https://plex.tv/claim>.
2. Set `PLEX_CLAIM=claim-XXXX` in `.env` temporarily.
3. Restart just Plex: `docker compose up -d plex`.
4. Once claimed, clear `PLEX_CLAIM` in `.env` and restart Plex again.

### Updates and permissions
- `public` tag tracks current stable builds; Watchtower will recreate the container on its schedule.
- Plex runs as your host user/group via `PLEX_UID`/`PLEX_GID` so it can read/write media and metadata.

## Monitoring
- Prometheus scrapes node-exporter, cAdvisor, and any additional exporters you configure.
- Grafana ships with dashboards for system overview, container metrics, and Homepage status.
- Homepage widgets surface Sonarr/Radarr/SAB status and Grafana links using `HOMEPAGE_VAR_*` environment variables.

## Automated updates (Watchtower)
- Container: `watchtower` (Discord notifications via Shoutrrr).
- Schedule: 04:00 daily, rolling restarts, cleans old images.
- Notifications: daily summary and update reports to Discord.
- Scope: all containers by default; to restrict by label, add `--label-enable` and set `com.centurylinklabs.watchtower.enable=true` on desired services.

## Maintenance cheatsheet
```bash
# Update images now (in addition to the Watchtower schedule)
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

## Configuration management
- `.env` holds per-host secrets and instance values; keep it out of version control.
- Homepage dashboard files live in `homepage/config/` and support templating via `{{HOMEPAGE_VAR_*}}` values.
- Grafana provisioning is tracked under `grafana/` with anonymous viewer access enabled; change the admin password immediately.
- Version control policy: compose files, Homepage config, Grafana provisioning, borgmatic configuration (`backup/config/**`), and rclone schedules (`backup/rclone/crontab.txt`) are tracked. App data directories, Prometheus data, Borg repositories, and rclone credentials stay untracked.

## Additional notes
- Homepage tiles default to LAN URLs; adjust if exposing services beyond the internal network.
- Backups focus on app configuration and databases. Large media libraries are typically re-hydratable and are not backed up by default.
