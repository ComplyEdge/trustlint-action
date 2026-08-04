# ComplyEdge TrustLint — GitHub Action

[![GitHub Marketplace](https://img.shields.io/badge/Marketplace-ComplyEdge%20TrustLint-blue?logo=github)](https://github.com/marketplace/actions/complyedge-trustlint)

CI gate that lint-scans **AI prompts and agent-instruction files** with ComplyEdge’s [TrustLint](https://pypi.org/project/trustlint/) corpus and **article citations** — not an Annex III paperwork scorer and not a production runtime gateway. Offline `trustlint check` by default; optional API-backed `trustlint scan` with a ComplyEdge API key. Fails the job on threshold violations so prohibited-practice prompts do not merge.

**Install:** `uses: complyedge/trustlint-action@v1`  
**Marketplace:** https://github.com/marketplace/actions/complyedge-trustlint  
**Product:** https://complyedge.io  
**Public repo:** https://github.com/ComplyEdge/trustlint-action  
**PyPI CLI:** https://pypi.org/project/trustlint/  
**Regulation:** [EU AI Act (2024/1689)](https://eur-lex.europa.eu/eli/reg/2024/1689)

> **Source of truth for development:** the ComplyEdge platform monorepo at `packages/trustlint-action/`. This public repo is the published export (via `scripts/release.sh` + the monorepo `trustlint-action-release` workflow).

This Action is a **CI merge gate** (prompt/content lint). It is **not** legal advice, **not** certified by GitHub, and **not** ComplyEdge’s OPA/Rego runtime API (`api.complyedge.io` runtime enforcement is a separate product surface).

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

### Pin by commit SHA (high-security consumers)

Prefer an immutable SHA after verifying the tag:

```yaml
- uses: complyedge/trustlint-action@<full-commit-sha>
```

Resolve the SHA for a tag with:

```bash
git ls-remote https://github.com/ComplyEdge/trustlint-action.git refs/tags/v1
```

## Inputs

| Name | Required | Default | Description |
|---|---|---|---|
| `paths` | no | `**/prompts/*.md **/prompts/*.txt **/*.prompt agents/*.system.md` | Space-separated bash globs of files to scan. |
| `jurisdiction` | no | `EU` | Jurisdiction filter for offline `check` (`EU` / `US` / `GLOBAL` / `universal`). |
| `api-key` | no | empty | ComplyEdge API key. Set ⇒ `trustlint scan` (API); CLI **falls back to offline check** if the API is unreachable. Empty ⇒ offline `trustlint check`. Always pass as a secret. |
| `severity-threshold` | no | `high` | Minimum severity that fails the job on the **offline `check` path**: `critical` / `high` / `medium` / `low`. Not a `scan` CLI flag — API path uses scan exit code / server policy. |
| `fail-on-violation` | no | `true` | When `true`, fail the workflow when scanned files violate (non-zero trustlint exit). |
| `comment-on-pr` | no | `false` | Post an idempotent Markdown report on the PR (`gh pr comment --edit-last`), including a Citation column. Requires `pull-requests: write`. |
| `github-token` | no | `${{ github.token }}` | Token for `comment-on-pr`. |

## Outputs

| Name | Description |
|---|---|
| `files-scanned` | Number of files scanned. |
| `violating-files` | Space-separated list of files that failed the scan step. |

## What it scans

High-value on **AI prompts, agent system prompts, content templates** — anything that flows into or out of an LLM. Not a general-purpose code linter and not an Annex III whole-product classifier.

## Behaviour

- Installs pinned `trustlint==2.0.3` from PyPI.
- Expands `paths`, runs `trustlint check` (or `scan` when `api-key` is set) per file.
- Offline `check` honors `--severity-threshold` (default `high`). Optional `scan` has no severity flag; on API failure the CLI falls back to offline check.
- Findings carry **rule citations** from the corpus when rules fire (also surfaced in optional PR comments).
- Emits `::error file=…::` annotations on violations (message includes the configured threshold) and (by default) fails the job.
- Optional PR comment when `comment-on-pr: true` (table includes a **Citation** column).

## Test fixtures (this repo)

```bash
pip install 'trustlint==2.0.3'
bash scripts/run-scan.sh 'test-prompts/compliant.md' EU true high   # exit 0
bash scripts/run-scan.sh 'test-prompts/violating.md' EU true high   # exit 1
```

## Marketplace

**Live listing:** https://github.com/marketplace/actions/complyedge-trustlint  

Branding is set in `action.yml` (`shield` / `blue`). Categories: **Security** (primary), **Code quality** (secondary). Listing framing: CI gate for AI prompts/agent instructions with TrustLint corpus and article citations — freemium offline `trustlint check` → optional API `trustlint scan`. Not legal advice; not certified by GitHub. To update the listing later: Releases UI → edit published release (org admin + Marketplace Developer Agreement + 2FA).

## Layout

```
action.yml
README.md
LICENSE                 — Apache-2.0
trustlint_action_intent.yaml
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
