#!/usr/bin/env bash
set -euo pipefail

manager_default_repo_slug="bright-builds-llc/bright-builds-rules"
manager_default_ref="main"
manager_entrypoint_path="${BASH_SOURCE[0]-}"
manager_bootstrap_tmp_dir=""
manager_module_paths=(
	"scripts/manage-downstream/core.sh"
	"scripts/manage-downstream/source-rendering.sh"
	"scripts/manage-downstream/badges.sh"
	"scripts/manage-downstream/downstream-detection.sh"
	"scripts/manage-downstream/blocks.sh"
	"scripts/manage-downstream/readme-blocks.sh"
	"scripts/manage-downstream/managed-files.sh"
	"scripts/manage-downstream/managed-state.sh"
	"scripts/manage-downstream/managed-operations.sh"
	"scripts/manage-downstream/commands.sh"
)

manager_bootstrap_cleanup() {
	if [[ -n "$manager_bootstrap_tmp_dir" && -d "$manager_bootstrap_tmp_dir" ]]; then
		rm -rf "$manager_bootstrap_tmp_dir"
	fi
}

manager_pre_scan_source() {
	local arg=""

	manager_bootstrap_repo_slug="$manager_default_repo_slug"
	manager_bootstrap_ref="$manager_default_ref"

	while [[ "$#" -gt 0 ]]; do
		arg="$1"
		case "$arg" in
		--repo)
			[[ "$#" -ge 2 ]] || break
			manager_bootstrap_repo_slug="$2"
			shift 2
			;;
		--ref)
			[[ "$#" -ge 2 ]] || break
			manager_bootstrap_ref="$2"
			shift 2
			;;
		*)
			shift
			;;
		esac
	done
}

manager_maybe_local_module_root() {
	local entrypoint_dir=""
	local module_path=""
	local module_root=""

	[[ -n "$manager_entrypoint_path" ]] || return 1
	[[ -e "$manager_entrypoint_path" ]] || return 1

	if ! entrypoint_dir="$(cd "$(dirname "$manager_entrypoint_path")" 2>/dev/null && pwd)"; then
		return 1
	fi

	module_root="${entrypoint_dir}/manage-downstream"
	for module_path in "${manager_module_paths[@]}"; do
		[[ -f "${module_root}/$(basename "$module_path")" ]] || return 1
	done

	printf '%s\n' "$module_root"
}

manager_source_local_modules() {
	local module_root="$1"
	local module_path=""

	for module_path in "${manager_module_paths[@]}"; do
		# shellcheck source=/dev/null
		source "${module_root}/$(basename "$module_path")"
	done
}

manager_source_remote_modules() {
	local raw_base=""
	local module_path=""
	local local_module_path=""

	command -v curl >/dev/null 2>&1 || {
		printf 'error: curl is required to load Bright Builds manager modules\n' >&2
		exit 1
	}

	manager_bootstrap_tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/bright-builds-rules-modules.XXXXXX")"
	raw_base="https://raw.githubusercontent.com/${manager_bootstrap_repo_slug}/${manager_bootstrap_ref}"

	for module_path in "${manager_module_paths[@]}"; do
		local_module_path="${manager_bootstrap_tmp_dir}/$(basename "$module_path")"
		rm -f "$local_module_path" "${local_module_path}.partial"
		if ! curl -fsSL \
			--retry 3 \
			--retry-delay 1 \
			--retry-max-time 15 \
			"${raw_base}/${module_path}" \
			-o "${local_module_path}.partial"; then
			rm -f "${local_module_path}.partial"
			printf 'error: unable to load Bright Builds manager module %s from %s\n' "$module_path" "$raw_base" >&2
			exit 1
		fi

		if [[ ! -s "${local_module_path}.partial" ]]; then
			printf 'error: downloaded Bright Builds manager module is empty: %s\n' "$module_path" >&2
			rm -f "${local_module_path}.partial"
			exit 1
		fi

		if ! mv "${local_module_path}.partial" "$local_module_path"; then
			rm -f "${local_module_path}.partial"
			printf 'error: unable to store Bright Builds manager module %s\n' "$module_path" >&2
			exit 1
		fi
	done

	manager_source_local_modules "$manager_bootstrap_tmp_dir"
}

manager_load_modules() {
	local maybe_module_root=""

	if maybe_module_root="$(manager_maybe_local_module_root)"; then
		manager_source_local_modules "$maybe_module_root"
		return
	fi

	manager_pre_scan_source "$@"
	manager_source_remote_modules
}

trap manager_bootstrap_cleanup EXIT
manager_load_modules "$@"
trap 'cleanup; manager_bootstrap_cleanup' EXIT
manage_downstream_main "$@"
