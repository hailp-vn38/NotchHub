#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
temporary_directory="$(mktemp -d)"
trap 'rm -rf "$temporary_directory"' EXIT

link_workspace="$temporary_directory/links"
mkdir -p "$link_workspace"
printf '%s\n' '# Target heading' > "$link_workspace/target.md"
printf '%s\n' '# README heading' '[target](target.md#target-heading)' '[self](#readme-heading)' '[external](https://example.com)' > "$link_workspace/README.md"
(cd "$link_workspace" && "$repository_root/Scripts/check-markdown-links.sh")
printf '%s\n' '[missing anchor](target.md#not-here)' > "$link_workspace/README.md"
if (cd "$link_workspace" && "$repository_root/Scripts/check-markdown-links.sh"); then
  echo 'Markdown link checker accepted a missing anchor.' >&2
  exit 1
fi
printf '%s\n' '# README heading' '[missing anchor](#not-here)' > "$link_workspace/README.md"
if (cd "$link_workspace" && "$repository_root/Scripts/check-markdown-links.sh"); then
  echo 'Markdown link checker accepted a missing same-file anchor.' >&2
  exit 1
fi

secret_workspace="$temporary_directory/secrets"
mkdir -p "$secret_workspace"
git -C "$secret_workspace" init --quiet
git -C "$secret_workspace" config user.email verification@example.invalid
git -C "$secret_workspace" config user.name Verification
printf '%s\n' 'baseline' > "$secret_workspace/README.md"
git -C "$secret_workspace" add README.md
git -C "$secret_workspace" commit --quiet -m baseline
base_commit="$(git -C "$secret_workspace" rev-parse HEAD)"
printf '%s%s\n' 'Authorization: Bearer ' 'abcdefghijklmnopqrstuvwxyz012345' > "$secret_workspace/README.md"
git -C "$secret_workspace" add README.md
git -C "$secret_workspace" commit --quiet -m secret
if (cd "$secret_workspace" && VERIFY_BASE_REF="$base_commit" "$repository_root/Scripts/check-changed-secrets.sh"); then
  echo 'Secret checker accepted a bearer token.' >&2
  exit 1
fi

boundary_workspace="$temporary_directory/boundary"
mkdir -p "$boundary_workspace/Packages/NotchDomain/Sources"
printf '%s\n' 'import SwiftUI' > "$boundary_workspace/Packages/NotchDomain/Sources/InvalidDomain.swift"
if (cd "$boundary_workspace" && PATH='/usr/bin:/bin' "$repository_root/Scripts/check-domain-boundary.sh"); then
  echo 'Domain boundary checker accepted a forbidden framework import without rg.' >&2
  exit 1
fi
