#!/usr/bin/env bash
set -euo pipefail

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "This script must be run inside a Git repository." >&2
  exit 1
fi

# List of literal replacements to apply everywhere in history.
# Each entry is old_value=>new_value.
replacements=(
  '10.0.0.100=>host.example.lan'
  '10.0.0.179=>host-backup.example.lan'
  '100.76.120.49=>tailscale.example.com'
  '100.64.0.0/24=>tailscale-range.example'
  '82.71.63.30=>203.0.113.10'
)

create_filter_repo_file() {
  local tmpfile
  tmpfile=$(mktemp)
  for mapping in "${replacements[@]}"; do
    local find=${mapping%%=>*}
    local replace=${mapping##*=>}
    printf 'literal:%s\n%s\n' "$find" "$replace" >>"$tmpfile"
  done
  printf '%s' "$tmpfile"
}

run_filter_repo() {
  local replace_file
  replace_file=$(create_filter_repo_file)
  git filter-repo --force --replace-text "$replace_file"
  rm -f "$replace_file"
}

run_filter_branch() {
  FILTER_BRANCH_SQUELCH_WARNING=1 \
  git filter-branch --force --tree-filter "\
    python3 - <<'PY'\
from pathlib import Path\
replacements = {\
    '10.0.0.100': 'host.example.lan',\
    '10.0.0.179': 'host-backup.example.lan',\
    '100.76.120.49': 'tailscale.example.com',\
    '100.64.0.0/24': 'tailscale-range.example',\
    '82.71.63.30': '203.0.113.10',\
}\
for path in Path('.').rglob('*'): \
    if not path.is_file():\
        continue\
    try:\
        data = path.read_text(encoding='utf-8')\
    except (UnicodeDecodeError, OSError):\
        continue\
    new_data = data\
    for find, replace in replacements.items():\
        new_data = new_data.replace(find, replace)\
    if new_data != data:\
        path.write_text(new_data, encoding='utf-8')\
PY" --tag-name-filter cat -- --all
}

if command -v git-filter-repo >/dev/null 2>&1; then
  echo "Using git-filter-repo to rewrite history" >&2
  run_filter_repo
else
  echo "git-filter-repo not found; falling back to git filter-branch" >&2
  run_filter_branch
fi

git for-each-ref --format='%(refname)' refs/original/ | xargs -r -n1 git update-ref -d
rm -rf .git/filter-branch

echo "History rewritten. Review the results, then force-push to remote:" >&2
echo "  git push --force-with-lease <remote> <branch>" >&2
