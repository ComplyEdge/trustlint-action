# ComplyEdge TrustLint — GitHub Action

Composite GitHub Action that scans AI-prompt / agent-instruction files against the [EU AI Act](https://eur-lex.europa.eu/eli/reg/2024/1689) rule corpus using the [`trustlint`](https://pypi.org/project/trustlint/) CLI. Fails the workflow on threshold violations so merges do not ship prohibited-practice prompts.

**Install:** `uses: complyedge/trustlint-action@v1`  
**Public repo:** https://github.com/ComplyEdge/trustlint-action  
**PyPI CLI:** https://pypi.org/project/trustlint/

> **Source of truth for development:** the ComplyEdge platform monorepo at `packages/trustlint-action/`. This public repo is the published export (via `scripts/release.sh` + the monorepo `trustlint-action-release` workflow).

## Usage

```yaml
# .github/workflows/compliance.yml
name: ComplyEdge
on: [push, pull_request]

jobs:
  trustlint:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write   # only needed if comment-on-pr: true
    steps:
      - uses: actions/checkout@v4
      - uses: complyedge/trustlint-action@v1
        with:
          jurisdiction: EU
          paths: '**/prompts/*.md **/prompts/*.txt agents/*.system.md'
          # optional — omit for offline trustlint check
          api-key: ${{ secrets.COMPLYEDGE_API_KEY }}
          fail-on-violation: 'true'
```

## Inputs

| Name | Required | Default | Description |
|---|---|---|---|
| `paths` | no | `**/prompts/*.md **/prompts/*.txt **/*.prompt agents/*.system.md` | Space-separated bash globs of files to scan. |
| `jurisdiction` | no | `EU` | Jurisdiction filter (`EU` / `US` / `GLOBAL` / `universal`). |
| `api-key` | no | empty | ComplyEdge API key. Set ⇒ `trustlint scan` (API-backed). Empty ⇒ `trustlint check` (offline). Always pass as a secret. |
| `severity-threshold` | no | `high` | Minimum severity that fails the job: `critical` / `high` / `medium` / `low`. |
| `fail-on-violation` | no | `true` | When `true`, fail the workflow on violations at-or-above the threshold. |
| `comment-on-pr` | no | `false` | Post an idempotent Markdown report on the PR (`gh pr comment --edit-last`). Requires `pull-requests: write`. |
| `github-token` | no | `${{ github.token }}` | Token for `comment-on-pr`. |

## Outputs

| Name | Description |
|---|---|
| `files-scanned` | Number of files scanned. |
| `violating-files` | Space-separated list of files with at least one critical violation. |

## What it scans

High-value on **AI prompts, agent system prompts, content templates** — anything that flows into or out of an LLM. Not a general-purpose code linter.

## Behaviour

- Installs `trustlint` from PyPI.
- Expands `paths`, runs `trustlint check` (or `scan` when `api-key` is set) per file.
- Emits `::error file=…::` annotations on violations and (by default) fails the job.
- Optional PR comment when `comment-on-pr: true`.

## Test fixtures (this repo)

```bash
pip install trustlint
bash scripts/run-scan.sh 'test-prompts/compliant.md' EU true high   # exit 0
bash scripts/run-scan.sh 'test-prompts/violating.md' EU true high   # exit 1
```

## Marketplace

Branding is set in `action.yml` (`shield` / `blue`). Submit or update the GitHub Marketplace listing from this repo’s Releases UI (publishers with org admin).

## Layout

```
action.yml
README.md
LICENSE                 — Apache-2.0
scripts/
  run-scan.sh
  post-pr-comment.sh
  render_pr_comment.py
test-prompts/
  compliant.md
  violating.md
```

## License

Apache 2.0 — see `LICENSE`.
