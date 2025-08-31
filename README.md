# Logan LXC Mediaserver

A lightweight, reproducible Docker Compose stack for a personal media server (Jellyfin/Plex, Sonarr, Radarr, SABnzbd, Prowlarr, Overseerr/Bazarr, Recyclarr) plus helper scripts for recovery and key checks.

## Prerequisites
- Docker and Docker Compose
- SSH key access to GitHub (`git@github.com:theglove44/logan-lxc.git`)
- Host directories mapped in `compose.yml` exist (e.g. `/opt/mediaserver`, `/mnt/storage/data`)

## Quick Start
1. Clone the repo:
   ```
   git clone git@github.com:theglove44/logan-lxc.git
   cd logan-lxc
   ```
2. Create `.env` from example and adjust values:
   ```
   cp .env.example .env
   ```
3. Bring the stack up:
   ```
   docker compose up -d
   ```
4. Access services (defaults): Jellyfin `:8096`, SABnzbd `:8080`, Sonarr `:8989`, Radarr `:7878`, Overseerr `:5155` (mapped to `5055`). Plex runs in host network.

## Structure
- `compose.yml` — Services and volumes
- `scripts/` — Utilities:
  - `print-and-test-apikeys.sh`: reads API keys from `/opt/mediaserver/{sonarr,radarr}/config.xml` and tests `/api/v3/system/status`.
  - `recover-sonarr.sh` / `recover-radarr.sh`: restore appdata from an old host via rsync; review host/path before use.
- `recyclarr/configs/` — Recyclarr config templates

## Configuration
- Copy and edit `.env.example` to `.env` (kept out of git). Do not commit real secrets.
- Recyclarr: copy `recyclarr/configs/config.example.yaml` to `recyclarr/configs/config.yaml` and set your API keys or adjust to source from env.

## Notes
- The repo intentionally ignores appdata (volumes) to avoid committing large, mutable data and secrets.
- If migrating, update the old host/port/path variables inside recovery scripts before running.
- Hardware transcoding is enabled via `/dev/dri`; remove if not needed.
