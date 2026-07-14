#!/usr/bin/env bash
# post-pr-comment.sh — collect per-file trustlint --json output, render a
# Markdown comment via render_pr_comment.py, post idempotently to the PR.
#
# Why this exists: the v0 action ships the run-scan.sh wrapper that prints
# a human-readable report and aggregates exit codes. For the PR-comment
# formatter (follow-up to the --json work) we need a separate
# step that captures JSON output. Re-running trustlint here (rather than
# inside run-scan.sh) keeps the two scripts orthogonal and lets users opt
# into PR comments via the `comment-on-pr` action input.
#
# Args:
#   $1  paths               — space-separated globs (same as run-scan.sh)
#   $2  jurisdiction        — EU | US | GLOBAL | universal
#   $3  severity_threshold  — critical | high | medium | low
#
# Env:
#   GH_TOKEN              — token with `pull-requests: write`
#   GITHUB_REPOSITORY     — set by Actions
#   GITHUB_RUN_ID         — set by Actions
#   GITHUB_EVENT_NUMBER   — PR number for pull_request events (Actions-provided)
#   PR_NUMBER             — fallback if GITHUB_EVENT_NUMBER isn't set
#   COMPLYEDGE_API_KEY    — optional; presently NOT used (post-comment relies on
#                           offline `trustlint check --json` — `trustlint scan`
#                           does not have a --json mode yet)

set -u

PATHS="${1:-}"
JURISDICTION="${2:-EU}"
SEVERITY_THRESHOLD="${3:-high}"

PR_NUMBER="${GITHUB_EVENT_NUMBER:-${PR_NUMBER:-}}"
if [ -z "${PR_NUMBER:-}" ]; then
  echo "::notice::trustlint-action: not a pull_request event (no PR number) — skipping PR comment."
  exit 0
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "::warning::trustlint-action: gh CLI not on PATH — cannot post PR comment."
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JSONL=$(mktemp)
trap 'rm -f "$JSONL" "$BODY_FILE" 2>/dev/null || true' EXIT

# Expand globs (same Python helper as run-scan.sh — keeps behaviour identical)
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

if [ -z "$FILES" ]; then
  echo "::notice::trustlint-action: no files matched paths — nothing to render for PR comment."
  exit 0
fi

while IFS= read -r file; do
  [ -n "$file" ] || continue
  # --severity-threshold doesn't affect the JSON payload (it only governs
  # the exit code). The renderer uses the per-file summary to colour-code
  # severity tiers, so we want the full report regardless of threshold.
  trustlint check --json \
    --jurisdiction "$JURISDICTION" \
    --severity-threshold "$SEVERITY_THRESHOLD" \
    "$file" >> "$JSONL" 2>/dev/null || true
  # Each trustlint check --json prints one JSON object; ensure newline-terminated
  echo "" >> "$JSONL"
done <<< "$FILES"

BODY_FILE=$(mktemp)
python3 "${SCRIPT_DIR}/render_pr_comment.py" "$JSONL" > "$BODY_FILE"

# Idempotent post: --edit-last updates the most recent comment by the calling
# actor (github-actions[bot]). If no prior comment exists, fall back to a
# fresh post.
if gh pr comment "$PR_NUMBER" --edit-last --body-file "$BODY_FILE" 2>/dev/null; then
  echo "✓ trustlint-action: updated existing PR comment on #${PR_NUMBER}."
else
  if ! gh pr comment "$PR_NUMBER" --body-file "$BODY_FILE"; then
    echo "::error::trustlint-action: gh pr comment failed — check the token has 'pull-requests: write'."
    exit 0  # don't fail the workflow just for the comment
  fi
  echo "✓ trustlint-action: posted new PR comment on #${PR_NUMBER}."
fi

exit 0
