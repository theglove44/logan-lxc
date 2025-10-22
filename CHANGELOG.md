# Changelog

All notable changes to this project will be documented in this file. Dates use the UTC timezone.

## [v0.2] - 2025-10-22
### Changed
- Switched Plex to the official `plexinc/pms-docker:public` image and run it under the host UID/GID to satisfy mobile clients.
- Documented the Plex claim flow, new environment variables, and permission expectations for the updated container image.
- Refreshed Grafana's compose definition and vendored plugins (Explore Traces, Metrics Drilldown, Pyroscope) to their current releases.
- Consolidated Watchtower's Discord reporting into a single readable template compatible with docker-compose variable escaping.

## [v0.1] - 2025-09-02
### Added
- Introduced the base homelab stack with Homepage, Prometheus, and Grafana dashboards wired into docker-compose.
- Added Tautulli monitoring with matching Homepage widget content.
- Provisioned Borgmatic-based backups with rclone-driven Google Drive offsite sync and persisted configuration templates.
