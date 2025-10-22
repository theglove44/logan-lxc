# Media stack compose modules

The stack is broken into composable fragments so you can pick the services that make sense for a given host.

## Files

| File | Purpose |
| --- | --- |
| `base.yml` | Defines the project name, shared anchors (users, labels, healthcheck defaults), named volumes, and the common bridge network. Always include this file first. |
| `core.yml` | Jellyfin, Plex, the *arr suite, SABnzbd, Overseerr, Bazarr, and Jellyseerr. These are the core media management services. |
| `automation.yml` | Operational helpers such as Recyclarr, Watchtower, Borgmatic backups, and the rclone sidecar. |
| `monitoring.yml` | Observability and security helpers (Tautulli metrics and Fail2ban log monitoring). |

## Typical combinations

```
# Core applications only
docker compose -f docker/base.yml -f docker/core.yml up -d

# Core + automation jobs
docker compose -f docker/base.yml -f docker/core.yml -f docker/automation.yml up -d

# Full stack (core + automation + monitoring)
docker compose -f docker/base.yml -f docker/core.yml -f docker/automation.yml -f docker/monitoring.yml up -d
```

Compose merges in order, so `docker/base.yml` must come first to expose the shared anchors that the other files reference.

If your Compose CLI is 2.20 or newer, `docker compose up -d` from the repository root will automatically include every fragment through the root `compose.yml`.
