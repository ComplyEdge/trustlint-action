#!/usr/bin/env bash
# run-scan.sh — wrapper for `trustlint check` / `trustlint scan`.
#
# Why this exists: the trustlint CLI takes one file (or --text) at a time.
# A GitHub Action wants to scan a glob set in one step. This script does the
# glob expansion (via Python — bash-version-agnostic, ** recursive works
# even on macOS's ancient /bin/bash 3.2), runs trustlint per file, emits
# GitHub-Actions annotations on violations, and aggregates the exit code.
#
# Args:
#   $1  paths               — space-separated globs (e.g. "**/prompts/*.md docs/*.md")
#   $2  jurisdiction        — EU | US | GLOBAL | universal
#   $3  fail_on_violation   — "true" | "false"
#   $4  severity_threshold  — critical | high | medium | low (default high)
#
# Env:
#   COMPLYEDGE_API_KEY  — optional; when set, tries `trustlint scan` (API). The CLI
#                         falls back to offline check if the API is unreachable.
#                         `severity-threshold` applies only to the offline `check`
#                         path (`scan` has no --severity-threshold flag).
#   GITHUB_OUTPUT       — set by GitHub Actions; we append `files-scanned` + `violating-files` outputs there

set -u  # strict-undefined, but NOT -e — we deliberately handle non-zero exits from trustlint

PATHS="${1:-}"
JURISDICTION="${2:-EU}"
FAIL_ON_VIOLATION="${3:-true}"
SEVERITY_THRESHOLD="${4:-high}"

# Expand globs via Python — supports ** recursive on every platform,
# avoids bash version sensitivity (macOS ships bash 3.2; ubuntu CI ships 5+).
FILES=$(python3 - "$PATHS" <<'PY'
import glob, os, sys
patterns = sys.argv[1].split() if len(sys.argv) > 1 else []
seen, ordered = set(), []
for pat in patterns:
    for f in glob.glob(pat, recursive=True):
        if f in seen or not os.path.isfile(f):
            continue
        seen.add(f)
        ordered.append(f)
print("\n".join(ordered))
PY
)

COUNT=0
VIOLATING_FILES=""
if [ -z "$FILES" ]; then
  echo "::notice::TrustLint: no files matched any of the configured paths — nothing to scan."
else
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    COUNT=$((COUNT + 1))
    echo "::group::trustlint: ${file}"
    if [ -n "${COMPLYEDGE_API_KEY:-}" ]; then
      # API path: scan has no --severity-threshold; CLI falls back to offline check on API errors.
      trustlint scan "$file" --api-key "$COMPLYEDGE_API_KEY"
    else
      trustlint check \
        --jurisdiction "$JURISDICTION" \
        --severity-threshold "$SEVERITY_THRESHOLD" \
        "$file"
    fi
    sub_exit=$?
    echo "::endgroup::"
    if [ $sub_exit -ne 0 ]; then
      VIOLATING_FILES="${VIOLATING_FILES}${file} "
      echo "::error file=${file}::TrustLint violation in ${file} (severity-threshold=${SEVERITY_THRESHOLD})"
    fi
  done <<< "$FILES"
fi

VIOLATING_FILES="${VIOLATING_FILES% }"  # strip trailing space
V_COUNT=0
if [ -n "$VIOLATING_FILES" ]; then
  V_COUNT=$(printf '%s' "$VIOLATING_FILES" | tr ' ' '\n' | grep -c .)
fi

echo
echo "TrustLint scanned ${COUNT} file(s); ${V_COUNT} violating."

echo "files-scanned=${COUNT}" >> "${GITHUB_OUTPUT:-/dev/null}"
echo "violating-files=${VIOLATING_FILES}" >> "${GITHUB_OUTPUT:-/dev/null}"

if [ -n "$VIOLATING_FILES" ] && [ "$FAIL_ON_VIOLATION" = "true" ]; then
  exit 1
fi
exit 0
