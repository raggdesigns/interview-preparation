#!/usr/bin/env bash
# translation-sync-hook.sh — Warns about translation sync issues on commit.
# Non-blocking: prints warnings but always exits 0.

set -euo pipefail

# Excluded paths (not translatable)
EXCLUDED="^(CONTRIBUTING\.md|CODE_OF_CONDUCT\.md|LICENSE|\.github/|docs/|node_modules/|\.claude/)"

# Get staged .md files (added, modified, deleted)
ADDED_OR_MODIFIED=$(git diff --cached --name-only --diff-filter=AM -- '*.md' | grep -v '\.sr\.md$' | grep -Ev "$EXCLUDED" || true)
DELETED=$(git diff --cached --name-only --diff-filter=D -- '*.md' | grep -v '\.sr\.md$' | grep -Ev "$EXCLUDED" || true)
ALL_STAGED_SR=$(git diff --cached --name-only -- '*.sr.md' || true)

found_issues=false

# Check 1: New or modified English files — is the .sr.md also staged?
while IFS= read -r file; do
  [ -z "$file" ] && continue
  sr_file="${file%.md}.sr.md"
  if ! echo "$ALL_STAGED_SR" | grep -qx "$sr_file"; then
    if [ ! -f "$sr_file" ]; then
      echo "[translation-sync] WARNING: New file $file — no Serbian translation found ($sr_file)"
    else
      echo "[translation-sync] WARNING: Modified $file — check if $sr_file needs updating"
    fi
    found_issues=true
  fi
done <<< "$ADDED_OR_MODIFIED"

# Check 2: Deleted English files — does the .sr.md still exist?
while IFS= read -r file; do
  [ -z "$file" ] && continue
  sr_file="${file%.md}.sr.md"
  if [ -f "$sr_file" ] && ! echo "$ALL_STAGED_SR" | grep -qx "$sr_file"; then
    echo "[translation-sync] WARNING: Deleted $file — orphaned translation still exists ($sr_file)"
    found_issues=true
  fi
done <<< "$DELETED"

if [ "$found_issues" = true ]; then
  echo "[translation-sync] Run 'bash scripts/translation-coverage.sh' for full translation status."
fi

exit 0
