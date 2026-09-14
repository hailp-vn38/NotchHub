#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path
from urllib.parse import unquote
import re
import sys

root = Path.cwd()
link_pattern = re.compile(r"(?<!!)\[[^\]]*\]\(([^)\s]+)(?:\s+['\"][^)]*['\"])?\)")
heading_pattern = re.compile(r"^\s{0,3}#{1,6}\s+(.+?)(?:\s+#+)?\s*$")
ignored_schemes = ("http://", "https://", "mailto:", "tel:", "data:")
failures = []
anchors_by_file = {}

def anchor_names(markdown_path):
    if markdown_path in anchors_by_file:
        return anchors_by_file[markdown_path]

    anchors = set()
    counts = {}
    for line in markdown_path.read_text(encoding="utf-8").splitlines():
        match = heading_pattern.match(line)
        if not match:
            continue
        slug = re.sub(r"[^\w\s-]", "", match.group(1).lower())
        slug = re.sub(r"\s", "-", slug).strip("-")
        count = counts.get(slug, 0)
        counts[slug] = count + 1
        anchors.add(slug if count == 0 else f"{slug}-{count}")

    anchors_by_file[markdown_path] = anchors
    return anchors

for markdown_path in root.rglob("*.md"):
    if any(part in {".git", ".build"} for part in markdown_path.parts):
        continue

    for line_number, line in enumerate(markdown_path.read_text(encoding="utf-8").splitlines(), start=1):
        for match in link_pattern.finditer(line):
            destination = unquote(match.group(1).strip("<>"))
            if not destination or destination.startswith(ignored_schemes):
                continue

            if destination.startswith("#"):
                candidate = markdown_path
                fragment = destination[1:]
            else:
                target, _, fragment = destination.partition("#")
                target = target.split("?", maxsplit=1)[0]
                if target.startswith("/"):
                    candidate = root / target.lstrip("/")
                else:
                    candidate = markdown_path.parent / target

            if not candidate.exists():
                failures.append(f"{markdown_path.relative_to(root)}:{line_number}: missing local link target {destination}")
            elif fragment and candidate.suffix.lower() == ".md" and fragment not in anchor_names(candidate):
                failures.append(f"{markdown_path.relative_to(root)}:{line_number}: missing local anchor {destination}")

if failures:
    print("Markdown link validation failed:", file=sys.stderr)
    print("\n".join(failures), file=sys.stderr)
    sys.exit(1)
PY
