#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

command -v shfmt >/dev/null 2>&1 || {
	printf 'error: shfmt is required to verify managed shell templates\n' >&2
	exit 1
}

shell_scripts_to_verify=(
	"scripts/manage-downstream.sh"
	scripts/manage-downstream/*.sh
	"scripts/test-manage-downstream.sh"
	scripts/test-manage-downstream/*.sh
	scripts/test-manage-downstream/scenarios/*.sh
	scripts/test-support/*.sh
	"scripts/test-bright-builds-auto-update.sh"
	scripts/test-bright-builds-auto-update/*.sh
	scripts/test-bright-builds-auto-update/scenarios/*.sh
	"scripts/verify-managed-shells.sh"
	"templates/bright-builds-auto-update.sh"
)

for script_path in "${shell_scripts_to_verify[@]}"; do
	bash -n "$script_path"
	shfmt -d "$script_path"
done
