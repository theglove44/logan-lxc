# Backups

Local and offsite strategies for safeguarding application configuration and metadata.

## Local backups (borgmatic)
- Container: `mediaserver-backup` (`ghcr.io/borgmatic-collective/borgmatic`).
- Repository: `/mnt/backup/mediaserver` (mounted from the host).
- Schedule: 03:30 daily via container `crond` (`backup/config/crontab.txt`).
- Config: `backup/config/config.yaml` (tracked in Git).
- Excludes: `backup/config/excludes.txt`.
- Hooks: SQLite snapshot before backup (`backup/config/hooks.d/pre-backup.sh`).

### Common operations
```bash
# Validate the borgmatic configuration
docker exec mediaserver-backup borgmatic config validate

# Run a backup now
docker exec mediaserver-backup borgmatic -v 0 --stats

# List archives / repository info
docker exec mediaserver-backup borgmatic list
docker exec mediaserver-backup borgmatic info
```

### Restore example
```bash
# Inspect available archives
docker exec -it mediaserver-backup borgmatic list

# Extract a path from an archive to /restore (bind-mount as needed)
docker exec -it mediaserver-backup sh -lc \
  'borgmatic extract --archive latest --destination /restore --path home/…'
```

> Keep your `BORG_PASSPHRASE` safe. When using repokey mode, export the Borg key and store it offline alongside your passphrase.

## Offsite sync (Google Drive via rclone)
- Container: `rclone_backup` (Alpine + `crond` + `rclone`).
- Schedule: 04:10 daily (`backup/rclone/crontab.txt`).
- Local path synced: `/mnt/backup/mediaserver` → `gdrive:mediaserver-borg`.

### First-time rclone configuration
```bash
docker run -it --rm \
  -v /opt/mediaserver/backup/rclone:/config/rclone \
  rclone/rclone config
```

### Validation commands
```bash
docker exec rclone_backup rclone about gdrive:
docker exec rclone_backup rclone size gdrive:mediaserver-borg
docker exec -it rclone_backup sh -lc 'rclone sync /data gdrive:mediaserver-borg --progress'
```

Regularly confirm backups complete successfully and test restores to ensure your recovery plan works as expected.
