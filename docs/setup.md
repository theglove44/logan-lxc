# Setup

This guide walks through preparing a host, configuring environment values, and bringing the mediaserver stack online.

## Prerequisites
- Docker Engine and Docker Compose installed on the host.
- Host directories declared in `compose.yml` created ahead of time (for example `/opt/mediaserver`, `/mnt/storage/data`, `/mnt/backup`).
- Network access to the services you plan to expose (LAN IP, optional Tailscale network, etc.).

## Clone the repository
```bash
git clone git@github.com:theglove44/logan-lxc.git
cd logan-lxc
```

## Configure environment variables
1. Seed a local `.env` file from the template:
   ```bash
   cp .env.example .env
   ```
2. Adjust user, group, timezone, networking, and API token values to match your host. The generated [environment variable reference](env-vars.md) describes every option tracked in `.env.example`.
3. Commit changes to `.env.example` (if you make any) and re-run `python scripts/generate_env_docs.py` so documentation stays synchronized.

## Bring up the stack
1. Start the core media services:
   ```bash
   docker compose up -d
   ```
2. Launch dashboard and monitoring add-ons:
   ```bash
   docker compose -f homepage-stack.yml up -d
   ```
3. Verify containers are healthy (`docker compose ps`) before exposing services.

## Optional helper CLI (`ms`)
For streamlined day-to-day operations you can install the bundled helper script:
```bash
sudo ln -s /opt/mediaserver/scripts/ms /usr/local/bin/ms
# or add the scripts directory to PATH
# echo 'export PATH=/opt/mediaserver/scripts:$PATH' >> ~/.bashrc && exec $SHELL
```
Usage details live in the [operations guide](operations.md#mediaserver-cli-ms).

## Initial configuration touches
- **Homepage dashboard**: tweak tiles and widgets under `homepage/config/`, then redeploy with `docker compose -f homepage-stack.yml up -d homepage`.
- **Grafana**: default credentials are `admin/admin`; anonymous viewer access is pre-enabled. Change the password or adjust provisioning under `grafana/`.
- **Plex claiming**: fetch a claim token from <https://plex.tv/claim>, set `PLEX_CLAIM=claim-XXXX` in `.env`, restart Plex (`docker compose up -d plex`), then remove the claim token once the server is linked.

## Next steps
With the stack running, continue to the [operations guide](operations.md) for routine workflows and to the [backup runbook](backups.md) to secure your configuration data.
