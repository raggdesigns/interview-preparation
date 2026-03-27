#!/usr/bin/env bash
# translation-coverage.sh — Reports translation coverage across all domains.

set -euo pipefail

# Translatable domains
DOMAINS=(architecture caching ddd general highload javascript microservices mysql oop php solid symfony testing)

# Excluded files (not translatable)
EXCLUDED_FILES=("CONTRIBUTING.md" "CODE_OF_CONDUCT.md" "LICENSE")

total_en=0
total_sr=0
missing_files=()
stale_files=()

echo ""
echo "Translation Coverage Report"
echo "==========================="
echo ""

# Root docs
for root_file in README.md TOPIC_TEMPLATE.md; do
  if [ -f "$root_file" ]; then
    total_en=$((total_en + 1))
    sr_file="${root_file%.md}.sr.md"
    if [ -f "$sr_file" ]; then
      total_sr=$((total_sr + 1))
      # Check staleness via git log
      en_ts=$(git log -1 --format=%ct -- "$root_file" 2>/dev/null || echo 0)
      sr_ts=$(git log -1 --format=%ct -- "$sr_file" 2>/dev/null || echo 0)
      if [ "$en_ts" -gt "$sr_ts" ] 2>/dev/null; then
        en_date=$(git log -1 --format=%ci -- "$root_file" 2>/dev/null | cut -d' ' -f1)
        sr_date=$(git log -1 --format=%ci -- "$sr_file" 2>/dev/null | cut -d' ' -f1)
        stale_files+=("  $sr_file (English: $en_date, Serbian: $sr_date)")
      fi
    else
      missing_files+=("  $root_file")
    fi
  fi
done

# Per-domain stats
echo "By domain:"
for domain in "${DOMAINS[@]}"; do
  domain_en=0
  domain_sr=0

  while IFS= read -r file; do
    # Skip excluded files
    basename_file=$(basename "$file")
    skip=false
    for excl in "${EXCLUDED_FILES[@]}"; do
      if [ "$basename_file" = "$excl" ]; then
        skip=true
        break
      fi
    done
    if [ "$skip" = true ]; then continue; fi

    domain_en=$((domain_en + 1))
    total_en=$((total_en + 1))

    sr_file="${file%.md}.sr.md"
    if [ -f "$sr_file" ]; then
      domain_sr=$((domain_sr + 1))
      total_sr=$((total_sr + 1))
      # Check staleness
      en_ts=$(git log -1 --format=%ct -- "$file" 2>/dev/null || echo 0)
      sr_ts=$(git log -1 --format=%ct -- "$sr_file" 2>/dev/null || echo 0)
      if [ "$en_ts" -gt "$sr_ts" ] 2>/dev/null; then
        en_date=$(git log -1 --format=%ci -- "$file" 2>/dev/null | cut -d' ' -f1)
        sr_date=$(git log -1 --format=%ci -- "$sr_file" 2>/dev/null | cut -d' ' -f1)
        stale_files+=("  $sr_file (English: $en_date, Serbian: $sr_date)")
      fi
    else
      missing_files+=("  $file")
    fi
  done < <(find "$domain" -name "*.md" ! -name "*.sr.md" | sort)

  if [ "$domain_en" -gt 0 ]; then
    pct=$((domain_sr * 100 / domain_en))
    printf "  %-16s %3d/%-3d (%d%%)\n" "$domain:" "$domain_sr" "$domain_en" "$pct"
  fi
done

echo ""
if [ "$total_en" -gt 0 ]; then
  pct=$((total_sr * 100 / total_en))
else
  pct=0
fi
echo "Overall: $total_sr/$total_en files translated ($pct%)"

if [ ${#missing_files[@]} -gt 0 ]; then
  echo ""
  echo "Missing translations (${#missing_files[@]}):"
  printf '%s\n' "${missing_files[@]}"
fi

if [ ${#stale_files[@]} -gt 0 ]; then
  echo ""
  echo "Potentially stale (${#stale_files[@]}):"
  printf '%s\n' "${stale_files[@]}"
fi

echo ""
