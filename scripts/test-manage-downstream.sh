#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script_path="${repo_root}/scripts/manage-downstream.sh"
agents_block_begin="<!-- coding-and-architecture-requirements-managed:begin -->"
agents_block_end="<!-- coding-and-architecture-requirements-managed:end -->"
temp_root="$(mktemp -d "${TMPDIR:-/tmp}/coding-reqs-tests.XXXXXX")"
repo_exact_commit="$(git -C "${repo_root}" rev-parse HEAD)"
run_output=""
run_status=0

cleanup() {
  rm -rf "$temp_root"
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  local message="$3"

  if [[ "$actual" != "$expected" ]]; then
    fail "${message}: expected '${expected}', got '${actual}'"
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  if [[ "$haystack" != *"$needle"* ]]; then
    fail "${message}: missing '${needle}'"
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  if [[ "$haystack" == *"$needle"* ]]; then
    fail "${message}: unexpectedly found '${needle}'"
  fi
}

assert_file_exists() {
  local file_path="$1"

  [[ -f "$file_path" ]] || fail "expected file to exist: $file_path"
}

assert_file_missing() {
  local file_path="$1"

  [[ ! -f "$file_path" ]] || fail "expected file to be absent: $file_path"
}

assert_file_contains() {
  local file_path="$1"
  local needle="$2"
  local message="$3"

  grep -Fq "$needle" "$file_path" || fail "${message}: missing '${needle}' in ${file_path}"
}

assert_file_not_contains() {
  local file_path="$1"
  local needle="$2"
  local message="$3"

  if grep -Fq "$needle" "$file_path"; then
    fail "${message}: unexpectedly found '${needle}' in ${file_path}"
  fi
}

assert_exact_line_count() {
  local file_path="$1"
  local needle="$2"
  local expected_count="$3"
  local actual_count=""

  actual_count="$(awk -v needle="$needle" '$0 == needle { count++ } END { print count + 0 }' "$file_path")"
  assert_eq "$actual_count" "$expected_count" "unexpected marker count in ${file_path}"
}

assert_line_order() {
  local file_path="$1"
  local first="$2"
  local second="$3"
  local first_line=""
  local second_line=""

  first_line="$(awk -v pattern="$first" 'index($0, pattern) > 0 { print NR; exit }' "$file_path")"
  second_line="$(awk -v pattern="$second" 'index($0, pattern) > 0 { print NR; exit }' "$file_path")"

  [[ -n "$first_line" ]] || fail "missing '${first}' in ${file_path}"
  [[ -n "$second_line" ]] || fail "missing '${second}' in ${file_path}"

  if (( first_line >= second_line )); then
    fail "expected '${first}' to appear before '${second}' in ${file_path}"
  fi
}

create_repo() {
  local name="$1"
  local repo_path="${temp_root}/${name}"

  mkdir -p "$repo_path"
  printf '%s\n' "$repo_path"
}

write_file() {
  local file_path="$1"
  local content="$2"

  mkdir -p "$(dirname "$file_path")"
  printf '%s' "$content" > "$file_path"
}

run_manage() {
  local repo_path="$1"
  shift

  set +e
  run_output="$(bash "$script_path" "$@" --repo-root "$repo_path" 2>&1)"
  run_status=$?
  set -e
}

run_manage_with_script() {
  local installer_path="$1"
  local repo_path="$2"
  shift 2

  set +e
  run_output="$(bash "$installer_path" "$@" --repo-root "$repo_path" 2>&1)"
  run_status=$?
  set -e
}

run_manage_with_path_prefix() {
  local installer_path="$1"
  local repo_path="$2"
  local path_prefix="$3"
  shift 3

  set +e
  run_output="$(env PATH="${path_prefix}:$PATH" bash "$installer_path" "$@" --repo-root "$repo_path" 2>&1)"
  run_status=$?
  set -e
}

create_standalone_installer_bundle() {
  local name="$1"
  local bundle_root="${temp_root}/${name}-bundle"

  mkdir -p "${bundle_root}/scripts" "${bundle_root}/templates"
  cp "$script_path" "${bundle_root}/scripts/manage-downstream.sh"
  cp -R "${repo_root}/templates/." "${bundle_root}/templates/"
  printf '%s\n' "${bundle_root}/scripts/manage-downstream.sh"
}

test_fresh_install_and_reinstall() {
  local repo_path=""

  repo_path="$(create_repo fresh)"

  run_manage "$repo_path" status
  assert_eq "$run_status" "0" "fresh repo status should succeed"
  assert_contains "$run_output" "Repo state: installable" "fresh repo should be installable"
  assert_contains "$run_output" "Recommended action: install" "fresh repo should recommend install"

  run_manage "$repo_path" install
  assert_eq "$run_status" "0" "fresh install should succeed"

  assert_file_exists "${repo_path}/AGENTS.md"
  assert_file_exists "${repo_path}/AGENTS.bright-builds.md"
  assert_file_exists "${repo_path}/CONTRIBUTING.md"
  assert_file_exists "${repo_path}/.github/pull_request_template.md"
  assert_file_exists "${repo_path}/coding-and-architecture-requirements.audit.md"
  assert_file_exists "${repo_path}/standards-overrides.md"

  assert_file_contains "${repo_path}/AGENTS.md" "Study \`AGENTS.bright-builds.md\`" "root AGENTS should point to the sidecar"
  assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "Do not edit this file directly." "sidecar should contain the managed warning"
  assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "installed from \`https://github.com/bright-builds-llc/coding-and-architecture-requirements\`" "sidecar should name the canonical source"
  assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "Exact commit: \`${repo_exact_commit}\`" "sidecar should record the exact local commit"
  assert_file_contains "${repo_path}/coding-and-architecture-requirements.audit.md" "Exact commit: \`${repo_exact_commit}\`" "audit trail should record the exact local commit"

  run_manage "$repo_path" install
  assert_eq "$run_status" "0" "reinstall should be safe"
  assert_exact_line_count "${repo_path}/AGENTS.md" "$agents_block_begin" "1"
  assert_exact_line_count "${repo_path}/AGENTS.md" "$agents_block_end" "1"

  run_manage "$repo_path" status
  assert_eq "$run_status" "0" "installed repo status should succeed"
  assert_contains "$run_output" "Repo state: installed" "installed repo should be detected"
  assert_contains "$run_output" "Recommended action: update" "installed repo should recommend update"
  assert_contains "$run_output" "Pinned commit: ${repo_exact_commit}" "installed repo status should show the exact commit"
}

test_existing_agents_is_installable() {
  local repo_path=""

  repo_path="$(create_repo existing-agents)"
  write_file "${repo_path}/AGENTS.md" $'# Local AGENTS\n\n- Keep this instruction.\n'

  run_manage "$repo_path" status
  assert_eq "$run_status" "0" "existing AGENTS status should succeed"
  assert_contains "$run_output" "Repo state: installable" "existing AGENTS alone should still be installable"

  run_manage "$repo_path" install
  assert_eq "$run_status" "0" "install should append to an existing AGENTS.md"
  assert_file_contains "${repo_path}/AGENTS.md" "Keep this instruction." "local AGENTS content should remain"
  assert_exact_line_count "${repo_path}/AGENTS.md" "$agents_block_begin" "1"
  assert_exact_line_count "${repo_path}/AGENTS.md" "$agents_block_end" "1"
  assert_line_order "${repo_path}/AGENTS.md" "Keep this instruction." "$agents_block_begin"
}

test_blocked_conflicts_and_force_install() {
  local repo_path=""
  local backup_file=""

  repo_path="$(create_repo blocked-force)"
  write_file "${repo_path}/AGENTS.md" $'# Local AGENTS\n'
  write_file "${repo_path}/CONTRIBUTING.md" $'# Local CONTRIBUTING\n'

  run_manage "$repo_path" status
  assert_eq "$run_status" "0" "blocked repo status should succeed"
  assert_contains "$run_output" "Repo state: blocked" "repo with conflicting managed files should be blocked"
  assert_contains "$run_output" "Recommended action: install --force" "blocked repo should recommend force install"
  assert_contains "$run_output" "Blocking paths: CONTRIBUTING.md" "blocked repo should list the managed conflict"

  run_manage "$repo_path" install
  assert_eq "$run_status" "1" "install should fail for blocked repos"

  run_manage "$repo_path" install --force
  assert_eq "$run_status" "0" "force install should succeed"
  assert_contains "$run_output" "Legacy backup: .coding-and-architecture-requirements-backups/" "force install should report the backup root"

  backup_file="$(find "${repo_path}/.coding-and-architecture-requirements-backups" -type f -name 'CONTRIBUTING.md' | head -n 1)"
  [[ -n "$backup_file" ]] || fail "expected force install to back up CONTRIBUTING.md"

  assert_file_contains "${repo_path}/AGENTS.md" "# Local AGENTS" "force install should preserve an unmarked AGENTS.md"
  assert_exact_line_count "${repo_path}/AGENTS.md" "$agents_block_begin" "1"
  assert_file_contains "${repo_path}/CONTRIBUTING.md" "# CONTRIBUTING.md" "force install should replace CONTRIBUTING.md with the managed template"
}

test_update_preserves_local_agents_and_overrides() {
  local repo_path=""

  repo_path="$(create_repo update)"
  write_file "${repo_path}/AGENTS.md" $'# Local AGENTS\n\n- Preserve this.\n'

  run_manage "$repo_path" install
  assert_eq "$run_status" "0" "initial install should succeed before update"

  printf '\n| `custom` | `keep it` | `local` | `owner` | `2026-03-13` |\n' >> "${repo_path}/standards-overrides.md"

  run_manage "$repo_path" update --ref integration-test-ref
  assert_eq "$run_status" "0" "update should succeed for the marker-based layout"
  assert_file_contains "${repo_path}/AGENTS.md" "Preserve this." "update should keep local AGENTS content"
  assert_line_order "${repo_path}/AGENTS.md" "Preserve this." "$agents_block_begin"
  assert_exact_line_count "${repo_path}/AGENTS.md" "$agents_block_begin" "1"
  assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "Version pin: \`integration-test-ref\`" "update should refresh managed files"
  assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "Exact commit: \`${repo_exact_commit}\`" "update should preserve exact local provenance"
  assert_file_contains "${repo_path}/standards-overrides.md" "| \`custom\` | \`keep it\` | \`local\` | \`owner\` | \`2026-03-13\` |" "update should preserve local overrides"
}

test_old_standalone_install_is_blocked() {
  local repo_path=""

  repo_path="$(create_repo old-standalone)"
  write_file "${repo_path}/AGENTS.md" $'# AGENTS.md\n\nUse this file as the thin local adoption layer in a downstream repository.\n'
  write_file "${repo_path}/CONTRIBUTING.md" $'# CONTRIBUTING.md\n'
  write_file "${repo_path}/.github/pull_request_template.md" $'# Pull Request Template\n'
  write_file "${repo_path}/coding-and-architecture-requirements.audit.md" $'# Audit Trail\n'

  run_manage "$repo_path" status
  assert_eq "$run_status" "0" "old standalone layout status should succeed"
  assert_contains "$run_output" "Repo state: blocked" "old standalone layout should be blocked"
  assert_not_contains "$run_output" "Repo state: installed" "old standalone layout must not be treated as installed"
}

test_uninstall_preserves_local_agents_and_overrides() {
  local repo_path=""

  repo_path="$(create_repo uninstall-preserve)"
  write_file "${repo_path}/AGENTS.md" $'# Local AGENTS\n\n- Keep me.\n'

  run_manage "$repo_path" install
  assert_eq "$run_status" "0" "install should succeed before uninstall"
  printf '\n| `custom` | `still here` | `local` | `owner` | `2026-03-13` |\n' >> "${repo_path}/standards-overrides.md"

  run_manage "$repo_path" uninstall
  assert_eq "$run_status" "0" "uninstall should succeed"
  assert_file_exists "${repo_path}/AGENTS.md"
  assert_file_contains "${repo_path}/AGENTS.md" "Keep me." "uninstall should keep local AGENTS content"
  assert_file_not_contains "${repo_path}/AGENTS.md" "$agents_block_begin" "uninstall should remove the managed AGENTS block"
  assert_file_missing "${repo_path}/AGENTS.bright-builds.md"
  assert_file_missing "${repo_path}/CONTRIBUTING.md"
  assert_file_missing "${repo_path}/.github/pull_request_template.md"
  assert_file_missing "${repo_path}/coding-and-architecture-requirements.audit.md"
  assert_file_exists "${repo_path}/standards-overrides.md"
  assert_file_contains "${repo_path}/standards-overrides.md" "| \`custom\` | \`still here\` | \`local\` | \`owner\` | \`2026-03-13\` |" "uninstall should preserve overrides"
}

test_uninstall_removes_agents_when_only_managed_block_remains() {
  local repo_path=""

  repo_path="$(create_repo uninstall-clean)"

  run_manage "$repo_path" install
  assert_eq "$run_status" "0" "install should succeed before clean uninstall"

  run_manage "$repo_path" uninstall
  assert_eq "$run_status" "0" "clean uninstall should succeed"
  assert_file_missing "${repo_path}/AGENTS.md"
  assert_file_exists "${repo_path}/standards-overrides.md"
}

test_explicit_full_sha_ref_sets_exact_commit() {
  local repo_path=""
  local installer_path=""
  local explicit_sha="1234567890abcdef1234567890abcdef12345678"

  repo_path="$(create_repo explicit-sha)"
  installer_path="$(create_standalone_installer_bundle explicit-sha)"

  run_manage_with_script "$installer_path" "$repo_path" install --ref "$explicit_sha"
  assert_eq "$run_status" "0" "install with an explicit full SHA should succeed"
  assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "Version pin: \`${explicit_sha}\`" "sidecar should keep the requested SHA as the version pin"
  assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "Exact commit: \`${explicit_sha}\`" "sidecar should use the explicit SHA as the exact commit"
  assert_file_contains "${repo_path}/coding-and-architecture-requirements.audit.md" "Exact commit: \`${explicit_sha}\`" "audit trail should use the explicit SHA as the exact commit"

  run_manage_with_script "$installer_path" "$repo_path" status
  assert_eq "$run_status" "0" "status should succeed after explicit SHA install"
  assert_contains "$run_output" "Pinned commit: ${explicit_sha}" "status should report the explicit exact commit"
}

test_unavailable_exact_commit_does_not_block_install() {
  local repo_path=""
  local installer_path=""
  local fake_bin=""

  repo_path="$(create_repo unavailable-commit)"
  installer_path="$(create_standalone_installer_bundle unavailable-commit)"
  fake_bin="${temp_root}/fake-bin"
  mkdir -p "$fake_bin"
  write_file "${fake_bin}/git" $'#!/usr/bin/env bash\nexit 1\n'
  chmod +x "${fake_bin}/git"

  run_manage_with_path_prefix "$installer_path" "$repo_path" "$fake_bin" install --ref branch-without-resolution
  assert_eq "$run_status" "0" "install should still succeed when exact commit resolution is unavailable"
  assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "Exact commit: \`Unavailable\`" "sidecar should record unavailable exact-commit provenance"
  assert_file_contains "${repo_path}/coding-and-architecture-requirements.audit.md" "Exact commit: \`Unavailable\`" "audit trail should record unavailable exact-commit provenance"

  run_manage_with_path_prefix "$installer_path" "$repo_path" "$fake_bin" status
  assert_eq "$run_status" "0" "status should still succeed when exact commit is unavailable"
  assert_contains "$run_output" "Pinned commit: Unavailable" "status should surface unavailable exact-commit provenance"
}

trap cleanup EXIT

test_fresh_install_and_reinstall
test_existing_agents_is_installable
test_blocked_conflicts_and_force_install
test_update_preserves_local_agents_and_overrides
test_old_standalone_install_is_blocked
test_uninstall_preserves_local_agents_and_overrides
test_uninstall_removes_agents_when_only_managed_block_remains
test_explicit_full_sha_ref_sets_exact_commit
test_unavailable_exact_commit_does_not_block_install

printf 'All manage-downstream integration tests passed.\n'
