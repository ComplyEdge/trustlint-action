#!/usr/bin/env python3
"""Render a Markdown PR comment from a JSONL trustlint output buffer.

Each line in the input file is a JSON object as emitted by
``trustlint check --json`` (one per scanned file). This script aggregates
them into a single Markdown comment suitable for posting to a GitHub PR
via ``gh pr comment``.

Usage:
    render_pr_comment.py <jsonl_path>      # writes Markdown to stdout

The first line of the rendered body is an HTML comment marker
``<!-- complyedge-trustlint-action -->``. ``gh pr comment --edit-last``
is the primary idempotency mechanism; the marker is the secondary one
for downstream tooling that wants to detect existing comments.
"""

from __future__ import annotations

import json
import os
import sys
from typing import Any

MARKER = "<!-- complyedge-trustlint-action -->"


def _load_jsonl(path: str) -> list[dict[str, Any]]:
    files: list[dict[str, Any]] = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                files.append(json.loads(line))
            except json.JSONDecodeError:
                # Skip malformed lines silently — partial output shouldn't
                # crash the comment renderer.
                continue
    return files


def render(jsonl_path: str) -> str:
    """Render the full Markdown body for a PR comment.

    Returns a string starting with the HTML marker on its own line.
    """
    files = _load_jsonl(jsonl_path)

    totals = {"critical": 0, "high": 0, "medium": 0, "low": 0}
    violating_files: list[str] = []
    rows: list[dict[str, str]] = []

    for f in files:
        summ = f.get("summary") or {}
        for k in totals:
            totals[k] += int(summ.get(k, 0) or 0)
        violations = f.get("violations") or []
        if violations:
            fp = f.get("file") or "<text>"
            violating_files.append(fp)
            for v in violations:
                citation = (v.get("citation") or v.get("citations") or "").strip()
                if isinstance(citation, list):
                    citation = "; ".join(str(c) for c in citation if c)
                citation = " ".join(str(citation).split())
                rows.append({
                    "file": fp,
                    "rule_id": v.get("rule_id", "?"),
                    "severity": (v.get("severity") or "?").lower(),
                    "description": (v.get("description") or "").splitlines()[0][:90],
                    "citation": citation[:120],
                })

    grand_total = sum(totals.values())

    lines: list[str] = [MARKER, ""]

    if grand_total == 0:
        lines.append("## ✅ ComplyEdge TrustLint — no violations")
        lines.append("")
        lines.append(f"Scanned **{len(files)}** file(s); rule corpus is clean.")
    else:
        lines.append(
            f"## ⚠️ ComplyEdge TrustLint — {grand_total} violation(s) "
            f"across {len(set(violating_files))} file(s)"
        )
        lines.append("")
        lines.append("| Severity | Count |")
        lines.append("|---|---|")
        for sev in ("critical", "high", "medium", "low"):
            lines.append(f"| {sev.capitalize()} | {totals[sev]} |")
        lines.append("")
        lines.append("### Violations")
        lines.append("")
        lines.append("| File | Rule | Severity | Description | Citation |")
        lines.append("|---|---|---|---|---|")
        for r in rows:
            cite = r["citation"] or "—"
            lines.append(
                f"| `{r['file']}` | `{r['rule_id']}` | **{r['severity'].upper()}** | {r['description']} | {cite} |"
            )

    # Footer with a link back to the workflow run (when available)
    repo = os.environ.get("GITHUB_REPOSITORY", "")
    run_id = os.environ.get("GITHUB_RUN_ID", "")
    lines.append("")
    if repo and run_id:
        lines.append(
            f"<sub>Posted by [trustlint-action](https://github.com/{repo}/actions/runs/{run_id})"
            f" · idempotent (`gh pr comment --edit-last`).</sub>"
        )
    else:
        lines.append("<sub>Posted by trustlint-action · idempotent.</sub>")

    return "\n".join(lines) + "\n"


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: render_pr_comment.py <jsonl_path>", file=sys.stderr)
        return 2
    sys.stdout.write(render(sys.argv[1]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
