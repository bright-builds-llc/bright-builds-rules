#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

command -v shfmt >/dev/null 2>&1 || {
	printf 'error: shfmt is required to verify managed shell templates\n' >&2
	exit 1
}

managed_shell_templates=(
	"templates/bright-builds-auto-update.sh"
)

for template_path in "${managed_shell_templates[@]}"; do
	bash -n "$template_path"
	shfmt -d "$template_path"
done
