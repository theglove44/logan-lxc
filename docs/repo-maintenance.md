# Repository Maintenance & Branch Review

## Current branch state
- `work` is the only local branch in the repository. No remotes are configured, so there are no tracked upstream branches or open pull requests to audit.
- A `git fsck --full` check (2025-10-21) completed without errors, indicating that the object database is healthy and free of dangling or corrupt objects.

## Recommended clean-up actions
1. **Establish an authoritative main branch**
   - If `work` represents production-ready configuration, rename it to `main` (or create a `main` branch from its tip) so future contributors have a clear default target for pull requests.
   - Protect the main branch in your hosting provider to enforce reviews and prevent force pushes.

2. **Archive or prune historical exposure branches**
   - After running the history sanitisation workflow (`scripts/sanitize-history.sh`), force-push the cleaned history to the public remote.
   - Delete any forks or stale branches that still contain the leaked IP addresses so that the scrubbed history becomes canonical.

3. **Document branch workflow for contributors**
   - Require feature work to happen on topic branches named after the issue/feature (e.g., `feature/secure-proxy`).
   - Merge into `main` via reviewed pull requests to keep the history linear and auditable.

4. **Automate repository health checks**
   - Add a CI job that runs `git fsck --full`, `trufflehog`, and compose linting on every push to catch regressions early.
   - Publish the maintenance checklist in CONTRIBUTING.md so future maintainers repeat the process.

5. **Tag security-relevant milestones**
   - Create signed tags after major security remediation steps (e.g., history rewrite, secret rotation) to anchor a clean baseline that teams can audit against.

## Next steps for publishing
1. Run `scripts/sanitize-history.sh` locally with the replacement map confirmed in `docs/history-sanitization.md`.
2. Force-push the rewritten history to the remote repository (e.g., `git push --force origin main`).
3. Immediately rotate any secrets or IP allowlists that were previously exposed, as clones may still exist.
4. Communicate the updated branching policy to collaborators and require fresh clones from the sanitised history.

