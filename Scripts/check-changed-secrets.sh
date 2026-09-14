#!/usr/bin/env bash
set -euo pipefail

base_ref="${VERIFY_BASE_REF:-}"

if [[ -z "$base_ref" ]]; then
  base_ref="$(git rev-parse HEAD^)"
fi

git rev-parse --verify --quiet "${base_ref}^{commit}" >/dev/null || {
  echo "VERIFY_BASE_REF must identify a commit reachable by this checkout." >&2
  exit 1
}

python3 - "$base_ref" <<'PY'
from pathlib import Path
import re
import subprocess
import sys

base_ref = sys.argv[1]
changed_files = subprocess.check_output(
    ["git", "diff", "--name-only", "--diff-filter=ACMR", f"{base_ref}...HEAD"], text=True
).splitlines()
patterns = (
    re.compile(r"\b(?:api[_-]?key|secret|token|password|passwd|authorization)\b\s*[:=]\s*['\"]?(?!\$\{|\{\{|example\b|placeholder\b|changeme\b|redacted\b|null\b|none\b|false\b)[A-Za-z0-9_./+=-]{16,}", re.IGNORECASE),
    re.compile(r"\bauthorization\b\s*[:=]\s*['\"]?bearer\s+(?!\$\{|\{\{|example\b|placeholder\b|changeme\b|redacted\b)[A-Za-z0-9._~+/=-]{16,}", re.IGNORECASE),
    re.compile(r"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b"),
    re.compile(r"\bgh[pousr]_[A-Za-z0-9]{36,}\b"),
)
findings = []

for filename in changed_files:
    diff = subprocess.check_output(
        ["git", "diff", "--no-ext-diff", "--unified=0", f"{base_ref}...HEAD", "--", filename], text=True
    )
    for line_number, line in enumerate(diff.splitlines(), start=1):
        if not line.startswith("+") or line.startswith("+++"):
            continue
        if any(pattern.search(line) for pattern in patterns):
            findings.append(f"{filename}: changed line near diff line {line_number} matches a secret pattern")

if findings:
    print("Changed-file secret check failed:", file=sys.stderr)
    print("\n".join(findings), file=sys.stderr)
    sys.exit(1)
PY
