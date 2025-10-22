# Repository history sanitization

Use this playbook to rewrite the Git history and scrub the LAN, Tailscale, and
public IPs that were previously committed to the repository. The process
replaces the following sensitive literals everywhere in history:

- `10.0.0.100` → `host.example.lan`
- `10.0.0.179` → `host-backup.example.lan`
- `100.76.120.49` → `tailscale.example.com`
- `100.64.0.0/24` → `tailscale-range.example`
- `82.71.63.30` → `203.0.113.10`

## 1. Rewrite the history locally

Run the helper script from the repository root. It will prefer
[`git-filter-repo`](https://github.com/newren/git-filter-repo) if installed and
fall back to `git filter-branch` otherwise.

```bash
scripts/sanitize-history.sh
```

Inspect the rewritten history (e.g. `git log -S '10.0.0.100' --all`) to confirm
the literals no longer appear.

## 2. Force-push the sanitized history

After verifying the rewrite, push the cleaned branch to your remote and delete
any backup refs the script may have produced:

```bash
git push --force-with-lease origin main
```

Repeat the push for any other published branches or tags that contained the
original commits.

## 3. Prevent future regressions

1. Keep site-specific IPs, hostnames, and allowlists in private `.env` or
   `*.local` files that stay untracked.
2. Run secret-scanning tooling (`git secrets`, `trufflehog`, etc.) before
   pushing to catch hard-coded endpoints early.
3. If new sensitive data slips in, rerun `scripts/sanitize-history.sh` and force
   push again before sharing the repository.

