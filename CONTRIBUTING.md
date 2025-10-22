# Contributing to Logan LXC Mediaserver

Thanks for helping keep the stack secure. Because this repository previously
contained sensitive IP addresses and webhook tokens, we enforce a few extra
steps before accepting changes.

## Branching model
- The default branch is `main`.
- Create short-lived topic branches for all work using the
  `type/short-description` pattern (e.g. `feature/hardening-proxy`,
  `fix/docs-typo`).
- Open pull requests from your topic branch into `main` and request a review
  before merging.
- Force pushes are disallowed on `main`; use the sanitisation workflow if you
  need to rewrite history (see below).

## Required maintenance checks
Run the automated maintenance suite before pushing:

```bash
scripts/run-maintenance-checks.sh
```

The script verifies the Git object database, runs a verified `trufflehog`
secrets scan, and validates both Compose stacks. The GitHub Actions workflow
(`Repository Maintenance Checks`) runs the same script, so matching local
results should pass CI.

If you do not have Docker available locally, run the script inside a
Docker-enabled environment (e.g. GitHub Codespaces) so the Compose validation
steps are exercised.

## Secrets & IP hygiene
- Never commit real API keys, webhooks, LAN addresses, or allowlisted public
  IPs. Store them in your private `.env` files instead.
- Prefer placeholders such as `host.example.lan` or `tailscale.example.com` when
  documenting configuration examples.
- If sensitive values are committed, immediately run the history sanitisation
  workflow and rotate the exposed credentials.

## History sanitisation
The repository includes a playbook and automation for rewriting leaked values:

1. Follow [`docs/history-sanitization.md`](docs/history-sanitization.md) to
   confirm the replacement map.
2. Run [`scripts/sanitize-history.sh`](scripts/sanitize-history.sh) locally.
3. Force-push the rewritten branch to the remote and delete any forks or stale
   branches that still contain the leaked history.
4. Rotate all affected credentials after publishing the sanitised history.

## Pull request checklist
- [ ] Maintenance checks pass locally (`scripts/run-maintenance-checks.sh`).
- [ ] Documentation updated if behaviour, configuration, or requirements change.
- [ ] Secrets/IP policy verified (no real endpoints committed).
- [ ] Tests added or updated where applicable.

Thank you for keeping the mediaserver secure and reproducible!
