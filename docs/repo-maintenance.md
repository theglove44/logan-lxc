# Repository Maintenance & Branch Review

This checklist tracks the hardening and hygiene work that keeps the public
repository safe to publish and easy to collaborate on. Items marked as
completed already have automation or policy in place; revisit them regularly to
make sure the guardrails stay intact.

## Baseline hardening checklist
- [x] **Default branch established** — `work` has been renamed to the canonical
  `main` branch so contributors have a clear target for pull requests and
  release tags.
- [x] **History sanitisation tooling shipped** —
  [`scripts/sanitize-history.sh`](../scripts/sanitize-history.sh) and
  [`docs/history-sanitization.md`](history-sanitization.md) provide a repeatable
  process for rewriting any leaked LAN, Tailscale, or public IP addresses before
  publishing.
- [x] **Branch workflow documented** — The contribution guide sets expectations
  for topic branches, reviews, and protected mainline history
  (see [`CONTRIBUTING.md`](../CONTRIBUTING.md)).
- [x] **Automated health checks in CI** — The "Repository Maintenance Checks"
  workflow runs `git fsck --full`, a verified `trufflehog` scan, and Compose
  validation on every push and pull request.
- [x] **Security milestones tracked** — Signed tags should be created after
  major remediations (history rewrite, secret rotation, etc.) to anchor audit
  points.

## Ongoing tasks before publishing updates
1. Run `scripts/sanitize-history.sh` locally when sensitive IPs or secrets may
   have leaked into history, then force-push the rewritten branch to the remote.
2. Remove or archive any forks and stale branches that still contain the
   pre-sanitised history so the cleaned branch becomes authoritative.
3. Require new work to land via reviewed pull requests that merge into `main`
   from short-lived topic branches (e.g. `feature/hardening-proxy`).
4. Rotate credentials that were ever committed (webhooks, API keys, allowlisted
   IPs) because older clones may still exist even after rewriting history.

## Automated checks
- `scripts/run-maintenance-checks.sh` runs the same suite used in CI: Git object
  verification, verified secret scanning with `trufflehog`, and `docker compose
  config` validation for both stacks.
- The GitHub Actions workflow in
  [`.github/workflows/repo-maintenance.yml`](../.github/workflows/repo-maintenance.yml)
  executes on pushes to `main`, pull requests, and manual workflow dispatches.
  Keep the script and workflow in sync so local and CI runs match.

## Governance tips
- Protect `main` in your hosting provider to disallow direct pushes and force
  status checks to pass before merging.
- Keep forks private until the sanitised history is force-pushed; delete any
  forks that predate the rewrite.
- Require contributors to acknowledge the secret/IP policy in their pull
  requests (link to the relevant section in `CONTRIBUTING.md`).
- After publishing cleaned history, create a signed tag (for example,
  `security/baseline-2025-10-21`) and note the rotation steps taken in the tag
  message for auditors.
