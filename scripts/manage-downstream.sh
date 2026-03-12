#!/usr/bin/env bash
set -euo pipefail

default_repo_slug="bright-builds-llc/coding-and-architecture-requirements"
default_ref="main"

managed_pairs=(
  "templates/AGENTS.md|AGENTS.md"
  "templates/CONTRIBUTING.md|CONTRIBUTING.md"
  "templates/pull_request_template.md|.github/pull_request_template.md"
)
managed_paths=(
  "AGENTS.md"
  "CONTRIBUTING.md"
  ".github/pull_request_template.md"
  "standards-overrides.md"
  "coding-and-architecture-requirements.audit.md"
)
install_blocking_paths=(
  "AGENTS.md"
  "CONTRIBUTING.md"
  ".github/pull_request_template.md"
  "coding-and-architecture-requirements.audit.md"
)
default_uninstall_paths=(
  "AGENTS.md"
  "CONTRIBUTING.md"
  ".github/pull_request_template.md"
)

overrides_source="templates/standards-overrides.md"
overrides_destination="standards-overrides.md"
audit_source="templates/coding-and-architecture-requirements.audit.md"
audit_destination="coding-and-architecture-requirements.audit.md"
breadcrumb_begin="<!-- coding-and-architecture-requirements:begin -->"
breadcrumb_end="<!-- coding-and-architecture-requirements:end -->"
tmp_dir=""
script_dir=""
local_source_root=""
current_source=""
current_ref=""
current_entrypoint=""
repo_slug=""
repo_url=""
ref=""
repo_root="$(pwd)"
standards_index_url=""
raw_base=""
last_operation=""
last_updated_utc=""
force=0
remove_overrides=0
repo_was_explicit=0
ref_was_explicit=0

cleanup() {
  if [[ -n "$tmp_dir" && -d "$tmp_dir" ]]; then
    rm -rf "$tmp_dir"
  fi
}

usage() {
  cat <<'EOF'
Usage: manage-downstream.sh <install|update|status|uninstall> [options]

Commands:
  install     Use for a fresh downstream adoption. Writes the managed files
              and audit trail, and fails if managed files already exist unless
              --force is passed.
  update      Use when the downstream repo already appears adopted from this
              standards repo. Refreshes the managed files and audit trail.
  status      Show which managed files are present plus the detected source/ref
              from the audit manifest or AGENTS.md.
  uninstall   Remove AGENTS.md, CONTRIBUTING.md, and the PR template. Keeps
              standards-overrides.md and the audit manifest unless
              --remove-overrides is passed.

Options:
  --ref <git-ref>          Source ref to pin in downstream files. Defaults to
                           the current detected pin for update, otherwise main.
  --repo <owner/repo>      Source GitHub repository. Defaults to the current
                           AGENTS.md source for update, otherwise
                           bright-builds-llc/coding-and-architecture-requirements.
  --repo-root <path>       Target downstream repository root. Defaults to the
                           current directory.
  --force                  Overwrite conflicting managed files during install.
                           Do not use automatically for unclear conflicts.
  --remove-overrides       Also delete standards-overrides.md and
                           coding-and-architecture-requirements.audit.md
                           during uninstall.
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
    tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/coding-reqs.XXXXXX")"
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
  local repo_url="$1"

  printf '%s' "$repo_url" | sed -n 's#^https://github.com/\(.*\)$#\1#p' | sed 's#/$##'
}

render_breadcrumb_block() {
  cat <<EOF
${breadcrumb_begin}
<!-- source-repository: ${repo_url} -->
<!-- version-pin: ${ref} -->
<!-- canonical-entrypoint: ${standards_index_url} -->
<!-- audit-manifest: ${audit_destination} -->
${breadcrumb_end}
EOF
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

render_template_file() {
  local source_path="$1"
  local output_path="$2"
  local managed_files_markdown="${3:-}"
  local line=""

  {
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$line" == "REPLACE_WITH_MANAGED_FILES_LIST" ]]; then
        printf '%s\n' "$managed_files_markdown"
        continue
      fi

      line="${line//REPLACE_WITH_REPO_URL/$repo_url}"
      line="${line//REPLACE_WITH_TAG_OR_COMMIT/$ref}"
      line="${line//REPLACE_WITH_TAGGED_STANDARDS_INDEX_URL/$standards_index_url}"
      line="${line//REPLACE_WITH_AUDIT_MANIFEST_PATH/$audit_destination}"
      line="${line//REPLACE_WITH_LAST_OPERATION/$last_operation}"
      line="${line//REPLACE_WITH_LAST_UPDATED_UTC/$last_updated_utc}"
      printf '%s\n' "$line"
    done < "$source_path"
  } > "$output_path"
}

write_rendered_file() {
  local source_path="$1"
  local relative_destination="$2"
  local managed_files_markdown="${3:-}"
  local destination_path="${repo_root}/${relative_destination}"
  local downloaded_path=""
  local rendered_path=""

  ensure_tmp_dir
  downloaded_path="${tmp_dir}/$(basename "$source_path")"
  rendered_path="${tmp_dir}/$(basename "$source_path").rendered"
  download_file "$source_path" "$downloaded_path"
  render_template_file "$downloaded_path" "$rendered_path" "$managed_files_markdown"
  mkdir -p "$(dirname "$destination_path")"
  cp "$rendered_path" "$destination_path"
  note "Wrote ${relative_destination}"
}

file_has_breadcrumb_block() {
  local file_path="$1"

  grep -Fqx "$breadcrumb_begin" "$file_path" && grep -Fqx "$breadcrumb_end" "$file_path"
}

replace_breadcrumb_block() {
  local input_path="$1"
  local output_path="$2"
  local in_block=0
  local line=""

  {
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$line" == "$breadcrumb_begin" ]]; then
        render_breadcrumb_block
        in_block=1
        continue
      fi

      if [[ "$in_block" -eq 1 ]]; then
        if [[ "$line" == "$breadcrumb_end" ]]; then
          in_block=0
        fi
        continue
      fi

      printf '%s\n' "$line"
    done < "$input_path"
  } > "$output_path"
}

prepend_breadcrumb_block() {
  local input_path="$1"
  local output_path="$2"

  {
    render_breadcrumb_block
    printf '\n'
    cat "$input_path"
  } > "$output_path"
}

sync_overrides_file() {
  local destination_path="${repo_root}/${overrides_destination}"
  local updated_path=""

  if [[ ! -f "$destination_path" ]]; then
    write_rendered_file "$overrides_source" "$overrides_destination"
    return
  fi

  ensure_tmp_dir
  updated_path="${tmp_dir}/$(basename "$overrides_destination").updated"

  if file_has_breadcrumb_block "$destination_path"; then
    replace_breadcrumb_block "$destination_path" "$updated_path"
  else
    prepend_breadcrumb_block "$destination_path" "$updated_path"
  fi

  cp "$updated_path" "$destination_path"
  note "Updated ${overrides_destination}"
}

write_audit_manifest() {
  local operation="$1"
  shift

  last_operation="$operation"
  last_updated_utc="$(utc_now)"
  write_rendered_file "$audit_source" "$audit_destination" "$(build_managed_files_markdown "$@")"
}

resolve_current_install_metadata() {
  current_source=""
  current_ref=""
  current_entrypoint=""

  if [[ -f "${repo_root}/${audit_destination}" ]]; then
    current_source="$(extract_markdown_value "${repo_root}/${audit_destination}" "Source repository")"
    current_ref="$(extract_markdown_value "${repo_root}/${audit_destination}" "Version pin")"
    current_entrypoint="$(extract_markdown_value "${repo_root}/${audit_destination}" "Canonical entrypoint")"
  fi

  if [[ -f "${repo_root}/AGENTS.md" ]]; then
    if [[ -z "$current_source" ]]; then
      current_source="$(extract_markdown_value "${repo_root}/AGENTS.md" "Standards repository")"
    fi

    if [[ -z "$current_ref" ]]; then
      current_ref="$(extract_markdown_value "${repo_root}/AGENTS.md" "Version pin")"
    fi

    if [[ -z "$current_entrypoint" ]]; then
      current_entrypoint="$(extract_markdown_value "${repo_root}/AGENTS.md" "Canonical entrypoint")"
    fi
  fi
}

install_or_update() {
  local operation="$1"
  local pair=""
  local source_path=""
  local relative_destination=""

  for pair in "${managed_pairs[@]}"; do
    IFS='|' read -r source_path relative_destination <<< "$pair"
    write_rendered_file "$source_path" "$relative_destination"
  done

  sync_overrides_file
  write_audit_manifest "$operation" "${managed_paths[@]}"
}

status() {
  local relative_destination=""
  local display_source="$current_source"
  local display_ref="$current_ref"

  note "Target repository: ${repo_root}"

  for relative_destination in "${managed_paths[@]}"; do
    local destination_path=""

    destination_path="${repo_root}/${relative_destination}"

    if [[ -f "$destination_path" ]]; then
      note "[present] ${relative_destination}"
    else
      note "[missing] ${relative_destination}"
    fi
  done

  if [[ -z "$display_source" && -n "$repo_url" ]]; then
    display_source="$repo_url"
  fi

  if [[ -z "$display_ref" && -n "$ref" ]]; then
    display_ref="$ref"
  fi

  if [[ -n "$current_source" || -n "$current_ref" || -f "${repo_root}/${audit_destination}" || -f "${repo_root}/AGENTS.md" ]]; then
    if [[ -n "$display_source" ]]; then
      note "Pinned source: ${display_source}"
    fi

    if [[ -n "$display_ref" ]]; then
      note "Pinned ref: ${display_ref}"
    fi
  fi
}

uninstall() {
  local relative_destination=""
  local remaining_paths=()

  for relative_destination in "${default_uninstall_paths[@]}"; do
    local destination_path=""

    destination_path="${repo_root}/${relative_destination}"

    if [[ -f "$destination_path" ]]; then
      rm -f "$destination_path"
      note "Removed ${relative_destination}"
    fi
  done

  if [[ "$remove_overrides" -eq 1 ]]; then
    if [[ -f "${repo_root}/${overrides_destination}" ]]; then
      rm -f "${repo_root}/${overrides_destination}"
      note "Removed ${overrides_destination}"
    fi

    if [[ -f "${repo_root}/${audit_destination}" ]]; then
      rm -f "${repo_root}/${audit_destination}"
      note "Removed ${audit_destination}"
    fi
  else
    if [[ -f "${repo_root}/${overrides_destination}" ]]; then
      remaining_paths+=("${overrides_destination}")
    fi

    remaining_paths+=("${audit_destination}")
    write_audit_manifest "partial-uninstall" "${remaining_paths[@]}"
  fi

  rmdir "${repo_root}/.github" 2>/dev/null || true
}

trap cleanup EXIT

if script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"; then
  if [[ -f "${script_dir}/../templates/AGENTS.md" ]]; then
    local_source_root="$(cd "${script_dir}/.." && pwd)"
  fi
fi

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
    --force)
      force=1
      shift
      ;;
    --remove-overrides)
      remove_overrides=1
      shift
      ;;
    -h|--help)
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

if [[ "$repo_was_explicit" -eq 0 && -n "$current_source" ]]; then
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

case "$command_name" in
  install)
    existing_managed_files=()
    relative_destination=""

    for relative_destination in "${install_blocking_paths[@]}"; do
      if [[ -f "${repo_root}/${relative_destination}" ]]; then
        existing_managed_files+=("$relative_destination")
      fi
    done

    if [[ "${#existing_managed_files[@]}" -gt 0 && "$force" -ne 1 ]]; then
      die "managed files already exist: ${existing_managed_files[*]}. Re-run with --force or use update."
    fi

    install_or_update "install"
    note "Pinned canonical standards to ${repo_url} @ ${ref}"
    ;;
  update)
    install_or_update "update"
    note "Updated canonical standards pin to ${repo_url} @ ${ref}"
    ;;
  status)
    status
    ;;
  uninstall)
    uninstall
    ;;
  *)
    die "unknown command: ${command_name}"
    ;;
esac
