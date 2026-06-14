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
contributing_block_source="templates/CONTRIBUTING.md"
contributing_destination="CONTRIBUTING.md"
current_contributing_whole_file_compat_source="templates/compat/pre-contributing-block/CONTRIBUTING.md"
audit_source="templates/bright-builds-rules.audit.md"
audit_destination="bright-builds-rules.audit.md"
legacy_audit_destination="coding-and-architecture-requirements.audit.md"
current_audit_whole_file_compat_source="templates/compat/pre-contributing-block/bright-builds-rules.audit.md"
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
contributing_block_begin="<!-- bright-builds-rules-contributing:begin -->"
contributing_block_end="<!-- bright-builds-rules-contributing:end -->"
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
	"templates/pull_request_template.md|.github/pull_request_template.md"
)
managed_standards_paths=(
	"standards/index.md"
	"standards/core/architecture.md"
	"standards/core/code-shape.md"
	"standards/core/local-guidance.md"
	"standards/core/operability.md"
	"standards/core/testing.md"
	"standards/core/verification.md"
	"standards/languages/rust.md"
	"standards/languages/typescript-javascript.md"
)
base_whole_file_managed_pairs=(
	"${sidecar_source}|${sidecar_destination}"
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
	"${contributing_destination} (managed block)"
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
contributing_block_state="absent"
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
legacy_auto_update_helper_needs_standards_staging=0

cleanup() {
	if [[ -n "$tmp_dir" && -d "$tmp_dir" ]]; then
		rm -rf "$tmp_dir"
	fi
}

resolve_local_source_root() {
	local maybe_script_path="${manager_entrypoint_path:-${BASH_SOURCE[0]-}}"
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
              a managed CONTRIBUTING block, PR template, local standards
              corpus, audit trail, and default README badge block when managed
              README badges apply, plus the managed auto-update workflow and
              helper script when auto-update resolves to enabled. Pre-existing
              unmarked AGENTS.md and CONTRIBUTING.md files are preserved and
              receive the managed block at the end. Blocked repos stop unless
              --force is passed.
  update      Refresh the managed AGENTS block, AGENTS.bright-builds.md, the
              managed CONTRIBUTING block, local standards corpus, other managed
              files, README badge block, audit trail, and managed auto-update
              files for repos already using the marker-based layout.
  status      Show which managed files are present, classify the repo state,
              print the recommended next action, and report README badge state
              plus the resolved auto-update mode and reason.
  uninstall   Remove the managed AGENTS block, AGENTS.bright-builds.md, the
              managed CONTRIBUTING block or legacy clean CONTRIBUTING file,
              the PR template, local standards corpus, audit trail, managed
              README badges, and managed auto-update files. Keeps
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
