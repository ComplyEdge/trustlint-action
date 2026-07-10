#!/usr/bin/env bash
#
# release.sh — mirror the publishable trustlint-action surface from this
# monorepo (packages/trustlint-action/) into a checkout of the public repo
# complyedge/trustlint-action, ready to commit + tag.
#
# Usage:  release.sh <target_dir>
#   <target_dir>  a checkout of complyedge/trustlint-action (its working tree)
#
# Publishable surface: action.yml, README.md, scripts/ (minus this release
# tooling), test-prompts/, and an Apache-2.0 LICENSE copied from the monorepo
# root. Everything else in the monorepo stays private.
#
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"          # packages/trustlint-action
REPO_ROOT="$(cd "${SRC}/../.." && pwd)"                          # monorepo root
TARGET="${1:?usage: release.sh <target_dir> (a checkout of complyedge/trustlint-action)}"

if [[ ! -d "${TARGET}" ]]; then
  echo "release.sh: target dir does not exist: ${TARGET}" >&2
  exit 2
fi

echo "release.sh: mirroring ${SRC} → ${TARGET}"

# Mirror the publishable items (replace, don't merge stale files).
for item in action.yml README.md scripts test-prompts; do
  rm -rf "${TARGET:?}/${item}"
  cp -R "${SRC}/${item}" "${TARGET}/${item}"
done

# The release tooling itself must not ship in the public action repo.
rm -f "${TARGET}/scripts/release.sh"

# Prune build/cache artifacts that must not ship.
find "${TARGET}" -type d -name '__pycache__' -prune -exec rm -rf {} + 2>/dev/null || true
find "${TARGET}" -type f -name '*.pyc' -delete 2>/dev/null || true

# Apache-2.0 LICENSE — reuse the monorepo's canonical license text.
if [[ -f "${REPO_ROOT}/LICENSE" ]]; then
  cp "${REPO_ROOT}/LICENSE" "${TARGET}/LICENSE"
else
  echo "release.sh: WARNING — ${REPO_ROOT}/LICENSE not found; add an Apache-2.0 LICENSE to the public repo manually" >&2
fi

echo "release.sh: mirrored $(find "${TARGET}" -maxdepth 2 -type f | wc -l | tr -d ' ') files into ${TARGET}"
