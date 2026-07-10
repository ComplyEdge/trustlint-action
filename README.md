# ComplyEdge TrustLint — GitHub Action (v0 source)

A composite GitHub Action that scans your repo's AI-prompt / agent-instruction files against the [EU AI Act](https://eur-lex.europa.eu/eli/reg/2024/1689) rule corpus using the [`trustlint`](https://pypi.org/project/trustlint/) CLI. Fails the workflow on critical violations to block merge.

> **Source-of-truth location:** this monorepo at `packages/trustlint-action/`. The public consumer-facing repo will be `complyedge/trustlint-action` (publish workflow + repo creation is a separate follow-up — see "Roadmap" below). Until then, consume the action from a forked path; on origin/main it is exercised end-to-end by `.github/workflows/trustlint-action-selftest.yml`.

## Usage (after `complyedge/trustlint-action@v1` is published)

```yaml
# .github/workflows/compliance.yml
name: ComplyEdge
on: [push, pull_request]

jobs:
  trustlint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: complyedge/trustlint-action@v1
        with:
          jurisdiction: EU
          paths: '**/prompts/*.md **/prompts/*.txt agents/*.system.md'
          api-key: ${{ secrets.COMPLYEDGE_API_KEY }}   # optional; uses offline check if empty
          fail-on-violation: 'true'
```

## Inputs

| Name | Required | Default | Description |
|---|---|---|---|
| `paths` | no | `**/prompts/*.md **/prompts/*.txt **/*.prompt agents/*.system.md` | Space-separated bash globs of files to scan. |
| `jurisdiction` | no | `EU` | Jurisdiction filter for the rule corpus (`EU` / `US` / `GLOBAL` / `universal`). |
| `api-key` | no | empty | ComplyEdge API key. Set ⇒ `trustlint scan` (API-backed). Empty ⇒ `trustlint check` (offline regex). Always pass as a secret. |
| `severity-threshold` | no | `high` | Minimum severity that causes the workflow to fail: `critical` / `high` / `medium` / `low`. Default `high` matches the CLI default. |
| `fail-on-violation` | no | `true` | When `true`, the workflow fails on violations at-or-above `severity-threshold`. Set `false` to surface as annotations only. |
| `comment-on-pr` | no | `false` | Post a Markdown violation report on the PR (idempotent via `gh pr comment --edit-last`). Only fires on `pull_request` events. **Requires `permissions: pull-requests: write` at the workflow or job level.** |
| `github-token` | no | `${{ github.token }}` | Token used by `gh pr comment` when `comment-on-pr: true`. Defaults to the workflow's `GITHUB_TOKEN`; override with a PAT for fork-PR scenarios. |

## Outputs

| Name | Description |
|---|---|
| `files-scanned` | Number of files the action scanned. |
| `violating-files` | Space-separated list of files with at least one critical violation. |

## What it scans

The action is a content scanner against the EU AI Act rule corpus — it's high-value on **AI prompts, agent system prompts, content templates, anything that flows into or out of an LLM**. It is not a general-purpose code linter.

## Behaviour

- Installs `trustlint` from PyPI (`pip install --upgrade trustlint`).
- Expands the `paths` globs, deduplicates the file list, runs `trustlint check` (or `trustlint scan` when `api-key` is set) per file.
- Emits a `::group::` per file for clean log folding.
- On critical violations, emits a `::error file=…::` annotation per offending file (visible inline in the PR diff) and (by default) fails the workflow.
- Exposes `files-scanned` and `violating-files` outputs for downstream steps.
- When `comment-on-pr: true` on a `pull_request` event, posts (or updates) a Markdown violation report via `gh pr comment --edit-last`.

## Test locally

```bash
# from the repo root
pip install trustlint
bash packages/trustlint-action/scripts/run-scan.sh \
  'packages/trustlint-action/test-prompts/compliant.md' \
  EU \
  true \
  high
# exit 0

bash packages/trustlint-action/scripts/run-scan.sh \
  'packages/trustlint-action/test-prompts/violating.md' \
  EU \
  true \
  high
# exit 1
```

## Roadmap (filed as separate Trello cards)

**Shipped (cards #225 / #226):**
- `trustlint check --json` + `--severity-threshold` — CLI options wired end-to-end through `run-scan.sh`.
- PR-comment formatter — `post-pr-comment.sh` + `render_pr_comment.py`; enable with `comment-on-pr: true`.

**Remaining:**
1. **Publish to `complyedge/trustlint-action@v1`** — create the public repo, add a `release.yml` that exports `packages/trustlint-action/` to the public repo and tags new versions. Human-needed for the repo creation; the publish workflow is agent-doable after. (Trello #224 / M1.5-T4)
2. **GitHub Marketplace listing** — submission flow once `complyedge/trustlint-action@v1` is live. Human-needed.

## Source layout

```
packages/trustlint-action/
├── action.yml                       — composite action definition (inputs + steps)
├── README.md                        — this file
├── scripts/
│   ├── run-scan.sh                  — glob expansion + per-file trustlint + annotations + exit aggregation
│   ├── post-pr-comment.sh           — JSONL capture + idempotent `gh pr comment` (card #226)
│   └── render_pr_comment.py         — JSONL → Markdown PR body renderer (card #226)
└── test-prompts/
    ├── compliant.md                 — fixture: should pass
    └── violating.md                 — fixture: should fail (social-scoring pattern)
```

## License

Apache 2.0 — see the repo `LICENSE`.
