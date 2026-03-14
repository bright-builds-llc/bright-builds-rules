#!/usr/bin/env bash
set -euo pipefail

default_repo_slug="bright-builds-llc/coding-and-architecture-requirements"
default_ref="main"
backup_root=".coding-and-architecture-requirements-backups"

agents_block_source="templates/AGENTS.md"
agents_destination="AGENTS.md"
sidecar_source="templates/AGENTS.bright-builds.md"
sidecar_destination="AGENTS.bright-builds.md"
overrides_source="templates/standards-overrides.md"
overrides_destination="standards-overrides.md"
audit_source="templates/coding-and-architecture-requirements.audit.md"
audit_destination="coding-and-architecture-requirements.audit.md"
agents_block_begin="<!-- coding-and-architecture-requirements-managed:begin -->"
agents_block_end="<!-- coding-and-architecture-requirements-managed:end -->"

managed_pairs=(
  "${sidecar_source}|${sidecar_destination}"
  "templates/CONTRIBUTING.md|CONTRIBUTING.md"
  "templates/pull_request_template.md|.github/pull_request_template.md"
)
managed_status_paths=(
  "${agents_destination}"
  "${sidecar_destination}"
  "CONTRIBUTING.md"
  ".github/pull_request_template.md"
  "${audit_destination}"
  "${overrides_destination}"
)
managed_audit_entries=(
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
repo_state=""
recommended_action=""
repo_slug=""
repo_url=""
ref=""
repo_root="$(pwd)"
standards_index_url=""
raw_base=""
last_operation=""
last_updated_utc=""
last_backup_relative_root=""
force=0
repo_was_explicit=0
ref_was_explicit=0
agents_block_state="absent"
blocking_paths=()

cleanup() {
  if [[ -n "$tmp_dir" && -d "$tmp_dir" ]]; then
    rm -rf "$tmp_dir"
  fi
}

usage() {
  cat <<'EOF'
Usage: manage-downstream.sh <install|update|status|uninstall> [options]

Run `status` first to classify the repo as `installable`, `installed`, or
`blocked` before choosing an action.

Commands:
  install     Install the managed AGENTS block, AGENTS.bright-builds.md,
              CONTRIBUTING.md, PR template, and audit trail. A pre-existing
              unmarked AGENTS.md is preserved and receives the managed block at
              the end. Blocked repos stop unless --force is passed.
  update      Refresh the managed AGENTS block, AGENTS.bright-builds.md, the
              managed files, and the audit trail for repos already using the
              marker-based layout.
  status      Show which managed files are present, classify the repo state,
              and print the recommended next action.
  uninstall   Remove the managed AGENTS block, AGENTS.bright-builds.md,
              CONTRIBUTING.md, the PR template, and the audit trail. Keeps
              standards-overrides.md.

Options:
  --ref <git-ref>          Source ref to pin in downstream files. Defaults to
                           the current detected audit pin for update, otherwise
                           main.
  --repo <owner/repo>      Source GitHub repository. Defaults to the current
                           audit source for update, otherwise
                           bright-builds-llc/coding-and-architecture-requirements.
  --repo-root <path>       Target downstream repository root. Defaults to the
                           current directory.
  --force                  Back up and replace blocked managed files during
                           install. The backup is written to
                           .coding-and-architecture-requirements-backups/<UTC-timestamp>.
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
  local input_url="$1"

  printf '%s' "$input_url" | sed -n 's#^https://github.com/\(.*\)$#\1#p' | sed 's#/$##'
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
      line="${line//REPLACE_WITH_MANAGED_SIDECAR_PATH/$sidecar_destination}"
      printf '%s\n' "$line"
    done < "$source_path"
  } > "$output_path"
}

render_template_to_tmp_path() {
  local source_path="$1"
  local tmp_stem="$2"
  local managed_files_markdown="${3:-}"
  local downloaded_path=""
  local rendered_path=""

  ensure_tmp_dir
  downloaded_path="${tmp_dir}/${tmp_stem}.source"
  rendered_path="${tmp_dir}/${tmp_stem}.rendered"
  download_file "$source_path" "$downloaded_path"
  render_template_file "$downloaded_path" "$rendered_path" "$managed_files_markdown"
  printf '%s\n' "$rendered_path"
}

write_rendered_file() {
  local source_path="$1"
  local relative_destination="$2"
  local managed_files_markdown="${3:-}"
  local destination_path="${repo_root}/${relative_destination}"
  local rendered_path=""

  rendered_path="$(render_template_to_tmp_path "$source_path" "$(basename "$relative_destination")" "$managed_files_markdown")"
  mkdir -p "$(dirname "$destination_path")"
  cp "$rendered_path" "$destination_path"
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
  ' "$input_path" > "$output_path"
}

detect_agents_block_state() {
  local file_path="$1"

  if [[ ! -f "$file_path" ]]; then
    printf 'absent\n'
    return
  fi

  awk -v begin="$agents_block_begin" -v end="$agents_block_end" '
    $0 == begin {
      begin_count++
      if (begin_line == 0) {
        begin_line = NR
      }
    }

    $0 == end {
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

replace_managed_block() {
  local input_path="$1"
  local output_path="$2"
  local replacement_path="$3"

  awk -v begin="$agents_block_begin" -v end="$agents_block_end" -v replacement_path="$replacement_path" '
    BEGIN {
      while ((getline line < replacement_path) > 0) {
        replacement[++replacement_count] = line
      }
      close(replacement_path)
    }

    $0 == begin && in_block == 0 {
      for (i = 1; i <= replacement_count; i++) {
        print replacement[i]
      }
      in_block = 1
      replaced = 1
      next
    }

    in_block == 1 {
      if ($0 == end) {
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
  ' "$input_path" > "$output_path"
}

remove_managed_block() {
  local input_path="$1"
  local output_path="$2"

  awk -v begin="$agents_block_begin" -v end="$agents_block_end" '
    $0 == begin && in_block == 0 {
      in_block = 1
      removed = 1
      next
    }

    in_block == 1 {
      if ($0 == end) {
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
  ' "$input_path" > "$output_path"
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
  agents_block_state="$(detect_agents_block_state "$destination_path")"

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
        } > "$updated_path"
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

write_audit_manifest() {
  local operation="$1"

  last_operation="$operation"
  last_updated_utc="$(utc_now)"
  write_rendered_file "$audit_source" "$audit_destination" "$(build_managed_files_markdown "${managed_audit_entries[@]}")"
}

resolve_current_install_metadata() {
  current_source=""
  current_ref=""
  current_entrypoint=""

  if [[ ! -f "${repo_root}/${audit_destination}" ]]; then
    return
  fi

  current_source="$(extract_markdown_value "${repo_root}/${audit_destination}" "Source repository")"
  current_ref="$(extract_markdown_value "${repo_root}/${audit_destination}" "Version pin")"
  current_entrypoint="$(extract_markdown_value "${repo_root}/${audit_destination}" "Canonical entrypoint")"
}

determine_repo_state() {
  local agents_path="${repo_root}/${agents_destination}"
  local path=""

  repo_state=""
  recommended_action=""
  blocking_paths=()
  agents_block_state="$(detect_agents_block_state "$agents_path")"

  if [[ "$agents_block_state" == "present" && -f "${repo_root}/${sidecar_destination}" ]]; then
    repo_state="installed"
    recommended_action="update"
    return
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

  for path in "CONTRIBUTING.md" ".github/pull_request_template.md" "${audit_destination}"; do
    if [[ -f "${repo_root}/${path}" ]]; then
      append_unique_blocking_path "$path"
    fi
  done

  if [[ "${#blocking_paths[@]}" -gt 0 ]]; then
    repo_state="blocked"
    recommended_action="install --force"
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
    cp "$source_path" "$backup_path"
    note "Backed up ${relative_destination} -> ${last_backup_relative_root}/${relative_destination}"
  done
}

clear_blocking_paths() {
  local relative_destination=""
  local destination_path=""

  for relative_destination in "${blocking_paths[@]-}"; do
    destination_path="${repo_root}/${relative_destination}"
    rm -f "$destination_path"
    note "Removed conflicting ${relative_destination}"
  done

  rmdir "${repo_root}/.github" 2>/dev/null || true
}

install_or_update() {
  local operation="$1"
  local pair=""
  local source_path=""
  local relative_destination=""

  write_or_update_agents_file

  for pair in "${managed_pairs[@]}"; do
    IFS='|' read -r source_path relative_destination <<< "$pair"
    write_rendered_file "$source_path" "$relative_destination"
  done

  ensure_overrides_file
  write_audit_manifest "$operation"
}

status() {
  local relative_destination=""
  local destination_path=""

  note "Target repository: ${repo_root}"
  note "Repo state: ${repo_state}"
  note "Recommended action: ${recommended_action}"
  note "AGENTS marker: ${agents_block_state}"

  if [[ "$repo_state" == "blocked" ]]; then
    note "Blocking paths: ${blocking_paths[*]}"
  fi

  for relative_destination in "${managed_status_paths[@]}"; do
    destination_path="${repo_root}/${relative_destination}"

    if [[ -f "$destination_path" ]]; then
      note "[present] ${relative_destination}"
    else
      note "[missing] ${relative_destination}"
    fi
  done

  if [[ -f "${repo_root}/${audit_destination}" ]]; then
    note "Audit trail: ${audit_destination}"
  fi

  if [[ "$repo_state" == "installed" ]]; then
    if [[ -n "$current_source" ]]; then
      note "Pinned source: ${current_source}"
    fi

    if [[ -n "$current_ref" ]]; then
      note "Pinned ref: ${current_ref}"
    fi
  fi
}

uninstall() {
  local destination_path="${repo_root}/${agents_destination}"
  local updated_path=""
  local trimmed_path=""
  local state=""
  local relative_destination=""

  state="$(detect_agents_block_state "$destination_path")"

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

  for relative_destination in "${sidecar_destination}" "CONTRIBUTING.md" ".github/pull_request_template.md" "${audit_destination}"; do
    if [[ -f "${repo_root}/${relative_destination}" ]]; then
      rm -f "${repo_root}/${relative_destination}"
      note "Removed ${relative_destination}"
    fi
  done

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
determine_repo_state

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
    if [[ "$repo_state" == "blocked" && "$force" -ne 1 ]]; then
      die "repo has blocked managed-file paths: ${blocking_paths[*]}. Re-run install --force to back up and replace them."
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
      die "repo has blocked managed-file paths: ${blocking_paths[*]}. Re-run install --force to back up and replace them."
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
