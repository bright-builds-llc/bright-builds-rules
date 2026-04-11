#!/usr/bin/env bash
set -euo pipefail

default_repo_slug="bright-builds-llc/bright-builds-rules"
default_ref="main"
backup_root=".bright-builds-rules-backups"

agents_block_source="templates/AGENTS.md"
agents_destination="AGENTS.md"
sidecar_source="templates/AGENTS.bright-builds.md"
sidecar_destination="AGENTS.bright-builds.md"
prerename_compat_sidecar_source="templates/compat/prerename/AGENTS.bright-builds.md"
overrides_source="templates/standards-overrides.md"
overrides_destination="standards-overrides.md"
audit_source="templates/bright-builds-rules.audit.md"
audit_destination="bright-builds-rules.audit.md"
legacy_audit_destination="coding-and-architecture-requirements.audit.md"
prerename_compat_audit_source="templates/compat/prerename/coding-and-architecture-requirements.audit.md"
auto_update_script_source="templates/bright-builds-auto-update.sh"
auto_update_script_destination="scripts/bright-builds-auto-update.sh"
auto_update_workflow_source="templates/bright-builds-auto-update.yml"
auto_update_workflow_destination=".github/workflows/bright-builds-auto-update.yml"
prerename_compat_auto_update_script_source="templates/compat/prerename/bright-builds-auto-update.sh"
prerename_compat_auto_update_workflow_source="templates/compat/prerename/bright-builds-auto-update.yml"
prerename_compat_contributing_source="templates/compat/prerename/CONTRIBUTING.md"
prerename_compat_pull_request_template_source="templates/compat/prerename/pull_request_template.md"
agents_block_begin="<!-- bright-builds-rules-managed:begin -->"
agents_block_end="<!-- bright-builds-rules-managed:end -->"
legacy_agents_block_begin="<!-- coding-and-architecture-requirements-managed:begin -->"
legacy_agents_block_end="<!-- coding-and-architecture-requirements-managed:end -->"
managed_file_marker_placeholder="REPLACE_WITH_MANAGED_FILE_MARKER"
managed_file_marker_prefix="bright-builds-rules-managed-file"
legacy_managed_file_marker_prefix="coding-and-architecture-requirements-managed-file"
readme_destination="README.md"
readme_badges_begin="<!-- bright-builds-rules-readme-badges:begin -->"
readme_badges_end="<!-- bright-builds-rules-readme-badges:end -->"
legacy_readme_badges_begin="<!-- coding-and-architecture-requirements-readme-badges:begin -->"
legacy_readme_badges_end="<!-- coding-and-architecture-requirements-readme-badges:end -->"
auto_update_branch="bright-builds/auto-update"
auto_update_commit_message="chore: update Bright Builds Rules"
legacy_auto_update_commit_message="chore: update Bright Builds requirements"
auto_update_cron="0 14 * * *"
openlinks_identity_url="https://openlinks.us/"
bright_builds_rules_url="https://github.com/${default_repo_slug}"
bright_builds_rules_raw_base_url="https://raw.githubusercontent.com/${default_repo_slug}/${default_ref}"
bright_builds_badges_base_url="https://raw.githubusercontent.com/${default_repo_slug}/${default_ref}/public/badges"
legacy_bright_builds_repo_slug="bright-builds-llc/coding-and-architecture-requirements"
legacy_bright_builds_url="https://github.com/${legacy_bright_builds_repo_slug}"
legacy_bright_builds_raw_base_url="https://raw.githubusercontent.com/${legacy_bright_builds_repo_slug}/main"
trusted_auto_update_identities=(
	"prizz"
	"bright-builds-llc"
)

base_managed_pairs=(
	"${sidecar_source}|${sidecar_destination}"
	"templates/CONTRIBUTING.md|CONTRIBUTING.md"
	"templates/pull_request_template.md|.github/pull_request_template.md"
)
base_whole_file_managed_pairs=(
	"${sidecar_source}|${sidecar_destination}"
	"templates/CONTRIBUTING.md|CONTRIBUTING.md"
	"templates/pull_request_template.md|.github/pull_request_template.md"
	"${audit_source}|${audit_destination}"
)
base_managed_status_paths=(
	"${agents_destination}"
	"${sidecar_destination}"
	"CONTRIBUTING.md"
	".github/pull_request_template.md"
	"${audit_destination}"
	"${overrides_destination}"
)
base_managed_audit_entries=(
	"${agents_destination} (managed block)"
	"${sidecar_destination}"
	"CONTRIBUTING.md"
	".github/pull_request_template.md"
	"${audit_destination}"
)

tmp_dir=""
script_dir=""
local_source_root=""
current_source=""
current_ref=""
current_entrypoint=""
current_exact_commit=""
current_auto_update=""
current_auto_update_reason=""
current_last_operation=""
current_last_updated_utc=""
current_audit_destination=""
current_install_uses_legacy_layout=0
repo_state=""
recommended_action=""
repo_slug=""
repo_url=""
ref=""
exact_commit=""
exact_commit_unavailable="Unavailable"
repo_root="$(pwd)"
standards_index_url=""
raw_base=""
last_operation=""
last_updated_utc=""
last_backup_relative_root=""
force=0
repo_was_explicit=0
ref_was_explicit=0
auto_update_was_explicit=0
agents_block_state="absent"
agents_block_family="absent"
readme_badge_state="absent"
readme_badges_family="absent"
readme_badge_blocking_reason=""
readme_badges_markdown=""
readme_has_managed_badges=0
auto_update_request="auto"
auto_update_mode=""
auto_update_reason=""
downstream_repo_slug=""
downstream_repo_url=""
downstream_repo_owner=""
downstream_ci_workflow_path=""
downstream_deploy_workflow_path=""
downstream_license_file=""
current_github_user=""
owner_specific_guidance_markdown=""
blocking_paths=()

cleanup() {
	if [[ -n "$tmp_dir" && -d "$tmp_dir" ]]; then
		rm -rf "$tmp_dir"
	fi
}

resolve_local_source_root() {
	local maybe_script_path="${BASH_SOURCE[0]-}"
	local maybe_script_dir=""
	local maybe_source_root=""

	[[ -n "$maybe_script_path" ]] || return 0
	[[ -e "$maybe_script_path" ]] || return 0

	if ! maybe_script_dir="$(cd "$(dirname "$maybe_script_path")" 2>/dev/null && pwd)"; then
		return 0
	fi

	if [[ ! -f "${maybe_script_dir}/../templates/AGENTS.md" ]]; then
		return 0
	fi

	if ! maybe_source_root="$(cd "${maybe_script_dir}/.." 2>/dev/null && pwd)"; then
		return 0
	fi

	script_dir="$maybe_script_dir"
	local_source_root="$maybe_source_root"
}

usage() {
	cat <<'EOF'
Usage: manage-downstream.sh <install|update|status|uninstall> [options]

Run `status` first to classify the repo as `installable`, `installed`, or
`blocked` before choosing an action.

Commands:
  install     Install the managed AGENTS block, AGENTS.bright-builds.md,
              CONTRIBUTING.md, PR template, audit trail, and default README
              badge block when managed README badges apply, plus the managed
              auto-update workflow and helper script when auto-update resolves
              to enabled. A pre-existing unmarked AGENTS.md is preserved and
              receives the managed block at the end. Blocked repos stop unless
              --force is passed.
  update      Refresh the managed AGENTS block, AGENTS.bright-builds.md, the
              managed files, README badge block, audit trail, and managed
              auto-update files for repos already using the marker-based
              layout.
  status      Show which managed files are present, classify the repo state,
              print the recommended next action, and report README badge state
              plus the resolved auto-update mode and reason.
  uninstall   Remove the managed AGENTS block, AGENTS.bright-builds.md,
              CONTRIBUTING.md, the PR template, audit trail, managed README
              badges, and managed auto-update files. Keeps
              standards-overrides.md.

Options:
  --ref <git-ref>          Source ref to pin in downstream files. Defaults to
                           the current detected audit pin for update, otherwise
                           main.
  --repo <owner/repo>      Source GitHub repository. Defaults to the current
                           audit source for update, otherwise
                           bright-builds-llc/bright-builds-rules.
  --repo-root <path>       Target downstream repository root. Defaults to the
                           current directory.
  --auto-update <mode>     Auto-update mode for install/update. Use
                           auto|enabled|disabled. Defaults to auto for fresh
                           installs and reuses the persisted audit setting on
                           later updates unless explicitly overridden.
  --force                  Back up and replace blocked managed files during
                           install. The backup is written to
                           .bright-builds-rules-backups/<UTC-timestamp>.
  -h, --help               Show this help text.
EOF
}

die() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

note() {
	printf '%s\n' "$*"
}

require_command() {
	command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

utc_now() {
	date -u +"%Y-%m-%dT%H:%M:%SZ"
}

ensure_tmp_dir() {
	if [[ -z "$tmp_dir" || ! -d "$tmp_dir" ]]; then
		tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/bright-builds-rules.XXXXXX")"
	fi
}

build_managed_files_markdown() {
	local output=""
	local path=""

	if [[ "$#" -eq 0 ]]; then
		printf '%s' "- No managed files are currently tracked."
		return
	fi

	for path in "$@"; do
		if [[ -n "$output" ]]; then
			output="${output}
"
		fi

		output="${output}- \`${path}\`"
	done

	printf '%s' "$output"
}

build_managed_file_marker_line() {
	local relative_destination="$1"
	local marker_prefix="${managed_file_marker_prefix}"

	case "$relative_destination" in
	*.md)
		printf '<!-- %s: %s -->' "$marker_prefix" "$relative_destination"
		;;
	*.sh | *.yml | *.yaml)
		printf '# %s: %s' "$marker_prefix" "$relative_destination"
		;;
	*)
		printf '# %s: %s' "$marker_prefix" "$relative_destination"
		;;
	esac
}

is_full_commit_sha() {
	[[ "${1:-}" =~ ^[0-9a-fA-F]{40}$ ]]
}

normalize_commit_sha() {
	printf '%s\n' "$1" | tr '[:upper:]' '[:lower:]'
}

extract_markdown_value() {
	local file_path="$1"
	local label="$2"

	awk -v label="$label" '
    BEGIN {
      prefix = "- " label ": `"
    }

    index($0, prefix) == 1 {
      value = substr($0, length(prefix) + 1)
      sub(/`$/, "", value)
      print value
      exit
    }
  ' "$file_path"
}

extract_repo_slug_from_url() {
	local input_url="$1"

	printf '%s' "$input_url" | sed -n 's#^https://github.com/\(.*\)$#\1#p' | sed 's#/$##'
}

extract_repo_owner_from_slug() {
	local repo_slug_value="$1"

	printf '%s\n' "$repo_slug_value" | cut -d/ -f1
}

normalize_github_identity() {
	printf '%s\n' "${1:-}" | tr '[:upper:]' '[:lower:]'
}

normalize_personal_owner_identity() {
	printf '%s\n' "${1:-}" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]'
}

is_legacy_source_repository_url() {
	[[ "${1:-}" == "$legacy_bright_builds_url" ]]
}

resolve_effective_audit_destination() {
	if [[ -n "$current_audit_destination" ]]; then
		printf '%s\n' "$current_audit_destination"
		return
	fi

	printf '%s\n' "$audit_destination"
}

is_trusted_auto_update_identity() {
	local candidate="${1:-}"
	local normalized_candidate=""
	local trusted_identity=""

	normalized_candidate="$(normalize_github_identity "$candidate")"
	[[ -n "$normalized_candidate" ]] || return 1

	for trusted_identity in "${trusted_auto_update_identities[@]}"; do
		if [[ "$normalized_candidate" == "$trusted_identity" ]]; then
			return 0
		fi
	done

	return 1
}

is_openlinks_identity_owner() {
	local candidate="${1:-}"
	local normalized_candidate=""
	local supported_identity=""
	local supported_identities=(
		"prizz"
		"peterryszkiewicz"
	)

	normalized_candidate="$(normalize_personal_owner_identity "$candidate")"
	[[ -n "$normalized_candidate" ]] || return 1

	for supported_identity in "${supported_identities[@]}"; do
		if [[ "$normalized_candidate" == "$supported_identity" ]]; then
			return 0
		fi
	done

	return 1
}

build_owner_specific_guidance_markdown() {
	local maybe_owner="${1:-$downstream_repo_owner}"

	if ! is_openlinks_identity_owner "$maybe_owner"; then
		return 0
	fi

	cat <<EOF
## Owner-specific skill default

- Because the downstream GitHub repo owner resolves to \`${maybe_owner}\`, use the \`openlinks-identity-presence\` skill whenever the task touches README/docs, website or app chrome, profile/about/footer/settings surfaces, or metadata and discovery fields.
- Follow the skill's low-intrusion placement bias: prefer footer, about, profile, or README "Find me" placement, keep the visible link primary, and add metadata hints only when the surface already supports them cleanly.
- If the installer already manages an OpenLinks README badge for this repo, do not add a second near-duplicate README placement unless the user explicitly asks for more prominence.
- Keep the host project's main brand and CTA primary. Do not add repetitive or aggressive OpenLinks promotion unless the user explicitly asks for it.
EOF
}

extract_sidecar_owner_specific_guidance_owner() {
	local file_path="$1"

	sed -n 's/^- Because the downstream GitHub repo owner resolves to `\([^`]*\)`,.*$/\1/p' "$file_path" | head -n 1
}

download_file() {
	local source_path="$1"
	local output_path="$2"
	local maybe_local_source_path=""

	maybe_local_source_path="${local_source_root}/${source_path}"

	if [[ -n "$local_source_root" && -f "$maybe_local_source_path" ]]; then
		cp "$maybe_local_source_path" "$output_path"
		return
	fi

	require_command curl
	curl -fsSL "${raw_base}/${source_path}" -o "$output_path"
}

download_file_if_available_from_raw_base() {
	local candidate_raw_base="$1"
	local source_path="$2"
	local output_path="$3"

	[[ -n "$candidate_raw_base" ]] || return 1

	require_command curl
	rm -f "$output_path"
	if curl -fsSL "${candidate_raw_base}/${source_path}" -o "$output_path" >/dev/null 2>&1; then
		return 0
	fi

	rm -f "$output_path"
	return 1
}

download_file_for_install_state_candidate() {
	local source_path="$1"
	local output_path="$2"
	local candidate_repo_slug="$3"
	local candidate_ref="$4"
	local candidate_raw_base=""

	[[ -n "$candidate_repo_slug" ]] || return 1
	[[ -n "$candidate_ref" ]] || return 1
	[[ "$candidate_ref" != "$exact_commit_unavailable" ]] || return 1

	candidate_raw_base="https://raw.githubusercontent.com/${candidate_repo_slug}/${candidate_ref}"
	download_file_if_available_from_raw_base "$candidate_raw_base" "$source_path" "$output_path"
}

download_file_for_install_state_rendering() {
	local source_path="$1"
	local output_path="$2"
	local compare_repo_url="$3"
	local compare_requested_ref="$4"
	local compare_exact_commit="$5"
	local manager_repo_slug="$6"
	local manager_requested_ref="$7"
	local manager_exact_commit="$8"
	local maybe_local_source_path=""
	local compare_repo_slug=""

	maybe_local_source_path="${local_source_root}/${source_path}"
	if [[ -n "$local_source_root" && -f "$maybe_local_source_path" ]]; then
		cp "$maybe_local_source_path" "$output_path"
		return 0
	fi

	compare_repo_slug="$(extract_repo_slug_from_url "$compare_repo_url")"
	if download_file_for_install_state_candidate "$source_path" "$output_path" "$compare_repo_slug" "$compare_exact_commit"; then
		return 0
	fi

	if download_file_for_install_state_candidate "$source_path" "$output_path" "$compare_repo_slug" "$compare_requested_ref"; then
		return 0
	fi

	if [[ -z "$compare_repo_slug" ]] || is_legacy_source_repository_url "$compare_repo_url"; then
		if download_file_for_install_state_candidate "$source_path" "$output_path" "$manager_repo_slug" "$manager_exact_commit"; then
			return 0
		fi

		if download_file_for_install_state_candidate "$source_path" "$output_path" "$manager_repo_slug" "$manager_requested_ref"; then
			return 0
		fi
	fi

	rm -f "$output_path"
	return 1
}

render_template_file() {
	local source_path="$1"
	local output_path="$2"
	local managed_files_markdown="${3:-}"
	local relative_destination="${4:-}"
	local include_managed_file_marker="${5:-enabled}"
	local owner_specific_guidance_override="${6-__CURRENT__}"
	local managed_file_marker_line=""
	local owner_specific_guidance_content=""
	local line=""

	if [[ "$include_managed_file_marker" == "enabled" && -n "$relative_destination" ]]; then
		managed_file_marker_line="$(build_managed_file_marker_line "$relative_destination")"
	fi

	if [[ "$owner_specific_guidance_override" == "__CURRENT__" ]]; then
		owner_specific_guidance_content="$owner_specific_guidance_markdown"
	else
		owner_specific_guidance_content="$owner_specific_guidance_override"
	fi

	{
		while IFS= read -r line || [[ -n "$line" ]]; do
			if [[ "$line" == "$managed_file_marker_placeholder" ]]; then
				if [[ -n "$managed_file_marker_line" ]]; then
					printf '%s\n' "$managed_file_marker_line"
				fi
				continue
			fi

			if [[ "$line" == "REPLACE_WITH_MANAGED_FILES_LIST" ]]; then
				printf '%s\n' "$managed_files_markdown"
				continue
			fi

			if [[ "$line" == "REPLACE_WITH_OWNER_SPECIFIC_GUIDANCE" ]]; then
				if [[ -n "$owner_specific_guidance_content" ]]; then
					printf '%s\n' "$owner_specific_guidance_content"
				fi
				continue
			fi

			line="${line//REPLACE_WITH_REPO_URL/$repo_url}"
			line="${line//REPLACE_WITH_TAG_OR_COMMIT/$ref}"
			line="${line//REPLACE_WITH_EXACT_COMMIT/$exact_commit}"
			line="${line//REPLACE_WITH_TAGGED_STANDARDS_INDEX_URL/$standards_index_url}"
			line="${line//REPLACE_WITH_AUDIT_MANIFEST_PATH/$audit_destination}"
			line="${line//REPLACE_WITH_LAST_OPERATION/$last_operation}"
			line="${line//REPLACE_WITH_LAST_UPDATED_UTC/$last_updated_utc}"
			line="${line//REPLACE_WITH_MANAGED_SIDECAR_PATH/$sidecar_destination}"
			line="${line//REPLACE_WITH_AUTO_UPDATE_MODE/$auto_update_mode}"
			line="${line//REPLACE_WITH_AUTO_UPDATE_REASON/$auto_update_reason}"
			line="${line//REPLACE_WITH_AUTO_UPDATE_SCRIPT_PATH/$auto_update_script_destination}"
			line="${line//REPLACE_WITH_AUTO_UPDATE_BRANCH/$auto_update_branch}"
			line="${line//REPLACE_WITH_AUTO_UPDATE_COMMIT_MESSAGE/$auto_update_commit_message}"
			line="${line//REPLACE_WITH_AUTO_UPDATE_CRON/$auto_update_cron}"
			printf '%s\n' "$line"
		done <"$source_path"
	} >"$output_path"
}

resolve_exact_commit() {
	local resolved_commit=""
	local remote_url=""
	local ls_remote_output=""

	if is_full_commit_sha "$ref"; then
		exact_commit="$(normalize_commit_sha "$ref")"
		return
	fi

	if command -v git >/dev/null 2>&1 && [[ -n "$local_source_root" ]]; then
		if resolved_commit="$(git -C "$local_source_root" rev-parse HEAD 2>/dev/null)" && is_full_commit_sha "$resolved_commit"; then
			exact_commit="$(normalize_commit_sha "$resolved_commit")"
			return
		fi
	fi

	if ! command -v git >/dev/null 2>&1; then
		exact_commit="$exact_commit_unavailable"
		return
	fi

	remote_url="https://github.com/${repo_slug}.git"

	if ! ls_remote_output="$(git ls-remote "$remote_url" "$ref" "$ref^{}" 2>/dev/null)" || [[ -z "$ls_remote_output" ]]; then
		exact_commit="$exact_commit_unavailable"
		return
	fi

	resolved_commit="$(printf '%s\n' "$ls_remote_output" | awk '
    $2 ~ /\^\{\}$/ {
      print $1
      found = 1
      exit
    }

    NR == 1 && first == "" {
      first = $1
    }

    END {
      if (found != 1 && first != "") {
        print first
      }
    }
  ')"

	if is_full_commit_sha "$resolved_commit"; then
		exact_commit="$(normalize_commit_sha "$resolved_commit")"
		return
	fi

	exact_commit="$exact_commit_unavailable"
}

render_template_to_tmp_path() {
	local source_path="$1"
	local tmp_stem="$2"
	local managed_files_markdown="${3:-}"
	local relative_destination="${4:-}"
	local downloaded_path=""
	local rendered_path=""

	ensure_tmp_dir
	downloaded_path="${tmp_dir}/${tmp_stem}.source"
	rendered_path="${tmp_dir}/${tmp_stem}.rendered"
	download_file "$source_path" "$downloaded_path"
	render_template_file "$downloaded_path" "$rendered_path" "$managed_files_markdown" "$relative_destination" "enabled"
	printf '%s\n' "$rendered_path"
}

render_template_to_tmp_path_for_install_state() {
	local source_path="$1"
	local tmp_stem="$2"
	local relative_destination="$3"
	local managed_files_markdown="${4:-}"
	local include_managed_file_marker="${5:-enabled}"
	local compare_downstream_owner="${6-__CURRENT__}"
	local compare_repo_url="${current_source:-$repo_url}"
	local compare_requested_ref="${current_ref:-$ref}"
	local compare_exact_commit="${current_exact_commit:-$exact_commit}"
	local compare_entrypoint="${current_entrypoint:-}"
	local compare_auto_update_mode="${current_auto_update:-$auto_update_mode}"
	local compare_auto_update_reason="${current_auto_update_reason:-$auto_update_reason}"
	local compare_owner_specific_guidance_markdown=""
	local compare_last_operation="${current_last_operation:-}"
	local compare_last_updated_utc="${current_last_updated_utc:-}"
	local manager_repo_slug="$repo_slug"
	local manager_requested_ref="$ref"
	local manager_exact_commit="$exact_commit"
	local repo_url=""
	local ref=""
	local exact_commit=""
	local standards_index_url=""
	local auto_update_mode=""
	local auto_update_reason=""
	local last_operation=""
	local last_updated_utc=""
	local downloaded_path=""
	local rendered_path=""

	if [[ -z "$compare_entrypoint" ]]; then
		compare_entrypoint="${compare_repo_url}/blob/${compare_requested_ref}/standards/index.md"
	fi

	repo_url="$compare_repo_url"
	ref="$compare_requested_ref"
	exact_commit="$compare_exact_commit"
	standards_index_url="$compare_entrypoint"
	auto_update_mode="$compare_auto_update_mode"
	auto_update_reason="$compare_auto_update_reason"
	last_operation="$compare_last_operation"
	last_updated_utc="$compare_last_updated_utc"

	if [[ "$compare_downstream_owner" == "__CURRENT__" ]]; then
		compare_owner_specific_guidance_markdown="$owner_specific_guidance_markdown"
	else
		compare_owner_specific_guidance_markdown="$(build_owner_specific_guidance_markdown "$compare_downstream_owner")"
	fi

	ensure_tmp_dir
	downloaded_path="${tmp_dir}/${tmp_stem}.source"
	rendered_path="${tmp_dir}/${tmp_stem}.rendered"
	if ! download_file_for_install_state_rendering "$source_path" "$downloaded_path" "$compare_repo_url" "$compare_requested_ref" "$compare_exact_commit" "$manager_repo_slug" "$manager_requested_ref" "$manager_exact_commit"; then
		printf '\n'
		return 0
	fi

	render_template_file "$downloaded_path" "$rendered_path" "$managed_files_markdown" "$relative_destination" "$include_managed_file_marker" "$compare_owner_specific_guidance_markdown"
	printf '%s\n' "$rendered_path"
}

rewrite_rendered_file_for_legacy_identity() {
	local input_path="$1"
	local output_path="$2"
	local relative_destination="$3"
	local line=""
	local skip_legacy_helper_fallback_block=0
	local previous_auto_update_line_blank=0

	{
		while IFS= read -r line || [[ -n "$line" ]]; do
			if [[ "$relative_destination" == "$auto_update_script_destination" && "$skip_legacy_helper_fallback_block" -eq 1 ]]; then
				if [[ "$line" == "fi" ]]; then
					skip_legacy_helper_fallback_block=0
				fi
				continue
			fi

			line="${line//bright-builds-rules-managed-file: /coding-and-architecture-requirements-managed-file: }"
			line="${line//${agents_block_begin}/${legacy_agents_block_begin}}"
			line="${line//${agents_block_end}/${legacy_agents_block_end}}"
			line="${line//${readme_badges_begin}/${legacy_readme_badges_begin}}"
			line="${line//${readme_badges_end}/${legacy_readme_badges_end}}"
			line="${line//Bright Builds Rules default workflow/Bright Builds default workflow}"
			line="${line//Bright Builds Rules defaults/Bright Builds defaults}"
			line="${line//Bright Builds Rules standards page/Bright Builds standards page}"
			line="${line//Bright Builds Rules guidance/Bright Builds guidance}"
			line="${line//Bright Builds Rules specification./Bright Builds specification.}"
			line="${line//Bright Builds Rules spec./Bright Builds spec.}"
			line="${line//Bright Builds Rules block/Bright Builds block}"

			case "$relative_destination" in
			"${agents_destination}")
				line="${line//# Bright Builds Rules/# Bright Builds Standards}"
				;;
			"${audit_destination}" | "${legacy_audit_destination}")
				line="${line//# Bright Builds Rules Audit Trail/# Coding and Architecture Requirements Audit Trail}"
				line="${line//This file records that this repository is using the Bright Builds Rules and shows where the managed adoption files came from./This file records that this repository is using the Bright Builds coding and architecture requirements and shows where the managed adoption files came from.}"
				;;
			"${auto_update_script_destination}")
				if [[ "$line" == 'legacy_audit_path="coding-and-architecture-requirements.audit.md"' ]]; then
					continue
				fi
				if [[ "$line" == *'bright-builds-rules.audit.md \' ]]; then
					line="${line//bright-builds-rules.audit.md/coding-and-architecture-requirements.audit.md}"
				elif [[ "$line" == *'coding-and-architecture-requirements.audit.md \' ]]; then
					continue
				fi
				if [[ "$line" == 'if [[ ! -f "$audit_path" && -f "$legacy_audit_path" ]]; then' ]]; then
					skip_legacy_helper_fallback_block=1
					continue
				fi
				line="${line//Automated Bright Builds Rules update./Automated Bright Builds requirements update.}"
				;;
			esac

			if [[ "$relative_destination" == "$auto_update_script_destination" ]]; then
				if [[ "$line" =~ ^[[:space:]]*$ ]]; then
					if [[ "$previous_auto_update_line_blank" -eq 1 ]]; then
						continue
					fi
					previous_auto_update_line_blank=1
				else
					previous_auto_update_line_blank=0
				fi
			fi

			printf '%s\n' "$line"
		done <"$input_path"
	} >"$output_path"
}

render_template_to_legacy_identity_tmp_path_for_install_state() {
	local source_path="$1"
	local tmp_stem="$2"
	local relative_destination="$3"
	local managed_files_markdown="${4:-}"
	local include_managed_file_marker="${5:-enabled}"
	local compare_downstream_owner="${6-__CURRENT__}"
	local compare_repo_url="${current_source:-$legacy_bright_builds_url}"
	local compare_requested_ref="${current_ref:-$ref}"
	local compare_exact_commit="${current_exact_commit:-$exact_commit}"
	local compare_entrypoint="${current_entrypoint:-}"
	local compare_auto_update_mode="${current_auto_update:-$auto_update_mode}"
	local compare_auto_update_reason="${current_auto_update_reason:-$auto_update_reason}"
	local compare_last_operation="${current_last_operation:-}"
	local compare_last_updated_utc="${current_last_updated_utc:-}"
	local compare_owner_specific_guidance_markdown=""
	local manager_repo_slug="$repo_slug"
	local manager_requested_ref="$ref"
	local manager_exact_commit="$exact_commit"
	local repo_url=""
	local ref=""
	local exact_commit=""
	local standards_index_url=""
	local auto_update_mode=""
	local auto_update_reason=""
	local last_operation=""
	local last_updated_utc=""
	local audit_destination="$legacy_audit_destination"
	local managed_file_marker_prefix="$legacy_managed_file_marker_prefix"
	local auto_update_commit_message="$legacy_auto_update_commit_message"
	local downloaded_path=""
	local rendered_path=""
	local compat_rendered_path=""

	if [[ -z "$compare_entrypoint" ]]; then
		compare_entrypoint="${compare_repo_url}/blob/${compare_requested_ref}/standards/index.md"
	fi

	repo_url="$compare_repo_url"
	ref="$compare_requested_ref"
	exact_commit="$compare_exact_commit"
	standards_index_url="$compare_entrypoint"
	auto_update_mode="$compare_auto_update_mode"
	auto_update_reason="$compare_auto_update_reason"
	last_operation="$compare_last_operation"
	last_updated_utc="$compare_last_updated_utc"

	if [[ "$compare_downstream_owner" == "__CURRENT__" ]]; then
		compare_owner_specific_guidance_markdown="$owner_specific_guidance_markdown"
	else
		compare_owner_specific_guidance_markdown="$(build_owner_specific_guidance_markdown "$compare_downstream_owner")"
	fi

	ensure_tmp_dir
	downloaded_path="${tmp_dir}/${tmp_stem}.legacy.source"
	rendered_path="${tmp_dir}/${tmp_stem}.legacy.rendered"
	compat_rendered_path="${tmp_dir}/${tmp_stem}.legacy.compat.rendered"
	if ! download_file_for_install_state_rendering "$source_path" "$downloaded_path" "" "" "" "$manager_repo_slug" "$manager_requested_ref" "$manager_exact_commit"; then
		printf '\n'
		return 0
	fi

	render_template_file "$downloaded_path" "$rendered_path" "$managed_files_markdown" "$relative_destination" "$include_managed_file_marker" "$compare_owner_specific_guidance_markdown"
	rewrite_rendered_file_for_legacy_identity "$rendered_path" "$compat_rendered_path" "$relative_destination"
	printf '%s\n' "$compat_rendered_path"
}

prerename_compat_source_path_for_relative_destination() {
	local relative_destination="$1"

	case "$relative_destination" in
	"${sidecar_destination}")
		printf '%s\n' "$prerename_compat_sidecar_source"
		;;
	"CONTRIBUTING.md")
		printf '%s\n' "$prerename_compat_contributing_source"
		;;
	".github/pull_request_template.md")
		printf '%s\n' "$prerename_compat_pull_request_template_source"
		;;
	"${audit_destination}" | "${legacy_audit_destination}")
		printf '%s\n' "$prerename_compat_audit_source"
		;;
	"${auto_update_script_destination}")
		printf '%s\n' "$prerename_compat_auto_update_script_source"
		;;
	"${auto_update_workflow_destination}")
		printf '%s\n' "$prerename_compat_auto_update_workflow_source"
		;;
	esac
}

render_template_to_prerename_compat_tmp_path_for_install_state() {
	local tmp_stem="$1"
	local relative_destination="$2"
	local managed_files_markdown="${3:-}"
	local include_managed_file_marker="${4:-enabled}"
	local compare_downstream_owner="${5-__CURRENT__}"
	local compare_repo_url="${current_source:-$legacy_bright_builds_url}"
	local compare_requested_ref="${current_ref:-$ref}"
	local compare_exact_commit="${current_exact_commit:-$exact_commit}"
	local compare_entrypoint="${current_entrypoint:-}"
	local compare_auto_update_mode="${current_auto_update:-$auto_update_mode}"
	local compare_auto_update_reason="${current_auto_update_reason:-$auto_update_reason}"
	local compare_last_operation="${current_last_operation:-}"
	local compare_last_updated_utc="${current_last_updated_utc:-}"
	local compare_owner_specific_guidance_markdown=""
	local manager_repo_slug="$repo_slug"
	local manager_requested_ref="$ref"
	local manager_exact_commit="$exact_commit"
	local compat_source_path=""
	local repo_url=""
	local ref=""
	local exact_commit=""
	local standards_index_url=""
	local auto_update_mode=""
	local auto_update_reason=""
	local last_operation=""
	local last_updated_utc=""
	local audit_destination="$legacy_audit_destination"
	local managed_file_marker_prefix="$legacy_managed_file_marker_prefix"
	local auto_update_commit_message="$legacy_auto_update_commit_message"
	local downloaded_path=""
	local rendered_path=""

	compat_source_path="$(prerename_compat_source_path_for_relative_destination "$relative_destination")"
	if [[ -z "$compat_source_path" ]]; then
		printf '\n'
		return 0
	fi

	if [[ -z "$compare_entrypoint" ]]; then
		compare_entrypoint="${compare_repo_url}/blob/${compare_requested_ref}/standards/index.md"
	fi

	repo_url="$compare_repo_url"
	ref="$compare_requested_ref"
	exact_commit="$compare_exact_commit"
	standards_index_url="$compare_entrypoint"
	auto_update_mode="$compare_auto_update_mode"
	auto_update_reason="$compare_auto_update_reason"
	last_operation="$compare_last_operation"
	last_updated_utc="$compare_last_updated_utc"

	if [[ "$compare_downstream_owner" == "__CURRENT__" ]]; then
		compare_owner_specific_guidance_markdown="$owner_specific_guidance_markdown"
	else
		compare_owner_specific_guidance_markdown="$(build_owner_specific_guidance_markdown "$compare_downstream_owner")"
	fi

	ensure_tmp_dir
	downloaded_path="${tmp_dir}/${tmp_stem}.prerename-compat.source"
	rendered_path="${tmp_dir}/${tmp_stem}.prerename-compat.rendered"
	if ! download_file_for_install_state_rendering "$compat_source_path" "$downloaded_path" "" "" "" "$manager_repo_slug" "$manager_requested_ref" "$manager_exact_commit"; then
		printf '\n'
		return 0
	fi

	render_template_file "$downloaded_path" "$rendered_path" "$managed_files_markdown" "$relative_destination" "$include_managed_file_marker" "$compare_owner_specific_guidance_markdown"
	printf '%s\n' "$rendered_path"
}

write_rendered_file() {
	local source_path="$1"
	local relative_destination="$2"
	local managed_files_markdown="${3:-}"
	local destination_path="${repo_root}/${relative_destination}"
	local rendered_path=""
	local updated_path=""

	rendered_path="$(render_template_to_tmp_path "$source_path" "$(basename "$relative_destination")" "$managed_files_markdown" "$relative_destination")"
	mkdir -p "$(dirname "$destination_path")"
	ensure_tmp_dir
	updated_path="${tmp_dir}/$(basename "$relative_destination").write"
	cp "$rendered_path" "$updated_path"
	mv "$updated_path" "$destination_path"
	note "Wrote ${relative_destination}"
}

file_has_non_whitespace() {
	local file_path="$1"
	[[ -f "$file_path" ]] && grep -q '[^[:space:]]' "$file_path"
}

trim_trailing_blank_lines() {
	local input_path="$1"
	local output_path="$2"

	awk '
    {
      lines[NR] = $0
    }
    END {
      last = NR
      while (last > 0 && lines[last] ~ /^[[:space:]]*$/) {
        last--
      }

      for (i = 1; i <= last; i++) {
        print lines[i]
      }
    }
  ' "$input_path" >"$output_path"
}

trim_value() {
	printf '%s' "${1:-}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

urlencode_component() {
	local input="${1:-}"
	local output=""
	local index=""
	local character=""
	local hex=""
	local ascii_code=""

	LC_ALL=C

	for ((index = 0; index < ${#input}; index++)); do
		character="${input:index:1}"

		case "$character" in
		[a-zA-Z0-9._~-])
			output="${output}${character}"
			;;
		' ')
			output="${output}%20"
			;;
		*)
			printf -v ascii_code '%d' "'$character"
			printf -v hex '%%%02X' "$ascii_code"
			output="${output}${hex}"
			;;
		esac
	done

	printf '%s\n' "$output"
}

build_static_badge_markdown() {
	local label="$1"
	local version="$2"
	local color="$3"
	local logo="${4:-}"
	local logo_color="${5:-}"
	local link_target="$6"
	local encoded_label=""
	local encoded_version=""
	local image_url=""

	encoded_label="$(urlencode_component "$label")"
	encoded_version="$(urlencode_component "$version")"
	image_url="https://img.shields.io/badge/${encoded_label}-${encoded_version}-${color}"

	if [[ -n "$logo" ]]; then
		image_url="${image_url}?logo=$(urlencode_component "$logo")"
		if [[ -n "$logo_color" ]]; then
			image_url="${image_url}&logoColor=$(urlencode_component "$logo_color")"
		fi
	fi

	printf '[![%s %s](%s)](%s)\n' "$label" "$version" "$image_url" "$link_target"
}

build_current_manual_bright_builds_badge_markdown() {
	local variant="$1"

	case "$variant" in
	canonical)
		printf '[![Bright Builds Rules](%s/public/badges/bright-builds-rules.svg)](%s)\n' "$bright_builds_rules_raw_base_url" "$bright_builds_rules_url"
		;;
	flat)
		printf '[![Bright Builds: Rules](%s/public/badges/bright-builds-rules-flat.svg)](%s)\n' "$bright_builds_rules_raw_base_url" "$bright_builds_rules_url"
		;;
	dark)
		printf '[![Bright Builds Rules](%s/assets/badges/bright-builds-rules-dark.svg)](%s)\n' "$bright_builds_rules_raw_base_url" "$bright_builds_rules_url"
		;;
	light)
		printf '[![Bright Builds Rules](%s/assets/badges/bright-builds-rules-light.svg)](%s)\n' "$bright_builds_rules_raw_base_url" "$bright_builds_rules_url"
		;;
	compact)
		printf '[![Bright Builds Rules](%s/assets/badges/bright-builds-rules-compact.svg)](%s)\n' "$bright_builds_rules_raw_base_url" "$bright_builds_rules_url"
		;;
	*)
		return 1
		;;
	esac
}

normalize_known_legacy_bright_builds_badge_line() {
	local line="$1"
	local old_canonical_raw=""
	local old_canonical_relative=""
	local old_flat_raw=""
	local old_flat_relative=""
	local old_dark_raw=""
	local old_dark_relative=""
	local old_light_raw=""
	local old_light_relative=""
	local old_compact_raw=""
	local old_compact_relative=""

	old_canonical_raw="[![Bright Builds Requirements](${legacy_bright_builds_raw_base_url}/public/badges/bright-builds.svg)](${legacy_bright_builds_url})"
	old_canonical_relative="[![Bright Builds Requirements](public/badges/bright-builds.svg)](${legacy_bright_builds_url})"
	old_flat_raw="[![Bright Builds: Coding requirements](${legacy_bright_builds_raw_base_url}/public/badges/bright-builds-flat.svg)](${legacy_bright_builds_url})"
	old_flat_relative="[![Bright Builds: Coding requirements](public/badges/bright-builds-flat.svg)](${legacy_bright_builds_url})"
	old_dark_raw="[![Bright Builds Requirements](${legacy_bright_builds_raw_base_url}/assets/badges/bright-builds-requirements-dark.svg)](${legacy_bright_builds_url})"
	old_dark_relative="[![Bright Builds Requirements](assets/badges/bright-builds-requirements-dark.svg)](${legacy_bright_builds_url})"
	old_light_raw="[![Bright Builds Requirements](${legacy_bright_builds_raw_base_url}/assets/badges/bright-builds-requirements-light.svg)](${legacy_bright_builds_url})"
	old_light_relative="[![Bright Builds Requirements](assets/badges/bright-builds-requirements-light.svg)](${legacy_bright_builds_url})"
	old_compact_raw="[![Uses Bright Builds](${legacy_bright_builds_raw_base_url}/assets/badges/bright-builds-requirements-compact.svg)](${legacy_bright_builds_url})"
	old_compact_relative="[![Uses Bright Builds](assets/badges/bright-builds-requirements-compact.svg)](${legacy_bright_builds_url})"

	if [[ "$line" == "$old_canonical_raw" || "$line" == "$old_canonical_relative" ]]; then
		build_current_manual_bright_builds_badge_markdown "canonical"
		return 0
	fi

	if [[ "$line" == "$old_flat_raw" || "$line" == "$old_flat_relative" ]]; then
		build_current_manual_bright_builds_badge_markdown "flat"
		return 0
	fi

	if [[ "$line" == "$old_dark_raw" || "$line" == "$old_dark_relative" ]]; then
		build_current_manual_bright_builds_badge_markdown "dark"
		return 0
	fi

	if [[ "$line" == "$old_light_raw" || "$line" == "$old_light_relative" ]]; then
		build_current_manual_bright_builds_badge_markdown "light"
		return 0
	fi

	if [[ "$line" == "$old_compact_raw" || "$line" == "$old_compact_relative" ]]; then
		build_current_manual_bright_builds_badge_markdown "compact"
		return 0
	fi

	return 1
}

line_is_blank() {
	[[ "${1:-}" =~ ^[[:space:]]*$ ]]
}

readme_line_is_badge_like() {
	local line="$1"

	if [[ "$line" == *"shields.io"* || "$line" == *"badge.svg"* || "$line" == *"badge?"* ]]; then
		return 0
	fi

	if [[ "$line" == *"<img"* ]] && [[ "$line" == *"badge"* || "$line" == *"shields"* ]]; then
		return 0
	fi

	if [[ "$line" == *"raw.githubusercontent.com/bright-builds-llc/"*"/public/badges/bright-builds"*.svg* ]]; then
		return 0
	fi

	if [[ "$line" == *"raw.githubusercontent.com/bright-builds-llc/"*"/assets/badges/bright-builds"*.svg* ]]; then
		return 0
	fi

	if [[ "$line" == *"(public/badges/bright-builds"*.svg* || "$line" == *"(assets/badges/bright-builds"*.svg* ]]; then
		return 0
	fi

	return 1
}

append_readme_badge() {
	local badge_markdown="$1"

	[[ -n "$badge_markdown" ]] || return

	if [[ -n "$readme_badges_markdown" ]]; then
		readme_badges_markdown="${readme_badges_markdown}
"
	fi

	readme_badges_markdown="${readme_badges_markdown}${badge_markdown}"
	readme_has_managed_badges=1
}

append_bright_builds_readme_badge() {
	if [[ "$readme_has_managed_badges" -ne 1 ]]; then
		return 0
	fi

	append_readme_badge "[![Bright Builds: Rules](${bright_builds_badges_base_url}/bright-builds-rules-flat.svg)](${bright_builds_rules_url})"
}

append_owner_specific_readme_badge() {
	if ! is_openlinks_identity_owner "$downstream_repo_owner"; then
		return 0
	fi

	append_readme_badge "$(build_static_badge_markdown "OpenLinks" "profile" "0F172A" "" "" "$openlinks_identity_url")"
}

normalize_badge_version() {
	local raw_value="$1"
	local normalized=""

	normalized="$(trim_value "$raw_value")"
	normalized="${normalized#\"}"
	normalized="${normalized%\"}"
	normalized="${normalized#\'}"
	normalized="${normalized%\'}"
	normalized="$(trim_value "$normalized")"

	[[ -n "$normalized" ]] || return 1

	if [[ "$normalized" =~ [[:space:],|] ]]; then
		return 1
	fi

	case "$normalized" in
	^* | ~*)
		normalized="${normalized:1}"
		;;
	==*)
		normalized="${normalized#==}"
		;;
	=*)
		normalized="${normalized#=}"
		;;
	esac

	if [[ "$normalized" =~ ^[vV]([0-9]+([.][0-9]+){0,2})$ ]]; then
		normalized="${BASH_REMATCH[1]}"
	elif [[ "$normalized" =~ ^([0-9]+([.][0-9]+){0,2})([xX*]|[.][xX*])$ ]]; then
		normalized="${BASH_REMATCH[1]}"
	fi

	if [[ "$normalized" =~ ^(>=|<=|>|<)([0-9]+([.][0-9]+){0,2})$ ]]; then
		printf '%s\n' "${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
		return 0
	fi

	if [[ "$normalized" =~ ^[0-9A-Za-z._+-]+$ ]]; then
		printf '%s\n' "$normalized"
		return 0
	fi

	return 1
}

select_single_normalized_version() {
	local raw_value=""
	local normalized=""
	local maybe_existing=""
	local seen_values=()
	local already_seen=0

	while IFS= read -r raw_value; do
		if ! normalized="$(normalize_badge_version "$raw_value" 2>/dev/null)"; then
			continue
		fi

		already_seen=0
		for maybe_existing in "${seen_values[@]-}"; do
			if [[ "$maybe_existing" == "$normalized" ]]; then
				already_seen=1
				break
			fi
		done

		if [[ "$already_seen" -eq 0 ]]; then
			seen_values+=("$normalized")
		fi
	done

	if [[ "${#seen_values[@]}" -eq 1 ]]; then
		printf '%s\n' "${seen_values[0]}"
		return 0
	fi

	return 1
}

compact_json_file() {
	local file_path="$1"

	[[ -f "$file_path" ]] || return
	tr '\n' ' ' <"$file_path"
}

extract_json_object_string_values() {
	local compact_json="$1"
	local object_key="$2"
	local item_key="$3"
	local section=""
	local value=""

	while IFS= read -r section; do
		[[ -n "$section" ]] || continue
		value="$(printf '%s\n' "$section" | sed -n "s/.*\"${item_key}\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p")"
		if [[ -n "$value" ]]; then
			printf '%s\n' "$value"
		fi
	done < <(printf '%s' "$compact_json" | grep -oE "\"${object_key}\"[[:space:]]*:[[:space:]]*\\{[^}]*\\}" || true)
}

extract_package_json_dependency_values() {
	local compact_json="$1"
	local package_name="$2"
	local section=""
	local value=""

	for section in dependencies devDependencies; do
		while IFS= read -r value; do
			[[ -n "$value" ]] || continue
			printf '%s\n' "$value"
		done < <(
			while IFS= read -r maybe_section; do
				[[ -n "$maybe_section" ]] || continue
				printf '%s\n' "$maybe_section" | sed -n "s/.*\"${package_name}\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p"
			done < <(printf '%s' "$compact_json" | grep -oE "\"${section}\"[[:space:]]*:[[:space:]]*\\{[^}]*\\}" || true)
		)
	done
}

detect_existing_path() {
	local candidate=""

	for candidate in "$@"; do
		if [[ -f "${repo_root}/${candidate}" ]]; then
			printf '%s\n' "$candidate"
			return 0
		fi
	done

	return 1
}

detect_license_file() {
	detect_existing_path \
		"LICENSE" \
		"LICENSE.md" \
		"LICENSE.txt" \
		"COPYING" \
		"COPYING.md" \
		"COPYING.txt"
}

extract_github_slug_from_remote_url() {
	local remote_url="$1"
	local maybe_slug=""

	maybe_slug="$(printf '%s' "$remote_url" | sed -n \
		-e 's#^https://github.com/\([^/][^ ]*\)$#\1#p' \
		-e 's#^git@github.com:\([^/][^ ]*\)$#\1#p' \
		-e 's#^ssh://git@github.com/\([^/][^ ]*\)$#\1#p' \
		-e 's#^git://github.com/\([^/][^ ]*\)$#\1#p')"
	maybe_slug="${maybe_slug%.git}"
	maybe_slug="${maybe_slug%/}"

	if [[ "$maybe_slug" =~ ^[^/]+/[^/]+$ ]]; then
		printf '%s\n' "$maybe_slug"
		return 0
	fi

	return 1
}

resolve_downstream_repo_slug() {
	local remote_url=""

	downstream_repo_slug=""
	downstream_repo_url=""
	downstream_repo_owner=""

	if ! command -v git >/dev/null 2>&1; then
		return
	fi

	if ! remote_url="$(git -C "$repo_root" remote get-url origin 2>/dev/null)"; then
		return
	fi

	if ! downstream_repo_slug="$(extract_github_slug_from_remote_url "$remote_url" 2>/dev/null)"; then
		downstream_repo_slug=""
		return
	fi

	downstream_repo_url="https://github.com/${downstream_repo_slug}"
	downstream_repo_owner="$(extract_repo_owner_from_slug "$downstream_repo_slug")"
}

resolve_current_github_user() {
	local maybe_actor="${GITHUB_ACTOR:-}"
	local maybe_login=""

	current_github_user=""

	if [[ -n "$maybe_actor" ]] && [[ "$(normalize_github_identity "$maybe_actor")" != "github-actions[bot]" ]]; then
		current_github_user="$maybe_actor"
		return
	fi

	if ! command -v gh >/dev/null 2>&1; then
		return
	fi

	maybe_login="$(gh api user --jq .login 2>/dev/null || true)"

	if [[ -n "$maybe_login" ]] && [[ "$(normalize_github_identity "$maybe_login")" != "github-actions[bot]" ]]; then
		current_github_user="$maybe_login"
	fi
}

detect_node_version_info() {
	local package_json_path="${repo_root}/package.json"
	local compact_json=""
	local maybe_raw_engine=""
	local maybe_normalized=""
	local maybe_nvmrc_path="${repo_root}/.nvmrc"
	local maybe_nvmrc_line=""
	local maybe_ci_version=""

	if [[ -f "$package_json_path" ]]; then
		compact_json="$(compact_json_file "$package_json_path")"
		maybe_raw_engine="$(extract_json_object_string_values "$compact_json" "engines" "node" | head -n 1)"

		if [[ -n "$maybe_raw_engine" ]]; then
			if maybe_normalized="$(normalize_badge_version "$maybe_raw_engine" 2>/dev/null)"; then
				printf '%s|package.json\n' "$maybe_normalized"
			fi
			return
		fi
	fi

	if [[ -f "$maybe_nvmrc_path" ]]; then
		maybe_nvmrc_line="$(awk 'NF { print; exit }' "$maybe_nvmrc_path")"
		if [[ -n "$maybe_nvmrc_line" ]]; then
			if maybe_normalized="$(normalize_badge_version "$maybe_nvmrc_line" 2>/dev/null)"; then
				printf '%s|.nvmrc\n' "$maybe_normalized"
			fi
			return
		fi
	fi

	if [[ -n "$downstream_ci_workflow_path" ]] && grep -q 'actions/setup-node' "${repo_root}/${downstream_ci_workflow_path}"; then
		maybe_ci_version="$(
			grep -E '^[[:space:]]*node-version:[[:space:]]*' "${repo_root}/${downstream_ci_workflow_path}" |
				sed -n "s/^[[:space:]]*node-version:[[:space:]]*['\"]\{0,1\}\([^'\"#[:space:]]*\)['\"]\{0,1\}.*/\\1/p" |
				select_single_normalized_version || true
		)"
		if [[ -n "$maybe_ci_version" ]]; then
			printf '%s|%s\n' "$maybe_ci_version" "$downstream_ci_workflow_path"
		fi
	fi
}

detect_package_json_dependency_version() {
	local package_name="$1"
	local package_json_path="${repo_root}/package.json"
	local compact_json=""

	[[ -f "$package_json_path" ]] || return 0

	compact_json="$(compact_json_file "$package_json_path")"
	extract_package_json_dependency_values "$compact_json" "$package_name" | select_single_normalized_version || true
}

detect_framework_badge_info() {
	local maybe_next=""
	local maybe_solid=""
	local maybe_react=""
	local maybe_vue=""
	local maybe_svelte=""
	local candidates=()

	maybe_next="$(detect_package_json_dependency_version "next" || true)"
	maybe_solid="$(detect_package_json_dependency_version "solid-js" || true)"
	maybe_react="$(detect_package_json_dependency_version "react" || true)"
	maybe_vue="$(detect_package_json_dependency_version "vue" || true)"
	maybe_svelte="$(detect_package_json_dependency_version "svelte" || true)"

	if [[ -n "$maybe_next" ]]; then
		candidates+=("Next.js|${maybe_next}|000000|nextdotjs|white|https://nextjs.org/")
	fi

	if [[ -n "$maybe_solid" ]]; then
		candidates+=("SolidJS|${maybe_solid}|2C4F7C|solid|white|https://www.solidjs.com/")
	fi

	if [[ -n "$maybe_vue" ]]; then
		candidates+=("Vue|${maybe_vue}|4FC08D|vuedotjs|white|https://vuejs.org/")
	fi

	if [[ -n "$maybe_svelte" ]]; then
		candidates+=("Svelte|${maybe_svelte}|FF3E00|svelte|white|https://svelte.dev/")
	fi

	if [[ -n "$maybe_react" && -z "$maybe_next" ]]; then
		candidates+=("React|${maybe_react}|149ECA|react|white|https://react.dev/")
	fi

	if [[ "${#candidates[@]}" -eq 1 ]]; then
		printf '%s\n' "${candidates[0]}"
	fi
}

extract_toml_value_from_section() {
	local file_path="$1"
	local section_name="$2"
	local key_name="$3"

	[[ -f "$file_path" ]] || return

	awk -v section_name="$section_name" -v key_name="$key_name" '
    $0 ~ "^[[:space:]]*\\[" section_name "\\][[:space:]]*$" {
      in_section = 1
      next
    }

    in_section == 1 && $0 ~ "^[[:space:]]*\\[" {
      in_section = 0
    }

    in_section == 1 && $0 ~ "^[[:space:]]*" key_name "[[:space:]]*=" {
      value = $0
      sub(/^[[:space:]]*[^=]+=[[:space:]]*/, "", value)
      sub(/[[:space:]]*#.*/, "", value)
      gsub(/^"/, "", value)
      gsub(/"$/, "", value)
      gsub(/^'\''/, "", value)
      gsub(/'\''$/, "", value)
      print value
      exit
    }
  ' "$file_path"
}

detect_rust_version() {
	local maybe_rust_toolchain="${repo_root}/rust-toolchain.toml"
	local maybe_cargo_toml="${repo_root}/Cargo.toml"
	local maybe_channel=""
	local maybe_normalized=""

	if [[ -f "$maybe_rust_toolchain" ]]; then
		maybe_channel="$(extract_toml_value_from_section "$maybe_rust_toolchain" "toolchain" "channel")"
		if [[ -n "$maybe_channel" ]]; then
			if maybe_normalized="$(normalize_badge_version "$maybe_channel" 2>/dev/null)"; then
				printf '%s\n' "$maybe_normalized"
			fi
			return
		fi
	fi

	if [[ -f "$maybe_cargo_toml" ]]; then
		maybe_channel="$(extract_toml_value_from_section "$maybe_cargo_toml" "package" "rust-version")"
		if [[ -n "$maybe_channel" ]]; then
			if maybe_normalized="$(normalize_badge_version "$maybe_channel" 2>/dev/null)"; then
				printf '%s\n' "$maybe_normalized"
			fi
		fi
	fi
}

detect_python_version() {
	local maybe_pyproject="${repo_root}/pyproject.toml"
	local maybe_python_version_file="${repo_root}/.python-version"
	local maybe_requires_python=""
	local maybe_normalized=""

	if [[ -f "$maybe_pyproject" ]]; then
		maybe_requires_python="$(awk '
      /^[[:space:]]*requires-python[[:space:]]*=/ {
        value = $0
        sub(/^[[:space:]]*requires-python[[:space:]]*=[[:space:]]*/, "", value)
        sub(/[[:space:]]*#.*/, "", value)
        gsub(/^"/, "", value)
        gsub(/"$/, "", value)
        gsub(/^'\''/, "", value)
        gsub(/'\''$/, "", value)
        print value
        exit
      }
    ' "$maybe_pyproject")"

		if [[ -n "$maybe_requires_python" ]]; then
			if maybe_normalized="$(normalize_badge_version "$maybe_requires_python" 2>/dev/null)"; then
				printf '%s\n' "$maybe_normalized"
			fi
			return
		fi
	fi

	if [[ -f "$maybe_python_version_file" ]]; then
		maybe_requires_python="$(awk 'NF { print; exit }' "$maybe_python_version_file")"
		if [[ -n "$maybe_requires_python" ]]; then
			if maybe_normalized="$(normalize_badge_version "$maybe_requires_python" 2>/dev/null)"; then
				printf '%s\n' "$maybe_normalized"
			fi
		fi
	fi
}

detect_go_version() {
	local maybe_go_mod="${repo_root}/go.mod"
	local maybe_go_version=""
	local maybe_normalized=""

	[[ -f "$maybe_go_mod" ]] || return 0

	maybe_go_version="$(awk '/^go[[:space:]]+[0-9]+([.][0-9]+){0,2}$/ { print $2; exit }' "$maybe_go_mod")"
	if [[ -n "$maybe_go_version" ]]; then
		if maybe_normalized="$(normalize_badge_version "$maybe_go_version" 2>/dev/null)"; then
			printf '%s\n' "$maybe_normalized"
		fi
	fi
}

resolve_downstream_badges() {
	local maybe_node_info=""
	local maybe_node_version=""
	local maybe_node_link=""
	local maybe_typescript_version=""
	local maybe_vite_version=""
	local maybe_framework_info=""
	local framework_label=""
	local framework_version=""
	local framework_color=""
	local framework_logo=""
	local framework_logo_color=""
	local framework_link=""
	local maybe_rust_version=""
	local maybe_python_version=""
	local maybe_go_version=""

	readme_badges_markdown=""
	readme_has_managed_badges=0
	downstream_ci_workflow_path="$(detect_existing_path ".github/workflows/ci.yml" ".github/workflows/ci.yaml" || true)"
	downstream_deploy_workflow_path="$(detect_existing_path ".github/workflows/deploy-pages.yml" ".github/workflows/deploy-pages.yaml" || true)"
	downstream_license_file="$(detect_license_file || true)"
	resolve_downstream_repo_slug

	if [[ -n "$downstream_repo_slug" ]]; then
		append_readme_badge "[![GitHub Stars](https://img.shields.io/github/stars/${downstream_repo_slug})](${downstream_repo_url})"

		if [[ -n "$downstream_ci_workflow_path" ]]; then
			local ci_workflow_badge_file=""
			ci_workflow_badge_file="$(basename "$downstream_ci_workflow_path")"
			append_readme_badge "[![CI](https://img.shields.io/github/actions/workflow/status/${downstream_repo_slug}/${ci_workflow_badge_file}?style=flat-square&logo=github&label=CI)](${downstream_repo_url}/actions/workflows/${ci_workflow_badge_file})"
		fi

		if [[ -n "$downstream_deploy_workflow_path" ]]; then
			local deploy_workflow_badge_file=""
			deploy_workflow_badge_file="$(basename "$downstream_deploy_workflow_path")"
			append_readme_badge "[![Deploy Pages](https://img.shields.io/github/actions/workflow/status/${downstream_repo_slug}/${deploy_workflow_badge_file}?style=flat-square&logo=github&label=Deploy%20Pages)](${downstream_repo_url}/actions/workflows/${deploy_workflow_badge_file})"
		fi

		if [[ -n "$downstream_license_file" ]]; then
			append_readme_badge "[![License](https://img.shields.io/github/license/${downstream_repo_slug}?style=flat-square)](./${downstream_license_file})"
		fi
	fi

	maybe_node_info="$(detect_node_version_info || true)"
	if [[ -n "$maybe_node_info" ]]; then
		maybe_node_version="${maybe_node_info%%|*}"
		maybe_node_link="${maybe_node_info#*|}"
		append_readme_badge "$(build_static_badge_markdown "Node.js" "$maybe_node_version" "339933" "node.js" "white" "./${maybe_node_link}")"
	fi

	maybe_typescript_version="$(detect_package_json_dependency_version "typescript" || true)"
	if [[ -n "$maybe_typescript_version" ]]; then
		append_readme_badge "$(build_static_badge_markdown "TypeScript" "$maybe_typescript_version" "3178C6" "typescript" "white" "https://www.typescriptlang.org/")"
	fi

	maybe_framework_info="$(detect_framework_badge_info || true)"
	if [[ -n "$maybe_framework_info" ]]; then
		IFS='|' read -r framework_label framework_version framework_color framework_logo framework_logo_color framework_link <<<"$maybe_framework_info"
		append_readme_badge "$(build_static_badge_markdown "$framework_label" "$framework_version" "$framework_color" "$framework_logo" "$framework_logo_color" "$framework_link")"
	fi

	maybe_vite_version="$(detect_package_json_dependency_version "vite" || true)"
	if [[ -n "$maybe_vite_version" ]]; then
		append_readme_badge "$(build_static_badge_markdown "Vite" "$maybe_vite_version" "646CFF" "vite" "white" "https://vite.dev/")"
	fi

	maybe_rust_version="$(detect_rust_version || true)"
	if [[ -n "$maybe_rust_version" ]]; then
		append_readme_badge "$(build_static_badge_markdown "Rust" "$maybe_rust_version" "000000" "rust" "white" "https://www.rust-lang.org/")"
	fi

	maybe_python_version="$(detect_python_version || true)"
	if [[ -n "$maybe_python_version" ]]; then
		append_readme_badge "$(build_static_badge_markdown "Python" "$maybe_python_version" "3776AB" "python" "white" "https://www.python.org/")"
	fi

	maybe_go_version="$(detect_go_version || true)"
	if [[ -n "$maybe_go_version" ]]; then
		append_readme_badge "$(build_static_badge_markdown "Go" "$maybe_go_version" "00ADD8" "go" "white" "https://go.dev/")"
	fi

	append_bright_builds_readme_badge
	append_owner_specific_readme_badge
}

resolve_owner_specific_guidance() {
	owner_specific_guidance_markdown="$(build_owner_specific_guidance_markdown)"
}

resolve_auto_update_default() {
	auto_update_mode="disabled"
	auto_update_reason="default disabled"

	if is_trusted_auto_update_identity "$downstream_repo_owner"; then
		auto_update_mode="enabled"
		auto_update_reason="trusted repo owner ${downstream_repo_owner}"
		return
	fi

	resolve_current_github_user

	if is_trusted_auto_update_identity "$current_github_user"; then
		auto_update_mode="enabled"
		auto_update_reason="trusted GitHub user ${current_github_user}"
	fi
}

resolve_auto_update_state() {
	auto_update_mode=""
	auto_update_reason=""

	if [[ "$auto_update_was_explicit" -eq 0 ]] && [[ "$current_auto_update" == "enabled" || "$current_auto_update" == "disabled" ]]; then
		auto_update_mode="$current_auto_update"
		auto_update_reason="$current_auto_update_reason"

		if [[ -z "$auto_update_reason" ]]; then
			auto_update_reason="explicit"
		fi

		return
	fi

	case "$auto_update_request" in
	enabled | disabled)
		auto_update_mode="$auto_update_request"
		auto_update_reason="explicit"
		;;
	auto)
		resolve_auto_update_default
		;;
	*)
		die "unsupported auto-update mode: ${auto_update_request}"
		;;
	esac
}

auto_update_files_are_relevant() {
	[[ "$auto_update_mode" == "enabled" || "$current_auto_update" == "enabled" ]]
}

detect_marker_block_state() {
	local file_path="$1"
	local begin_marker="$2"
	local end_marker="$3"

	if [[ ! -f "$file_path" ]]; then
		printf 'absent\n'
		return
	fi

	awk -v begin_marker="$begin_marker" -v end_marker="$end_marker" '
    $0 == begin_marker {
      begin_count++
      if (begin_line == 0) {
        begin_line = NR
      }
    }

    $0 == end_marker {
      end_count++
      if (end_line == 0) {
        end_line = NR
      }
    }

    END {
      if (begin_count == 0 && end_count == 0) {
        print "absent"
        exit
      }

      if (begin_count == 1 && end_count == 1 && begin_line < end_line) {
        print "present"
        exit
      }

      print "partial"
    }
  ' "$file_path"
}

compatible_marker_state="absent"
compatible_marker_family="absent"

resolve_compatible_marker_block_state() {
	local file_path="$1"
	local current_begin_marker="$2"
	local current_end_marker="$3"
	local legacy_begin_marker="$4"
	local legacy_end_marker="$5"
	local current_state=""
	local legacy_state=""

	compatible_marker_state="absent"
	compatible_marker_family="absent"

	current_state="$(detect_marker_block_state "$file_path" "$current_begin_marker" "$current_end_marker")"
	legacy_state="$(detect_marker_block_state "$file_path" "$legacy_begin_marker" "$legacy_end_marker")"

	if [[ "$current_state" == "present" && "$legacy_state" == "absent" ]]; then
		compatible_marker_state="present"
		compatible_marker_family="current"
		return
	fi

	if [[ "$current_state" == "absent" && "$legacy_state" == "present" ]]; then
		compatible_marker_state="present"
		compatible_marker_family="legacy"
		return
	fi

	if [[ "$current_state" == "absent" && "$legacy_state" == "absent" ]]; then
		compatible_marker_state="absent"
		compatible_marker_family="absent"
		return
	fi

	compatible_marker_state="partial"
	compatible_marker_family="partial"
}

resolve_agents_block_state() {
	local file_path="$1"

	resolve_compatible_marker_block_state "$file_path" "$agents_block_begin" "$agents_block_end" "$legacy_agents_block_begin" "$legacy_agents_block_end"
	agents_block_state="$compatible_marker_state"
	agents_block_family="$compatible_marker_family"
}

resolve_readme_badges_block_state() {
	local file_path="$1"

	resolve_compatible_marker_block_state "$file_path" "$readme_badges_begin" "$readme_badges_end" "$legacy_readme_badges_begin" "$legacy_readme_badges_end"
	readme_badges_family="$compatible_marker_family"
}

line_is_any_readme_badges_begin_marker() {
	[[ "${1:-}" == "$readme_badges_begin" || "${1:-}" == "$legacy_readme_badges_begin" ]]
}

line_is_any_readme_badges_end_marker() {
	[[ "${1:-}" == "$readme_badges_end" || "${1:-}" == "$legacy_readme_badges_end" ]]
}

readme_insertion_zone_has_unmanaged_badges() {
	local file_path="$1"
	local lines=()
	local line=""
	local maybe_replacement=""
	local first_h1_index=-1
	local index=0
	local start_index=0
	local in_managed=0

	[[ -f "$file_path" ]] || return 1

	while IFS= read -r line || [[ -n "$line" ]]; do
		lines+=("$line")
	done <"$file_path"

	for ((index = 0; index < ${#lines[@]}; index++)); do
		if [[ "${lines[index]}" == '# '* ]]; then
			first_h1_index="$index"
			break
		fi
	done

	if ((first_h1_index >= 0)); then
		start_index=$((first_h1_index + 1))
	fi

	for ((index = start_index; index < ${#lines[@]}; index++)); do
		line="${lines[index]}"

		if line_is_any_readme_badges_begin_marker "$line"; then
			in_managed=1
			continue
		fi

		if line_is_any_readme_badges_end_marker "$line"; then
			in_managed=0
			continue
		fi

		if [[ "$in_managed" -eq 1 ]] || line_is_blank "$line"; then
			continue
		fi

		if maybe_replacement="$(normalize_known_legacy_bright_builds_badge_line "$line" 2>/dev/null)"; then
			continue
		fi

		if readme_line_is_badge_like "$line"; then
			return 0
		fi

		break
	done

	return 1
}

resolve_readme_badge_state() {
	local destination_path="${repo_root}/${readme_destination}"
	local block_state=""

	readme_badge_blocking_reason=""

	if [[ ! -f "$destination_path" ]]; then
		if [[ "$readme_has_managed_badges" -eq 1 ]]; then
			printf 'absent\n'
		else
			printf 'not applicable\n'
		fi
		return
	fi

	resolve_readme_badges_block_state "$destination_path"
	block_state="$compatible_marker_state"

	if [[ "$block_state" == "partial" ]]; then
		readme_badge_blocking_reason="incomplete managed README badge block"
		printf 'partial\n'
		return
	fi

	if { [[ "$readme_has_managed_badges" -eq 1 ]] || [[ "$block_state" == "present" ]]; } && readme_insertion_zone_has_unmanaged_badges "$destination_path"; then
		readme_badge_blocking_reason="existing badge-like content in the managed README insertion zone"
		printf 'ambiguous\n'
		return
	fi

	if [[ "$block_state" == "present" ]]; then
		printf 'present\n'
		return
	fi

	if [[ "$readme_has_managed_badges" -eq 1 ]]; then
		printf 'absent\n'
		return
	fi

	printf 'not applicable\n'
}

replace_marker_block() {
	local input_path="$1"
	local output_path="$2"
	local replacement_path="$3"
	local begin_marker="$4"
	local end_marker="$5"

	awk -v begin_marker="$begin_marker" -v end_marker="$end_marker" -v replacement_path="$replacement_path" '
    BEGIN {
      while ((getline line < replacement_path) > 0) {
        replacement[++replacement_count] = line
      }
      close(replacement_path)
    }

    $0 == begin_marker && in_block == 0 {
      for (i = 1; i <= replacement_count; i++) {
        print replacement[i]
      }
      in_block = 1
      replaced = 1
      next
    }

    in_block == 1 {
      if ($0 == end_marker) {
        in_block = 0
      }
      next
    }

    {
      print
    }

    END {
      if (replaced != 1) {
        exit 3
      }
    }
  ' "$input_path" >"$output_path"
}

replace_managed_block() {
	resolve_agents_block_state "$1"

	if [[ "$agents_block_family" == "legacy" ]]; then
		replace_marker_block "$1" "$2" "$3" "$legacy_agents_block_begin" "$legacy_agents_block_end"
		return
	fi

	replace_marker_block "$1" "$2" "$3" "$agents_block_begin" "$agents_block_end"
}

replace_readme_badges_block() {
	resolve_readme_badges_block_state "$1"

	if [[ "$readme_badges_family" == "legacy" ]]; then
		replace_marker_block "$1" "$2" "$3" "$legacy_readme_badges_begin" "$legacy_readme_badges_end"
		return
	fi

	replace_marker_block "$1" "$2" "$3" "$readme_badges_begin" "$readme_badges_end"
}

remove_marker_block() {
	local input_path="$1"
	local output_path="$2"
	local begin_marker="$3"
	local end_marker="$4"

	awk -v begin_marker="$begin_marker" -v end_marker="$end_marker" '
    $0 == begin_marker && in_block == 0 {
      in_block = 1
      removed = 1
      next
    }

    in_block == 1 {
      if ($0 == end_marker) {
        in_block = 0
      }
      next
    }

    {
      print
    }

    END {
      if (removed != 1) {
        exit 3
      }
    }
  ' "$input_path" >"$output_path"
}

remove_managed_block() {
	resolve_agents_block_state "$1"

	if [[ "$agents_block_family" == "legacy" ]]; then
		remove_marker_block "$1" "$2" "$legacy_agents_block_begin" "$legacy_agents_block_end"
		return
	fi

	remove_marker_block "$1" "$2" "$agents_block_begin" "$agents_block_end"
}

remove_readme_badges_block() {
	resolve_readme_badges_block_state "$1"

	if [[ "$readme_badges_family" == "legacy" ]]; then
		remove_marker_block "$1" "$2" "$legacy_readme_badges_begin" "$legacy_readme_badges_end"
		return
	fi

	remove_marker_block "$1" "$2" "$readme_badges_begin" "$readme_badges_end"
}

remove_readme_badge_markers() {
	local input_path="$1"
	local output_path="$2"

	awk -v begin_marker="$readme_badges_begin" -v end_marker="$readme_badges_end" -v legacy_begin_marker="$legacy_readme_badges_begin" -v legacy_end_marker="$legacy_readme_badges_end" '
    $0 == begin_marker || $0 == end_marker || $0 == legacy_begin_marker || $0 == legacy_end_marker {
      next
    }

    {
      print
    }
  ' "$input_path" >"$output_path"
}

render_readme_badges_block_to_tmp_path() {
	local rendered_path=""

	ensure_tmp_dir
	rendered_path="${tmp_dir}/README.badges.rendered"
	{
		printf '%s\n' "$readme_badges_begin"
		printf '%s\n' "<!-- Managed upstream by bright-builds-rules. If this badge block needs a fix, open an upstream PR or issue instead of editing the downstream managed block. Keep repo-local README content outside this managed badge block. -->"
		if [[ -n "$readme_badges_markdown" ]]; then
			printf '%s\n' "$readme_badges_markdown"
		fi
		printf '%s\n' "$readme_badges_end"
	} >"$rendered_path"

	printf '%s\n' "$rendered_path"
}

insert_readme_badges_block() {
	local input_path="$1"
	local output_path="$2"
	local replacement_path="$3"

	awk -v replacement_path="$replacement_path" '
    BEGIN {
      while ((getline line < replacement_path) > 0) {
        replacement[++replacement_count] = line
      }
      close(replacement_path)
    }

    {
      lines[++count] = $0
      if (first_h1 == 0 && $0 ~ /^# /) {
        first_h1 = count
      }
    }

    END {
      if (first_h1 > 0) {
        for (i = 1; i <= count; i++) {
          print lines[i]

          if (i == first_h1) {
            print ""
            for (j = 1; j <= replacement_count; j++) {
              print replacement[j]
            }

            if (i < count) {
              print ""
            }

            while (i + 1 <= count && lines[i + 1] ~ /^[[:space:]]*$/) {
              i++
            }
          }
        }
        exit
      }

      for (j = 1; j <= replacement_count; j++) {
        print replacement[j]
      }

      if (count > 0) {
        print ""
      }

      first_content = 1
      while (first_content <= count && lines[first_content] ~ /^[[:space:]]*$/) {
        first_content++
      }

      for (i = first_content; i <= count; i++) {
        print lines[i]
      }
    }
  ' "$input_path" >"$output_path"
}

strip_readme_badge_region() {
	local input_path="$1"
	local output_path="$2"
	local lines=()
	local line=""
	local first_h1_index=-1
	local start_index=0
	local index=0
	local in_marker_block=0

	while IFS= read -r line || [[ -n "$line" ]]; do
		lines+=("$line")
	done <"$input_path"

	for ((index = 0; index < ${#lines[@]}; index++)); do
		if [[ "${lines[index]}" == '# '* ]]; then
			first_h1_index="$index"
			break
		fi
	done

	if ((first_h1_index >= 0)); then
		start_index=$((first_h1_index + 1))
	fi

	{
		if ((first_h1_index >= 0)); then
			for ((index = 0; index <= first_h1_index; index++)); do
				printf '%s\n' "${lines[index]}"
			done
		fi

		index="$start_index"
		while ((index < ${#lines[@]})); do
			line="${lines[index]}"

			if [[ "$in_marker_block" -eq 1 ]]; then
				if line_is_any_readme_badges_end_marker "$line"; then
					in_marker_block=0
					((index++))
					continue
				fi

				if line_is_blank "$line" || readme_line_is_badge_like "$line" || line_is_any_readme_badges_begin_marker "$line"; then
					((index++))
					continue
				fi

				break
			fi

			if line_is_any_readme_badges_begin_marker "$line"; then
				in_marker_block=1
				((index++))
				continue
			fi

			if line_is_any_readme_badges_end_marker "$line" || line_is_blank "$line" || readme_line_is_badge_like "$line"; then
				((index++))
				continue
			fi

			break
		done

		if ((first_h1_index >= 0 && index < ${#lines[@]})); then
			printf '\n'
		fi

		for (( ; index < ${#lines[@]}; index++)); do
			printf '%s\n' "${lines[index]}"
		done
	} >"$output_path"
}

normalize_legacy_bright_builds_readme_badges() {
	local input_path="$1"
	local output_path="$2"
	local remove_insertion_zone_legacy="$3"
	local lines=()
	local line=""
	local maybe_replacement=""
	local first_h1_index=-1
	local start_index=0
	local index=0
	local in_insertion_zone=0
	local insertion_zone_complete=0

	while IFS= read -r line || [[ -n "$line" ]]; do
		lines+=("$line")
	done <"$input_path"

	for ((index = 0; index < ${#lines[@]}; index++)); do
		if [[ "${lines[index]}" == '# '* ]]; then
			first_h1_index="$index"
			break
		fi
	done

	if ((first_h1_index >= 0)); then
		start_index=$((first_h1_index + 1))
	fi

	{
		for ((index = 0; index < ${#lines[@]}; index++)); do
			line="${lines[index]}"

			if ((insertion_zone_complete == 0 && index >= start_index)) && [[ "$in_insertion_zone" -eq 0 ]]; then
				in_insertion_zone=1
			fi

			if maybe_replacement="$(normalize_known_legacy_bright_builds_badge_line "$line" 2>/dev/null)"; then
				if [[ "$in_insertion_zone" -eq 1 && "$remove_insertion_zone_legacy" -eq 1 ]]; then
					continue
				fi

				printf '%s\n' "$maybe_replacement"
				continue
			fi

			printf '%s\n' "$line"

			if [[ "$in_insertion_zone" -eq 1 ]] && ! line_is_blank "$line" && ! readme_line_is_badge_like "$line"; then
				in_insertion_zone=0
				insertion_zone_complete=1
			fi
		done
	} >"$output_path"
}

build_readme_title() {
	printf '# %s\n' "$(basename "$repo_root")"
}

readme_is_generated_skeleton_after_removal() {
	local file_path="$1"
	local expected_title=""
	local trimmed_content=""

	[[ -f "$file_path" ]] || return 1

	expected_title="$(build_readme_title)"
	trimmed_content="$(awk '
    {
      lines[++count] = $0
    }

    END {
      last = count
      while (last > 0 && lines[last] ~ /^[[:space:]]*$/) {
        last--
      }

      first = 1
      while (first <= last && lines[first] ~ /^[[:space:]]*$/) {
        first++
      }

      for (i = first; i <= last; i++) {
        print lines[i]
      }
    }
  ' "$file_path")"

	[[ "$trimmed_content" == "$expected_title" ]]
}

append_unique_blocking_path() {
	local candidate="$1"
	local existing=""

	for existing in "${blocking_paths[@]-}"; do
		if [[ "$existing" == "$candidate" ]]; then
			return
		fi
	done

	blocking_paths+=("$candidate")
}

write_or_update_agents_file() {
	local destination_path="${repo_root}/${agents_destination}"
	local rendered_block_path=""
	local updated_path=""
	local stripped_path=""

	rendered_block_path="$(render_template_to_tmp_path "$agents_block_source" "agents-block")"
	resolve_agents_block_state "$destination_path"

	if [[ ! -f "$destination_path" ]]; then
		cp "$rendered_block_path" "$destination_path"
		note "Wrote ${agents_destination}"
		return
	fi

	case "$agents_block_state" in
	absent)
		ensure_tmp_dir
		updated_path="${tmp_dir}/AGENTS.updated"
		stripped_path="${tmp_dir}/AGENTS.stripped"
		trim_trailing_blank_lines "$destination_path" "$stripped_path"

		if file_has_non_whitespace "$stripped_path"; then
			{
				cat "$stripped_path"
				printf '\n\n'
				cat "$rendered_block_path"
			} >"$updated_path"
		else
			cp "$rendered_block_path" "$updated_path"
		fi

		cp "$updated_path" "$destination_path"
		note "Updated ${agents_destination}"
		;;
	present)
		ensure_tmp_dir
		updated_path="${tmp_dir}/AGENTS.updated"
		replace_managed_block "$destination_path" "$updated_path" "$rendered_block_path"
		cp "$updated_path" "$destination_path"
		note "Updated ${agents_destination}"
		;;
	partial)
		die "${agents_destination} contains an incomplete managed marker block. Re-run install --force to back up and replace it."
		;;
	esac
}

ensure_overrides_file() {
	local destination_path="${repo_root}/${overrides_destination}"

	if [[ -f "$destination_path" ]]; then
		return
	fi

	write_rendered_file "$overrides_source" "$overrides_destination"
}

build_current_managed_status_paths() {
	local effective_audit_destination=""
	local entries=()

	effective_audit_destination="$(resolve_effective_audit_destination)"
	entries=(
		"${agents_destination}"
		"${sidecar_destination}"
		"CONTRIBUTING.md"
		".github/pull_request_template.md"
		"${effective_audit_destination}"
		"${overrides_destination}"
	)

	if auto_update_files_are_relevant; then
		entries+=("${auto_update_script_destination}" "${auto_update_workflow_destination}")
	fi

	printf '%s\n' "${entries[@]}"
}

build_managed_files_markdown_for_state() {
	local current_readme_badge_state="$1"
	local current_auto_update_mode="$2"
	local current_audit_relative_destination="${3:-$audit_destination}"
	local entries=(
		"${agents_destination} (managed block)"
		"${sidecar_destination}"
		"CONTRIBUTING.md"
		".github/pull_request_template.md"
		"${current_audit_relative_destination}"
	)

	if [[ "$current_readme_badge_state" == "present" ]]; then
		entries+=("${readme_destination} (managed badges block)")
	fi

	if [[ "$current_auto_update_mode" == "enabled" ]]; then
		entries+=("${auto_update_script_destination}" "${auto_update_workflow_destination}")
	fi

	build_managed_files_markdown "${entries[@]}"
}

build_current_managed_files_markdown() {
	build_managed_files_markdown_for_state "$readme_badge_state" "$auto_update_mode" "$audit_destination"
}

build_installed_managed_files_markdown() {
	build_managed_files_markdown_for_state "$readme_badge_state" "${current_auto_update:-$auto_update_mode}" "$(resolve_effective_audit_destination)"
}

remove_auto_update_files() {
	local relative_destination=""

	for relative_destination in "${auto_update_script_destination}" "${auto_update_workflow_destination}"; do
		if [[ -f "${repo_root}/${relative_destination}" ]]; then
			rm -f "${repo_root}/${relative_destination}"
			note "Removed ${relative_destination}"
		fi
	done

	rmdir "${repo_root}/.github/workflows" 2>/dev/null || true
	rmdir "${repo_root}/.github" 2>/dev/null || true
}

build_whole_file_managed_pairs_for_mode() {
	local current_auto_update_mode="$1"
	local entries=("${base_whole_file_managed_pairs[@]}")

	if [[ "$current_auto_update_mode" == "enabled" ]]; then
		entries+=(
			"${auto_update_script_source}|${auto_update_script_destination}"
			"${auto_update_workflow_source}|${auto_update_workflow_destination}"
		)
	fi

	printf '%s\n' "${entries[@]}"
}

candidate_path_matches_destination() {
	local destination_path="$1"
	local candidate_path="$2"

	[[ -n "$candidate_path" && -f "$candidate_path" ]] || return 1
	cmp -s "$destination_path" "$candidate_path"
}

resolve_whole_file_managed_state() {
	local source_path="$1"
	local relative_destination="$2"
	local managed_files_markdown="${3:-}"
	local destination_path="${repo_root}/${relative_destination}"
	local actual_relative_destination="$relative_destination"
	local marked_path=""
	local legacy_path=""
	local actual_owner_specific_guidance_owner=""
	local alternate_marked_path=""
	local alternate_legacy_path=""
	local legacy_identity_marked_path=""
	local legacy_identity_unmarked_path=""
	local prerename_compat_marked_path=""
	local prerename_compat_unmarked_path=""

	if [[ "$relative_destination" == "$audit_destination" && ! -f "$destination_path" && -f "${repo_root}/${legacy_audit_destination}" ]]; then
		destination_path="${repo_root}/${legacy_audit_destination}"
		actual_relative_destination="$legacy_audit_destination"
	fi

	if [[ ! -f "$destination_path" ]]; then
		printf 'missing\n'
		return
	fi

	marked_path="$(render_template_to_tmp_path_for_install_state "$source_path" "$(basename "$relative_destination").marked" "$relative_destination" "$managed_files_markdown" "enabled")"
	if candidate_path_matches_destination "$destination_path" "$marked_path"; then
		printf 'marked\n'
		return
	fi

	legacy_path="$(render_template_to_tmp_path_for_install_state "$source_path" "$(basename "$relative_destination").legacy" "$relative_destination" "$managed_files_markdown" "disabled")"
	if candidate_path_matches_destination "$destination_path" "$legacy_path"; then
		printf 'legacy\n'
		return
	fi

	legacy_identity_marked_path="$(render_template_to_legacy_identity_tmp_path_for_install_state "$source_path" "$(basename "$actual_relative_destination").legacy-identity.marked" "$actual_relative_destination" "$managed_files_markdown" "enabled")"
	if candidate_path_matches_destination "$destination_path" "$legacy_identity_marked_path"; then
		printf 'legacy\n'
		return
	fi

	legacy_identity_unmarked_path="$(render_template_to_legacy_identity_tmp_path_for_install_state "$source_path" "$(basename "$actual_relative_destination").legacy-identity.unmarked" "$actual_relative_destination" "$managed_files_markdown" "disabled")"
	if candidate_path_matches_destination "$destination_path" "$legacy_identity_unmarked_path"; then
		printf 'legacy\n'
		return
	fi

	if [[ "$current_install_uses_legacy_layout" -eq 1 ]]; then
		prerename_compat_marked_path="$(render_template_to_prerename_compat_tmp_path_for_install_state "$(basename "$actual_relative_destination").prerename-compat.marked" "$actual_relative_destination" "$managed_files_markdown" "enabled")"
		if candidate_path_matches_destination "$destination_path" "$prerename_compat_marked_path"; then
			printf 'legacy\n'
			return
		fi

		prerename_compat_unmarked_path="$(render_template_to_prerename_compat_tmp_path_for_install_state "$(basename "$actual_relative_destination").prerename-compat.unmarked" "$actual_relative_destination" "$managed_files_markdown" "disabled")"
		if candidate_path_matches_destination "$destination_path" "$prerename_compat_unmarked_path"; then
			printf 'legacy\n'
			return
		fi
	fi

	if [[ "$relative_destination" == "$sidecar_destination" ]]; then
		if [[ -n "$owner_specific_guidance_markdown" ]]; then
			alternate_marked_path="$(render_template_to_tmp_path_for_install_state "$source_path" "$(basename "$relative_destination").marked.no-owner-guidance" "$relative_destination" "$managed_files_markdown" "enabled" "")"
			if candidate_path_matches_destination "$destination_path" "$alternate_marked_path"; then
				printf 'marked\n'
				return
			fi

			alternate_legacy_path="$(render_template_to_tmp_path_for_install_state "$source_path" "$(basename "$relative_destination").legacy.no-owner-guidance" "$relative_destination" "$managed_files_markdown" "disabled" "")"
			if candidate_path_matches_destination "$destination_path" "$alternate_legacy_path"; then
				printf 'legacy\n'
				return
			fi

			alternate_marked_path="$(render_template_to_legacy_identity_tmp_path_for_install_state "$source_path" "$(basename "$actual_relative_destination").legacy-identity.marked.no-owner-guidance" "$actual_relative_destination" "$managed_files_markdown" "enabled" "")"
			if candidate_path_matches_destination "$destination_path" "$alternate_marked_path"; then
				printf 'legacy\n'
				return
			fi

			alternate_legacy_path="$(render_template_to_legacy_identity_tmp_path_for_install_state "$source_path" "$(basename "$actual_relative_destination").legacy-identity.unmarked.no-owner-guidance" "$actual_relative_destination" "$managed_files_markdown" "disabled" "")"
			if candidate_path_matches_destination "$destination_path" "$alternate_legacy_path"; then
				printf 'legacy\n'
				return
			fi

			if [[ "$current_install_uses_legacy_layout" -eq 1 ]]; then
				alternate_marked_path="$(render_template_to_prerename_compat_tmp_path_for_install_state "$(basename "$actual_relative_destination").prerename-compat.marked.no-owner-guidance" "$actual_relative_destination" "$managed_files_markdown" "enabled" "")"
				if candidate_path_matches_destination "$destination_path" "$alternate_marked_path"; then
					printf 'legacy\n'
					return
				fi

				alternate_legacy_path="$(render_template_to_prerename_compat_tmp_path_for_install_state "$(basename "$actual_relative_destination").prerename-compat.unmarked.no-owner-guidance" "$actual_relative_destination" "$managed_files_markdown" "disabled" "")"
				if candidate_path_matches_destination "$destination_path" "$alternate_legacy_path"; then
					printf 'legacy\n'
					return
				fi
			fi
		fi

		actual_owner_specific_guidance_owner="$(extract_sidecar_owner_specific_guidance_owner "$destination_path")"
		if [[ -n "$actual_owner_specific_guidance_owner" && "$actual_owner_specific_guidance_owner" != "$downstream_repo_owner" ]]; then
			alternate_marked_path="$(render_template_to_tmp_path_for_install_state "$source_path" "$(basename "$relative_destination").marked.owner-guidance-compat" "$relative_destination" "$managed_files_markdown" "enabled" "$actual_owner_specific_guidance_owner")"
			if candidate_path_matches_destination "$destination_path" "$alternate_marked_path"; then
				printf 'marked\n'
				return
			fi

			alternate_legacy_path="$(render_template_to_tmp_path_for_install_state "$source_path" "$(basename "$relative_destination").legacy.owner-guidance-compat" "$relative_destination" "$managed_files_markdown" "disabled" "$actual_owner_specific_guidance_owner")"
			if candidate_path_matches_destination "$destination_path" "$alternate_legacy_path"; then
				printf 'legacy\n'
				return
			fi

			alternate_marked_path="$(render_template_to_legacy_identity_tmp_path_for_install_state "$source_path" "$(basename "$actual_relative_destination").legacy-identity.marked.owner-guidance-compat" "$actual_relative_destination" "$managed_files_markdown" "enabled" "$actual_owner_specific_guidance_owner")"
			if candidate_path_matches_destination "$destination_path" "$alternate_marked_path"; then
				printf 'legacy\n'
				return
			fi

			alternate_legacy_path="$(render_template_to_legacy_identity_tmp_path_for_install_state "$source_path" "$(basename "$actual_relative_destination").legacy-identity.unmarked.owner-guidance-compat" "$actual_relative_destination" "$managed_files_markdown" "disabled" "$actual_owner_specific_guidance_owner")"
			if candidate_path_matches_destination "$destination_path" "$alternate_legacy_path"; then
				printf 'legacy\n'
				return
			fi

			if [[ "$current_install_uses_legacy_layout" -eq 1 ]]; then
				alternate_marked_path="$(render_template_to_prerename_compat_tmp_path_for_install_state "$(basename "$actual_relative_destination").prerename-compat.marked.owner-guidance-compat" "$actual_relative_destination" "$managed_files_markdown" "enabled" "$actual_owner_specific_guidance_owner")"
				if candidate_path_matches_destination "$destination_path" "$alternate_marked_path"; then
					printf 'legacy\n'
					return
				fi

				alternate_legacy_path="$(render_template_to_prerename_compat_tmp_path_for_install_state "$(basename "$actual_relative_destination").prerename-compat.unmarked.owner-guidance-compat" "$actual_relative_destination" "$managed_files_markdown" "disabled" "$actual_owner_specific_guidance_owner")"
				if candidate_path_matches_destination "$destination_path" "$alternate_legacy_path"; then
					printf 'legacy\n'
					return
				fi
			fi
		fi
	fi

	printf 'drifted\n'
}

append_drifted_installed_whole_file_paths() {
	local pair=""
	local source_path=""
	local relative_destination=""
	local state=""
	local managed_files_markdown=""

	managed_files_markdown="$(build_installed_managed_files_markdown)"

	while IFS= read -r pair; do
		IFS='|' read -r source_path relative_destination <<<"$pair"
		state="$(resolve_whole_file_managed_state "$source_path" "$relative_destination" "$managed_files_markdown")"
		if [[ "$state" == "drifted" ]]; then
			append_unique_blocking_path "$relative_destination"
		fi
	done < <(build_whole_file_managed_pairs_for_mode "${current_auto_update:-$auto_update_mode}")
}

remove_clean_installed_whole_file() {
	local source_path="$1"
	local relative_destination="$2"
	local managed_files_markdown="${3:-}"
	local destination_path="${repo_root}/${relative_destination}"
	local state=""

	state="$(resolve_whole_file_managed_state "$source_path" "$relative_destination" "$managed_files_markdown")"

	case "$state" in
	marked | legacy)
		rm -f "$destination_path"
		note "Removed ${relative_destination}"
		;;
	drifted)
		note "Skipped ${relative_destination} because it has downstream edits"
		;;
	esac
}

sync_auto_update_files() {
	if [[ "$auto_update_mode" == "enabled" ]]; then
		write_rendered_file "$auto_update_script_source" "$auto_update_script_destination"
		write_rendered_file "$auto_update_workflow_source" "$auto_update_workflow_destination"
		return
	fi

	if [[ "$current_auto_update" == "enabled" ]]; then
		remove_auto_update_files
	fi
}

write_or_update_readme_file() {
	local destination_path="${repo_root}/${readme_destination}"
	local current_state=""
	local rendered_block_path=""
	local base_path=""
	local updated_path=""
	local trimmed_path=""
	local normalized_path=""
	local remove_insertion_zone_legacy=0

	current_state="$(resolve_readme_badge_state)"

	if [[ "$readme_has_managed_badges" -eq 1 ]]; then
		remove_insertion_zone_legacy=1
	fi

	if [[ "$readme_has_managed_badges" -ne 1 ]]; then
		if [[ -f "$destination_path" ]]; then
			ensure_tmp_dir
			normalized_path="${tmp_dir}/README.normalized"
			trimmed_path="${tmp_dir}/README.normalized.trimmed"

			if [[ "$current_state" == "present" ]]; then
				updated_path="${tmp_dir}/README.unmanaged"
				remove_readme_badges_block "$destination_path" "$updated_path"
				normalize_legacy_bright_builds_readme_badges "$updated_path" "$normalized_path" 0
			else
				normalize_legacy_bright_builds_readme_badges "$destination_path" "$normalized_path" 0
			fi

			trim_trailing_blank_lines "$normalized_path" "$trimmed_path"

			if ! cmp -s "$destination_path" "$trimmed_path"; then
				if file_has_non_whitespace "$trimmed_path"; then
					cp "$trimmed_path" "$destination_path"
					note "Updated ${readme_destination}"
				else
					rm -f "$destination_path"
					note "Removed ${readme_destination}"
				fi
			fi
		fi

		if [[ "$current_state" == "present" ]]; then
			current_state="absent"
		fi

		readme_badge_state="$(resolve_readme_badge_state)"
		return
	fi

	rendered_block_path="$(render_readme_badges_block_to_tmp_path)"

	if [[ ! -f "$destination_path" ]] || ! file_has_non_whitespace "$destination_path"; then
		ensure_tmp_dir
		updated_path="${tmp_dir}/README.generated"
		{
			build_readme_title
			printf '\n'
			cat "$rendered_block_path"
		} >"$updated_path"
		cp "$updated_path" "$destination_path"
		note "Wrote ${readme_destination}"
		readme_badge_state="$(resolve_readme_badge_state)"
		return
	fi

	case "$current_state" in
	partial | ambiguous)
		die "${readme_destination} contains conflicting badge content. Re-run install --force to back up and repair it."
		;;
	esac

	ensure_tmp_dir
	base_path="${tmp_dir}/README.base"
	updated_path="${tmp_dir}/README.updated"
	trimmed_path="${tmp_dir}/README.updated.trimmed"

	if [[ "$current_state" == "present" ]]; then
		remove_readme_badges_block "$destination_path" "$base_path"
	else
		cp "$destination_path" "$base_path"
	fi

	normalize_legacy_bright_builds_readme_badges "$base_path" "$updated_path" "$remove_insertion_zone_legacy"
	cp "$updated_path" "$base_path"

	insert_readme_badges_block "$base_path" "$updated_path" "$rendered_block_path"
	trim_trailing_blank_lines "$updated_path" "$trimmed_path"
	cp "$trimmed_path" "$destination_path"
	note "Updated ${readme_destination}"
	readme_badge_state="$(resolve_readme_badge_state)"
}

repair_blocking_readme_file() {
	local destination_path="${repo_root}/${readme_destination}"
	local markers_removed_path=""
	local sanitized_path=""
	local trimmed_path=""

	[[ -f "$destination_path" ]] || return

	ensure_tmp_dir
	markers_removed_path="${tmp_dir}/README.markers-removed"
	sanitized_path="${tmp_dir}/README.sanitized"
	trimmed_path="${tmp_dir}/README.sanitized.trimmed"

	remove_readme_badge_markers "$destination_path" "$markers_removed_path"
	strip_readme_badge_region "$markers_removed_path" "$sanitized_path"
	trim_trailing_blank_lines "$sanitized_path" "$trimmed_path"

	if file_has_non_whitespace "$trimmed_path"; then
		cp "$trimmed_path" "$destination_path"
		note "Sanitized conflicting ${readme_destination} badge region"
	else
		rm -f "$destination_path"
		note "Removed conflicting ${readme_destination}"
	fi

	readme_badge_state="$(resolve_readme_badge_state)"
}

write_audit_manifest() {
	local operation="$1"

	last_operation="$operation"
	last_updated_utc="$(utc_now)"
	write_rendered_file "$audit_source" "$audit_destination" "$(build_current_managed_files_markdown)"
}

remove_legacy_audit_manifest_if_migrated() {
	local legacy_audit_path="${repo_root}/${legacy_audit_destination}"

	if [[ ! -f "$legacy_audit_path" || ! -f "${repo_root}/${audit_destination}" ]]; then
		return
	fi

	if [[ "${GITHUB_ACTIONS:-}" == "true" && "$current_audit_destination" == "$legacy_audit_destination" ]]; then
		return
	fi

	if [[ "$current_audit_destination" == "$legacy_audit_destination" || "$current_audit_destination" == "$audit_destination" ]]; then
		rm -f "$legacy_audit_path"
		note "Removed ${legacy_audit_destination}"
	fi
}

stage_legacy_audit_migration_for_github_actions() {
	if [[ "$current_audit_destination" != "$legacy_audit_destination" ]]; then
		return
	fi

	if [[ "${GITHUB_ACTIONS:-}" != "true" ]]; then
		return
	fi

	if ! command -v git >/dev/null 2>&1; then
		return
	fi

	if ! git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		return
	fi

	git -C "$repo_root" add -A -- "$audit_destination" "$legacy_audit_destination" >/dev/null 2>&1 || true
}

resolve_current_install_metadata() {
	current_source=""
	current_ref=""
	current_entrypoint=""
	current_exact_commit=""
	current_auto_update=""
	current_auto_update_reason=""
	current_last_operation=""
	current_last_updated_utc=""
	current_audit_destination=""
	current_install_uses_legacy_layout=0

	if [[ -f "${repo_root}/${audit_destination}" ]]; then
		current_audit_destination="$audit_destination"
	elif [[ -f "${repo_root}/${legacy_audit_destination}" ]]; then
		current_audit_destination="$legacy_audit_destination"
		current_install_uses_legacy_layout=1
	else
		return 0
	fi

	current_source="$(extract_markdown_value "${repo_root}/${current_audit_destination}" "Source repository")"
	current_ref="$(extract_markdown_value "${repo_root}/${current_audit_destination}" "Version pin")"
	current_exact_commit="$(extract_markdown_value "${repo_root}/${current_audit_destination}" "Exact commit")"
	current_entrypoint="$(extract_markdown_value "${repo_root}/${current_audit_destination}" "Canonical entrypoint")"
	current_auto_update="$(extract_markdown_value "${repo_root}/${current_audit_destination}" "Auto-update")"
	current_auto_update_reason="$(extract_markdown_value "${repo_root}/${current_audit_destination}" "Auto-update reason")"
	current_last_operation="$(extract_markdown_value "${repo_root}/${current_audit_destination}" "Last operation")"
	current_last_updated_utc="$(extract_markdown_value "${repo_root}/${current_audit_destination}" "Last updated (UTC)")"

	if is_legacy_source_repository_url "$current_source"; then
		current_install_uses_legacy_layout=1
	fi
}

determine_repo_state() {
	local agents_path="${repo_root}/${agents_destination}"
	local path=""
	local auto_update_path=""
	local installed_signal=0
	local effective_audit_destination=""

	repo_state=""
	recommended_action=""
	blocking_paths=()
	resolve_agents_block_state "$agents_path"
	readme_badge_state="$(resolve_readme_badge_state)"
	effective_audit_destination="$(resolve_effective_audit_destination)"

	if [[ "$agents_block_state" == "present" && -f "${repo_root}/${sidecar_destination}" ]]; then
		installed_signal=1
	fi

	if [[ "$agents_block_state" == "partial" ]]; then
		append_unique_blocking_path "$agents_destination"
	fi

	if [[ "$agents_block_state" == "present" && ! -f "${repo_root}/${sidecar_destination}" ]]; then
		append_unique_blocking_path "$agents_destination"
		append_unique_blocking_path "$sidecar_destination"
	fi

	if [[ "$agents_block_state" != "present" && -f "${repo_root}/${sidecar_destination}" ]]; then
		append_unique_blocking_path "$sidecar_destination"
	fi

	if [[ "$installed_signal" -eq 1 ]]; then
		append_drifted_installed_whole_file_paths
	fi

	if [[ "$installed_signal" -ne 1 ]]; then
		for path in "CONTRIBUTING.md" ".github/pull_request_template.md" "${effective_audit_destination}"; do
			if [[ -f "${repo_root}/${path}" ]]; then
				append_unique_blocking_path "$path"
			fi
		done

		if auto_update_files_are_relevant; then
			for auto_update_path in "${auto_update_script_destination}" "${auto_update_workflow_destination}"; do
				if [[ -f "${repo_root}/${auto_update_path}" ]]; then
					append_unique_blocking_path "$auto_update_path"
				fi
			done
		fi
	fi

	if [[ "$installed_signal" -eq 1 && "$auto_update_mode" == "enabled" && "$current_auto_update" != "enabled" ]]; then
		for auto_update_path in "${auto_update_script_destination}" "${auto_update_workflow_destination}"; do
			if [[ -f "${repo_root}/${auto_update_path}" ]]; then
				append_unique_blocking_path "$auto_update_path"
			fi
		done
	fi

	if [[ "$readme_badge_state" == "partial" || "$readme_badge_state" == "ambiguous" ]]; then
		append_unique_blocking_path "$readme_destination"
	fi

	if [[ "${#blocking_paths[@]}" -gt 0 ]]; then
		repo_state="blocked"
		recommended_action="install --force"
		return
	fi

	if [[ "$installed_signal" -eq 1 ]]; then
		repo_state="installed"
		recommended_action="update"
		return
	fi

	repo_state="installable"
	recommended_action="install"
}

backup_blocking_paths() {
	local backup_timestamp=""
	local relative_destination=""
	local source_path=""
	local backup_path=""

	[[ "${#blocking_paths[@]}" -gt 0 ]] || return

	backup_timestamp="$(date -u +"%Y%m%dT%H%M%SZ")"
	last_backup_relative_root="${backup_root}/${backup_timestamp}"

	for relative_destination in "${blocking_paths[@]-}"; do
		source_path="${repo_root}/${relative_destination}"
		backup_path="${repo_root}/${last_backup_relative_root}/${relative_destination}"
		mkdir -p "$(dirname "$backup_path")"
		if [[ -f "$source_path" ]]; then
			cp "$source_path" "$backup_path"
			note "Backed up ${relative_destination} -> ${last_backup_relative_root}/${relative_destination}"
		fi
	done
}

clear_blocking_paths() {
	local relative_destination=""
	local destination_path=""

	for relative_destination in "${blocking_paths[@]-}"; do
		destination_path="${repo_root}/${relative_destination}"

		if [[ "$relative_destination" == "$readme_destination" ]]; then
			repair_blocking_readme_file
			continue
		fi

		rm -f "$destination_path"
		note "Removed conflicting ${relative_destination}"
	done

	rmdir "${repo_root}/.github/workflows" 2>/dev/null || true
	rmdir "${repo_root}/.github" 2>/dev/null || true
}

install_or_update() {
	local operation="$1"
	local pair=""
	local source_path=""
	local relative_destination=""

	write_or_update_agents_file

	for pair in "${base_managed_pairs[@]}"; do
		IFS='|' read -r source_path relative_destination <<<"$pair"
		write_rendered_file "$source_path" "$relative_destination"
	done

	ensure_overrides_file
	write_or_update_readme_file
	sync_auto_update_files
	write_audit_manifest "$operation"
	remove_legacy_audit_manifest_if_migrated
	stage_legacy_audit_migration_for_github_actions
}

status() {
	local relative_destination=""
	local destination_path=""

	note "Target repository: ${repo_root}"
	note "Repo state: ${repo_state}"
	note "Recommended action: ${recommended_action}"
	note "AGENTS marker: ${agents_block_state}"
	note "README badge block: ${readme_badge_state}"
	note "Auto-update: ${auto_update_mode}"
	note "Auto-update reason: ${auto_update_reason}"

	if [[ -n "$readme_badge_blocking_reason" ]]; then
		note "README badge reason: ${readme_badge_blocking_reason}"
	fi

	if [[ "$repo_state" == "blocked" ]]; then
		note "Blocking paths: ${blocking_paths[*]}"
	fi

	while IFS= read -r relative_destination; do
		destination_path="${repo_root}/${relative_destination}"

		if [[ -f "$destination_path" ]]; then
			note "[present] ${relative_destination}"
		else
			note "[missing] ${relative_destination}"
		fi
	done < <(build_current_managed_status_paths)

	if [[ -n "$current_audit_destination" && -f "${repo_root}/${current_audit_destination}" ]]; then
		note "Audit trail: ${current_audit_destination}"
	elif [[ -f "${repo_root}/${audit_destination}" ]]; then
		note "Audit trail: ${audit_destination}"
	fi

	if [[ "$repo_state" == "installed" ]]; then
		if [[ -n "$current_source" ]]; then
			note "Pinned source: ${current_source}"
		fi

		if [[ -n "$current_ref" ]]; then
			note "Pinned ref: ${current_ref}"
		fi

		if [[ -n "$current_exact_commit" ]]; then
			note "Pinned commit: ${current_exact_commit}"
		fi
	fi
}

uninstall() {
	local destination_path="${repo_root}/${agents_destination}"
	local readme_path="${repo_root}/${readme_destination}"
	local updated_path=""
	local trimmed_path=""
	local state=""
	local readme_state=""
	local pair=""
	local source_path=""
	local relative_destination=""
	local managed_files_markdown=""

	resolve_agents_block_state "$destination_path"
	state="$agents_block_state"

	if [[ "$state" == "present" ]]; then
		ensure_tmp_dir
		updated_path="${tmp_dir}/AGENTS.unmanaged"
		trimmed_path="${tmp_dir}/AGENTS.trimmed"
		remove_managed_block "$destination_path" "$updated_path"
		trim_trailing_blank_lines "$updated_path" "$trimmed_path"

		if file_has_non_whitespace "$trimmed_path"; then
			cp "$trimmed_path" "$destination_path"
			note "Updated ${agents_destination}"
		else
			rm -f "$destination_path"
			note "Removed ${agents_destination}"
		fi
	elif [[ "$state" == "partial" ]]; then
		note "Skipped ${agents_destination} because the managed marker block is incomplete"
	fi

	resolve_readme_badges_block_state "$readme_path"
	readme_state="$compatible_marker_state"

	if [[ "$readme_state" == "present" ]]; then
		ensure_tmp_dir
		updated_path="${tmp_dir}/README.unmanaged"
		trimmed_path="${tmp_dir}/README.unmanaged.trimmed"
		remove_readme_badges_block "$readme_path" "$updated_path"
		trim_trailing_blank_lines "$updated_path" "$trimmed_path"

		if readme_is_generated_skeleton_after_removal "$trimmed_path" || ! file_has_non_whitespace "$trimmed_path"; then
			rm -f "$readme_path"
			note "Removed ${readme_destination}"
		else
			cp "$trimmed_path" "$readme_path"
			note "Updated ${readme_destination}"
		fi
	elif [[ "$readme_state" == "partial" ]]; then
		note "Skipped ${readme_destination} because the managed badge block is incomplete"
	fi

	managed_files_markdown="$(build_installed_managed_files_markdown)"

	if [[ "$current_auto_update" == "enabled" ]]; then
		while IFS= read -r pair; do
			IFS='|' read -r source_path relative_destination <<<"$pair"
			case "$relative_destination" in
			"${auto_update_script_destination}" | "${auto_update_workflow_destination}")
				remove_clean_installed_whole_file "$source_path" "$relative_destination" "$managed_files_markdown"
				;;
			esac
		done < <(build_whole_file_managed_pairs_for_mode "$current_auto_update")
	fi

	while IFS= read -r pair; do
		IFS='|' read -r source_path relative_destination <<<"$pair"
		case "$relative_destination" in
		"${auto_update_script_destination}" | "${auto_update_workflow_destination}")
			continue
			;;
		esac
		remove_clean_installed_whole_file "$source_path" "$relative_destination" "$managed_files_markdown"
	done < <(build_whole_file_managed_pairs_for_mode "disabled")

	rmdir "${repo_root}/.github/workflows" 2>/dev/null || true
	rmdir "${repo_root}/.github" 2>/dev/null || true
}

trap cleanup EXIT

resolve_local_source_root

command_name="${1:-}"

if [[ -z "$command_name" || "$command_name" == "-h" || "$command_name" == "--help" || "$command_name" == "help" ]]; then
	usage
	exit 0
fi

shift

while [[ $# -gt 0 ]]; do
	case "$1" in
	--ref)
		[[ $# -ge 2 ]] || die "missing value for --ref"
		ref="$2"
		ref_was_explicit=1
		shift 2
		;;
	--repo)
		[[ $# -ge 2 ]] || die "missing value for --repo"
		repo_slug="$2"
		repo_was_explicit=1
		shift 2
		;;
	--repo-root)
		[[ $# -ge 2 ]] || die "missing value for --repo-root"
		repo_root="$2"
		shift 2
		;;
	--auto-update)
		[[ $# -ge 2 ]] || die "missing value for --auto-update"
		auto_update_request="$2"
		auto_update_was_explicit=1
		shift 2
		;;
	--force)
		force=1
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		die "unknown option: $1"
		;;
	esac
done

[[ -d "$repo_root" ]] || die "repo root does not exist: $repo_root"
repo_root="$(cd "$repo_root" && pwd)"

resolve_current_install_metadata

if [[ "$repo_was_explicit" -eq 0 && -n "$current_source" ]] && ! is_legacy_source_repository_url "$current_source"; then
	maybe_repo_slug="$(extract_repo_slug_from_url "$current_source")"

	if [[ -n "$maybe_repo_slug" ]]; then
		repo_slug="$maybe_repo_slug"
	fi
fi

if [[ "$ref_was_explicit" -eq 0 && -n "$current_ref" ]]; then
	ref="$current_ref"
fi

if [[ -z "$repo_slug" ]]; then
	repo_slug="$default_repo_slug"
fi

if [[ -z "$ref" ]]; then
	ref="$default_ref"
fi

repo_url="https://github.com/${repo_slug}"
raw_base="https://raw.githubusercontent.com/${repo_slug}/${ref}"
standards_index_url="${repo_url}/blob/${ref}/standards/index.md"
resolve_exact_commit
resolve_downstream_badges
resolve_owner_specific_guidance
resolve_auto_update_state
determine_repo_state

case "$command_name" in
install)
	if [[ "$repo_state" == "blocked" && "$force" -ne 1 ]]; then
		die "repo has blocked upstream-managed paths: ${blocking_paths[*]}. Prefer fixing the managed source in bright-builds-rules via upstream PR or issue. Re-run install --force only when you explicitly want to back up and replace the downstream copies."
	fi

	if [[ "$repo_state" == "blocked" && "$force" -eq 1 ]]; then
		backup_blocking_paths
		clear_blocking_paths
	fi

	install_or_update "install"
	note "Pinned standards to ${repo_url} @ ${ref}"
	if [[ -n "$last_backup_relative_root" ]]; then
		note "Legacy backup: ${last_backup_relative_root}"
	fi
	note "Audit trail: ${audit_destination}"
	;;
update)
	if [[ "$repo_state" == "installable" ]]; then
		die "repo does not contain the managed AGENTS marker. Use install for a fresh adoption."
	fi

	if [[ "$repo_state" == "blocked" ]]; then
		die "repo has blocked upstream-managed paths: ${blocking_paths[*]}. Prefer fixing the managed source in bright-builds-rules via upstream PR or issue. Re-run install --force only when you explicitly want to back up and replace the downstream copies."
	fi

	install_or_update "update"
	note "Updated standards pin to ${repo_url} @ ${ref}"
	note "Audit trail: ${audit_destination}"
	;;
status)
	status
	;;
uninstall)
	uninstall
	if [[ -f "${repo_root}/${overrides_destination}" ]]; then
		note "Preserved ${overrides_destination}"
	fi
	;;
*)
	die "unknown command: ${command_name}"
	;;
esac
