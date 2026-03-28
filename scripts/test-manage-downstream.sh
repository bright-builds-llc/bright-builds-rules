#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script_path="${repo_root}/scripts/manage-downstream.sh"
agents_block_begin="<!-- coding-and-architecture-requirements-managed:begin -->"
agents_block_end="<!-- coding-and-architecture-requirements-managed:end -->"
readme_badges_begin="<!-- coding-and-architecture-requirements-readme-badges:begin -->"
readme_badges_end="<!-- coding-and-architecture-requirements-readme-badges:end -->"
temp_root="$(mktemp -d "${TMPDIR:-/tmp}/coding-reqs-tests.XXXXXX")"
repo_exact_commit="$(git -C "${repo_root}" rev-parse HEAD)"
default_fake_bin="${temp_root}/default-fake-bin"
run_output=""
run_status=0

cleanup() {
  rm -rf "$temp_root"
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

managed_file_marker() {
  local relative_destination="$1"

  case "$relative_destination" in
    *.md)
      printf '<!-- coding-and-architecture-requirements-managed-file: %s -->\n' "$relative_destination"
      ;;
    *.sh|*.yml|*.yaml)
      printf '# coding-and-architecture-requirements-managed-file: %s\n' "$relative_destination"
      ;;
    *)
      printf '# coding-and-architecture-requirements-managed-file: %s\n' "$relative_destination"
      ;;
  esac
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

assert_command_succeeds() {
  local message="$1"
  shift

  "$@" >/dev/null 2>&1 || fail "${message}: $*"
}

assert_line_equals() {
  local file_path="$1"
  local line_number="$2"
  local expected_line="$3"
  local message="$4"
  local actual_line=""

  actual_line="$(sed -n "${line_number}p" "$file_path")"
  if [[ "$actual_line" != "$expected_line" ]]; then
    fail "${message}: expected '${expected_line}' on line ${line_number} of ${file_path}, got '${actual_line}'"
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

strip_whole_file_managed_markers() {
  local repo_path="$1"
  local relative_destination=""
  local file_path=""
  local stripped_path=""

  for relative_destination in \
    "AGENTS.bright-builds.md" \
    "CONTRIBUTING.md" \
    ".github/pull_request_template.md" \
    "coding-and-architecture-requirements.audit.md" \
    "scripts/bright-builds-auto-update.sh" \
    ".github/workflows/bright-builds-auto-update.yml"; do
    file_path="${repo_path}/${relative_destination}"
    if [[ ! -f "$file_path" ]]; then
      continue
    fi

    stripped_path="${file_path}.stripped"
    awk '!/coding-and-architecture-requirements-managed-file:/' "$file_path" > "$stripped_path"
    mv "$stripped_path" "$file_path"
  done
}

disable_real_gh_by_default() {
  mkdir -p "$default_fake_bin"
  write_file "${default_fake_bin}/gh" $'#!/usr/bin/env bash\nexit 1\n'
  chmod +x "${default_fake_bin}/gh"
  unset GITHUB_ACTOR || true
  export PATH="${default_fake_bin}:$PATH"
}

init_git_repo_with_origin() {
  local repo_path="$1"
  local remote_url="$2"

  git -C "$repo_path" init >/dev/null 2>&1
  git -C "$repo_path" remote add origin "$remote_url"
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

run_manage_with_actor() {
  local repo_path="$1"
  local actor="$2"
  shift 2

  set +e
  run_output="$(env GITHUB_ACTOR="$actor" bash "$script_path" "$@" --repo-root "$repo_path" 2>&1)"
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
  assert_contains "$run_output" "README badge block: not applicable" "fresh repo should report README badges as not applicable"
  assert_contains "$run_output" "Auto-update: disabled" "fresh repo should default auto-update to disabled"
  assert_contains "$run_output" "Auto-update reason: default disabled" "fresh repo should explain the disabled auto-update default"

  run_manage "$repo_path" install
  assert_eq "$run_status" "0" "fresh install should succeed"

  assert_file_exists "${repo_path}/AGENTS.md"
  assert_file_exists "${repo_path}/AGENTS.bright-builds.md"
  assert_file_exists "${repo_path}/CONTRIBUTING.md"
  assert_file_exists "${repo_path}/.github/pull_request_template.md"
  assert_file_exists "${repo_path}/coding-and-architecture-requirements.audit.md"
  assert_file_exists "${repo_path}/standards-overrides.md"
  assert_file_missing "${repo_path}/README.md"
  assert_file_missing "${repo_path}/scripts/bright-builds-auto-update.sh"
  assert_file_missing "${repo_path}/.github/workflows/bright-builds-auto-update.yml"

  assert_file_contains "${repo_path}/AGENTS.md" "Study \`AGENTS.bright-builds.md\`" "root AGENTS should point to the sidecar"
  assert_file_contains "${repo_path}/AGENTS.md" "Maintain and study a \`## Repo-Local Guidance\` section elsewhere in this file" "root AGENTS should direct repos to keep local guidance in AGENTS"
  assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "Do not edit this file directly." "sidecar should contain the managed warning"
  assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "installed from \`https://github.com/bright-builds-llc/coding-and-architecture-requirements\`" "sidecar should name the canonical source"
  assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "Exact commit: \`${repo_exact_commit}\`" "sidecar should record the exact local commit"
  assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "$(managed_file_marker "AGENTS.bright-builds.md")" "sidecar should include the whole-file managed marker"
  assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "Record recurring repo-specific workflow facts in \`AGENTS.md\` under \`## Repo-Local Guidance\`" "sidecar should distinguish local guidance from standards overrides"
  assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "internal nullable or optional names with \`maybe\`" "sidecar should include the expanded maybe-prefix naming guidance"
  assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "copyable summary with the exact commit when available" "sidecar should include the UI provenance guidance"
  assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "foreign-language logic inside strings" "sidecar should include the no-foreign-code-in-strings guidance"
  assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "rerunnable when sensible" "sidecar should include the rerunnable script guidance"
  assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "repo-defined gitignored location" "sidecar should point scripts at a repo-defined gitignored log location"
  assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "Before substantive implementation work, fetch remote state first" "sidecar should include the pre-work checkout sync guidance"
  assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "prefer rebasing onto the latest upstream or the repo's equivalent sync path" "sidecar should require rebase-first sync wording"
  assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "if a worktree starts detached, assume the repo default branch, often \`main\`" "sidecar should include the detached-worktree default-branch hint"
  assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "resolve any sync conflicts before proceeding" "sidecar should require conflict resolution before work"
  assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "bootstrap or dependency-sync step when dependencies or tools may be stale" "sidecar should include dependency prep guidance"
  assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "Before committing, run the relevant repo-native verification steps for the changed paths, including Markdown or shell formatter checks when supported tools are already available and local guidance does not define a clearer workflow, and do not commit if they fail." "sidecar should include the pass-before-commit verification rule"
  assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "Prefer the repo's own verify/check/validate entrypoint when it exists" "sidecar should prefer repo-owned verification entrypoints"
  assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "If hook-managed verification is detected and local docs are silent, ask before duplicating it manually." "sidecar should include the hook-aware prompting rule"
  assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "especially any \`## Repo-Local Guidance\` section" "sidecar workflow should tell agents to read local guidance first"
  assert_file_not_contains "${repo_path}/AGENTS.bright-builds.md" "openlinks-identity-presence" "non-matching owners should not receive the OpenLinks identity guidance"
  assert_file_contains "${repo_path}/CONTRIBUTING.md" "internal nullable or optional names with \`maybe\`" "CONTRIBUTING should include the expanded maybe-prefix naming guidance"
  assert_file_contains "${repo_path}/CONTRIBUTING.md" "$(managed_file_marker "CONTRIBUTING.md")" "CONTRIBUTING should include the whole-file managed marker"
  assert_file_contains "${repo_path}/CONTRIBUTING.md" "foreign-language logic inside strings" "CONTRIBUTING should include the no-foreign-code-in-strings guidance"
  assert_file_contains "${repo_path}/CONTRIBUTING.md" "rerunnable when sensible" "CONTRIBUTING should include the rerunnable script guidance"
  assert_file_contains "${repo_path}/CONTRIBUTING.md" "breadcrumb-heavy logs and summaries" "CONTRIBUTING should require breadcrumb-heavy logs and summaries"
  assert_file_contains "${repo_path}/CONTRIBUTING.md" "Before substantive implementation work, fetch remote state first" "CONTRIBUTING should require pre-work checkout sync"
  assert_file_contains "${repo_path}/CONTRIBUTING.md" "prefer rebasing onto the latest upstream or the repo's equivalent sync path" "CONTRIBUTING should prefer rebase-first sync wording"
  assert_file_contains "${repo_path}/CONTRIBUTING.md" "if a worktree starts detached, assume the repo default branch, often \`main\`" "CONTRIBUTING should include the detached-worktree default-branch hint"
  assert_file_contains "${repo_path}/CONTRIBUTING.md" "resolve any sync conflicts before proceeding" "CONTRIBUTING should require conflict resolution before work"
  assert_file_contains "${repo_path}/CONTRIBUTING.md" "bootstrap or dependency-sync step when dependencies or tools may be stale" "CONTRIBUTING should include dependency prep guidance"
  assert_file_contains "${repo_path}/CONTRIBUTING.md" "Before committing, run the relevant repo-native verification steps for the changed paths, including Markdown or shell formatter checks when supported tools are already available and local guidance does not define a clearer workflow, and do not commit if they fail." "CONTRIBUTING should require pass-before-commit verification"
  assert_file_contains "${repo_path}/CONTRIBUTING.md" "Heavy integration, end-to-end, or external-service suites may stay pre-push or CI-only" "CONTRIBUTING should allow documented CI-only heavy suites"
  assert_file_contains "${repo_path}/.github/pull_request_template.md" "Relevant repo-native verification ran and passed when applicable" "PR template should use flexible verification wording"
  assert_file_contains "${repo_path}/.github/pull_request_template.md" "$(managed_file_marker ".github/pull_request_template.md")" "PR template should include the whole-file managed marker"
  assert_file_contains "${repo_path}/.github/pull_request_template.md" "Any CI-only or hook-owned verification exception is documented" "PR template should capture verification exceptions"
  assert_file_contains "${repo_path}/standards-overrides.md" "hook-owned or leaves heavy suites to CI" "overrides template should mention verification exceptions"
  assert_file_contains "${repo_path}/coding-and-architecture-requirements.audit.md" "Exact commit: \`${repo_exact_commit}\`" "audit trail should record the exact local commit"
  assert_file_contains "${repo_path}/coding-and-architecture-requirements.audit.md" "Auto-update: \`disabled\`" "audit trail should record the disabled auto-update setting"
  assert_file_contains "${repo_path}/coding-and-architecture-requirements.audit.md" "Auto-update reason: \`default disabled\`" "audit trail should record why auto-update stayed disabled"
  assert_file_contains "${repo_path}/coding-and-architecture-requirements.audit.md" "$(managed_file_marker "coding-and-architecture-requirements.audit.md")" "audit trail should include the whole-file managed marker"

  run_manage "$repo_path" install
  assert_eq "$run_status" "0" "reinstall should be safe"
  assert_exact_line_count "${repo_path}/AGENTS.md" "$agents_block_begin" "1"
  assert_exact_line_count "${repo_path}/AGENTS.md" "$agents_block_end" "1"

  run_manage "$repo_path" status
  assert_eq "$run_status" "0" "installed repo status should succeed"
  assert_contains "$run_output" "Repo state: installed" "installed repo should be detected"
  assert_contains "$run_output" "Recommended action: update" "installed repo should recommend update"
  assert_contains "$run_output" "Pinned commit: ${repo_exact_commit}" "installed repo status should show the exact commit"
  assert_contains "$run_output" "README badge block: not applicable" "installed repo should keep README badge state not applicable when no badges are verified"
  assert_contains "$run_output" "Auto-update: disabled" "installed repo should keep auto-update disabled"
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

test_trusted_repo_owner_enables_auto_update_by_default() {
  local repo_path=""

  repo_path="$(create_repo trusted-owner)"
  init_git_repo_with_origin "$repo_path" "git@github.com:pRizz/trusted-owner.git"

  run_manage "$repo_path" status
  assert_eq "$run_status" "0" "trusted-owner status should succeed"
  assert_contains "$run_output" "Auto-update: enabled" "trusted repo owners should default auto-update to enabled"
  assert_contains "$run_output" "Auto-update reason: trusted repo owner pRizz" "status should report the trusted repo owner"

  run_manage "$repo_path" install
  assert_eq "$run_status" "0" "trusted-owner install should succeed"
  assert_file_exists "${repo_path}/scripts/bright-builds-auto-update.sh"
  assert_file_exists "${repo_path}/.github/workflows/bright-builds-auto-update.yml"
  assert_file_contains "${repo_path}/coding-and-architecture-requirements.audit.md" "Auto-update: \`enabled\`" "audit should record enabled auto-update"
  assert_file_contains "${repo_path}/coding-and-architecture-requirements.audit.md" "Auto-update reason: \`trusted repo owner pRizz\`" "audit should record the repo-owner trust decision"
  assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "use the \`openlinks-identity-presence\` skill whenever the task touches README/docs" "matching owners should receive the OpenLinks identity guidance"
  assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "repo owner resolves to \`pRizz\`" "sidecar should explain why the OpenLinks guidance applies"
  assert_line_equals "${repo_path}/scripts/bright-builds-auto-update.sh" "1" "#!/usr/bin/env bash" "auto-update helper should keep the shebang on line 1"
  assert_line_equals "${repo_path}/scripts/bright-builds-auto-update.sh" "2" "$(managed_file_marker "scripts/bright-builds-auto-update.sh")" "auto-update helper should put the whole-file marker on line 2"
  assert_command_succeeds "installed auto-update helper should pass bash -n" bash -n "${repo_path}/scripts/bright-builds-auto-update.sh"
  assert_command_succeeds "installed auto-update helper should be shfmt-clean" shfmt -d "${repo_path}/scripts/bright-builds-auto-update.sh"
  assert_line_equals "${repo_path}/.github/workflows/bright-builds-auto-update.yml" "1" "$(managed_file_marker ".github/workflows/bright-builds-auto-update.yml")" "auto-update workflow should start with the whole-file managed marker"
  assert_file_contains "${repo_path}/README.md" "OpenLinks profile" "matching owners should receive the owner-specific OpenLinks README badge"
  assert_file_contains "${repo_path}/.github/workflows/bright-builds-auto-update.yml" "cron: '0 14 * * *'" "workflow should use the fixed UTC schedule"
  assert_file_contains "${repo_path}/.github/workflows/bright-builds-auto-update.yml" "bash ./scripts/bright-builds-auto-update.sh" "workflow should invoke the managed helper script"
}

test_trusted_github_user_enables_auto_update_by_default() {
  local repo_path=""

  repo_path="$(create_repo trusted-user)"
  init_git_repo_with_origin "$repo_path" "git@github.com:someone-else/trusted-user.git"

  run_manage_with_actor "$repo_path" "pRizz" status
  assert_eq "$run_status" "0" "trusted-user status should succeed"
  assert_contains "$run_output" "Auto-update: enabled" "trusted GitHub users should default auto-update to enabled"
  assert_contains "$run_output" "Auto-update reason: trusted GitHub user pRizz" "status should report the trusted GitHub user"

  run_manage_with_actor "$repo_path" "pRizz" install
  assert_eq "$run_status" "0" "trusted-user install should succeed"
  assert_file_exists "${repo_path}/scripts/bright-builds-auto-update.sh"
  assert_file_exists "${repo_path}/.github/workflows/bright-builds-auto-update.yml"
  assert_file_contains "${repo_path}/coding-and-architecture-requirements.audit.md" "Auto-update reason: \`trusted GitHub user pRizz\`" "audit should record the GitHub-user trust decision"
}

test_peter_ryszkiewicz_owner_gets_openlinks_identity_guidance() {
  local repo_path=""

  repo_path="$(create_repo peter-owner-guidance)"
  init_git_repo_with_origin "$repo_path" "git@github.com:Peter-Ryszkiewicz/peter-owner-guidance.git"

  run_manage "$repo_path" status
  assert_eq "$run_status" "0" "Peter-owned repo status should succeed"
  assert_contains "$run_output" "README badge block: absent" "Peter-owned GitHub repos should treat the README badge block as applicable"
  assert_contains "$run_output" "Auto-update: disabled" "the OpenLinks owner rule should not change unrelated auto-update defaults"
  assert_contains "$run_output" "Auto-update reason: default disabled" "non-trusted auto-update owners should keep the default explanation"

  run_manage "$repo_path" install
  assert_eq "$run_status" "0" "Peter-owned repo install should succeed"
  assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "repo owner resolves to \`Peter-Ryszkiewicz\`" "owner-specific guidance should include the detected owner"
  assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "openlinks-identity-presence" "Peter-owned repos should receive the OpenLinks identity guidance"
  assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "do not add a second near-duplicate README placement" "guidance should avoid duplicate README promotion"
  assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "Keep the host project's main brand and CTA primary." "guidance should preserve the host brand"
  assert_file_contains "${repo_path}/README.md" "GitHub Stars" "Peter-owned GitHub repos should still include project badges"
  assert_file_contains "${repo_path}/README.md" "OpenLinks profile" "Peter-owned repos should receive the owner-specific OpenLinks README badge"
  assert_line_order "${repo_path}/README.md" "GitHub Stars" "OpenLinks profile"
}

test_owner_specific_openlinks_badge_appends_after_detected_badges() {
  local repo_path=""

  repo_path="$(create_repo peter-owner-readme-order)"
  init_git_repo_with_origin "$repo_path" "git@github.com:Peter-Ryszkiewicz/peter-owner-readme-order.git"
  write_file "${repo_path}/README.md" $'# Peter App\n\nBody text.\n'
  write_file "${repo_path}/package.json" $'{\n  "devDependencies": {\n    "typescript": "5.9.2",\n    "vite": "7.3.1"\n  }\n}\n'

  run_manage "$repo_path" install
  assert_eq "$run_status" "0" "Peter-owned repo install should succeed when detected project badges exist"
  assert_file_contains "${repo_path}/README.md" "TypeScript 5.9.2" "Peter-owned repos should still render detected project badges"
  assert_file_contains "${repo_path}/README.md" "Vite 7.3.1" "Peter-owned repos should still render detected project badges"
  assert_file_contains "${repo_path}/README.md" "OpenLinks profile" "Peter-owned repos should append the OpenLinks badge"
  assert_line_order "${repo_path}/README.md" "Vite 7.3.1" "OpenLinks profile"
}

test_untracked_auto_update_files_are_ignored_when_disabled() {
  local repo_path=""

  repo_path="$(create_repo local-auto-update)"
  write_file "${repo_path}/scripts/bright-builds-auto-update.sh" $'#!/usr/bin/env bash\nprintf local\n'
  write_file "${repo_path}/.github/workflows/bright-builds-auto-update.yml" $'name: Local Auto Update\n'

  run_manage "$repo_path" status
  assert_eq "$run_status" "0" "local auto-update file status should succeed"
  assert_contains "$run_output" "Repo state: installable" "local auto-update files should not block installs when auto-update is disabled"
  assert_contains "$run_output" "Auto-update: disabled" "status should still resolve auto-update to disabled"
  assert_not_contains "$run_output" "Blocking paths: scripts/bright-builds-auto-update.sh" "status should not treat local auto-update files as blocking when disabled"

  run_manage "$repo_path" install
  assert_eq "$run_status" "0" "install should succeed when unrelated auto-update files are present and auto-update is disabled"
  assert_file_contains "${repo_path}/scripts/bright-builds-auto-update.sh" "printf local" "install should preserve unrelated local auto-update script content"
  assert_file_contains "${repo_path}/.github/workflows/bright-builds-auto-update.yml" "name: Local Auto Update" "install should preserve unrelated local auto-update workflow content"
}

test_auto_update_conflicts_block_when_enabled() {
  local repo_path=""

  repo_path="$(create_repo auto-update-blocked)"
  init_git_repo_with_origin "$repo_path" "git@github.com:bright-builds-llc/auto-update-blocked.git"
  write_file "${repo_path}/scripts/bright-builds-auto-update.sh" $'#!/usr/bin/env bash\nprintf conflict\n'

  run_manage "$repo_path" status
  assert_eq "$run_status" "0" "enabled auto-update conflict status should succeed"
  assert_contains "$run_output" "Repo state: blocked" "conflicting auto-update files should block installs when auto-update is enabled"
  assert_contains "$run_output" "Blocking paths: scripts/bright-builds-auto-update.sh" "status should surface the conflicting auto-update path"

  run_manage "$repo_path" install
  assert_eq "$run_status" "1" "install should fail until the auto-update conflict is explicitly forced"
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

test_explicit_auto_update_disable_persists_across_update() {
  local repo_path=""

  repo_path="$(create_repo auto-update-disabled)"
  init_git_repo_with_origin "$repo_path" "git@github.com:bright-builds-llc/auto-update-disabled.git"

  run_manage "$repo_path" install --auto-update disabled
  assert_eq "$run_status" "0" "explicit disable install should succeed"
  assert_file_missing "${repo_path}/scripts/bright-builds-auto-update.sh"
  assert_file_missing "${repo_path}/.github/workflows/bright-builds-auto-update.yml"
  assert_file_contains "${repo_path}/coding-and-architecture-requirements.audit.md" "Auto-update: \`disabled\`" "audit should record the explicit disable"
  assert_file_contains "${repo_path}/coding-and-architecture-requirements.audit.md" "Auto-update reason: \`explicit\`" "audit should record the explicit override"

  run_manage "$repo_path" update
  assert_eq "$run_status" "0" "update should preserve an explicit disable without restating the flag"
  assert_file_missing "${repo_path}/scripts/bright-builds-auto-update.sh"
  assert_file_missing "${repo_path}/.github/workflows/bright-builds-auto-update.yml"
  assert_file_contains "${repo_path}/coding-and-architecture-requirements.audit.md" "Auto-update: \`disabled\`" "update should keep the disabled setting"
  assert_file_contains "${repo_path}/coding-and-architecture-requirements.audit.md" "Auto-update reason: \`explicit\`" "update should keep the explicit reason"
}

test_auto_update_enabled_files_are_restored_on_update() {
  local repo_path=""

  repo_path="$(create_repo auto-update-restore)"

  run_manage "$repo_path" install --auto-update enabled
  assert_eq "$run_status" "0" "explicit enable install should succeed"
  assert_file_exists "${repo_path}/scripts/bright-builds-auto-update.sh"
  assert_file_exists "${repo_path}/.github/workflows/bright-builds-auto-update.yml"

  rm -f "${repo_path}/scripts/bright-builds-auto-update.sh" "${repo_path}/.github/workflows/bright-builds-auto-update.yml"

  run_manage "$repo_path" update
  assert_eq "$run_status" "0" "update should restore missing managed auto-update files"
  assert_file_exists "${repo_path}/scripts/bright-builds-auto-update.sh"
  assert_file_exists "${repo_path}/.github/workflows/bright-builds-auto-update.yml"
  assert_file_contains "${repo_path}/coding-and-architecture-requirements.audit.md" "Auto-update: \`enabled\`" "audit should keep the enabled state"
  assert_file_contains "${repo_path}/coding-and-architecture-requirements.audit.md" "Auto-update reason: \`explicit\`" "audit should keep the explicit enable reason"
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
  assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "copyable summary with the exact commit when available" "update should keep the UI provenance guidance"
  assert_file_contains "${repo_path}/standards-overrides.md" "| \`custom\` | \`keep it\` | \`local\` | \`owner\` | \`2026-03-13\` |" "update should preserve local overrides"
}

test_legacy_exact_match_install_is_still_installed_and_update_migrates_markers() {
  local repo_path=""

  repo_path="$(create_repo legacy-exact-match)"

  run_manage "$repo_path" install --auto-update enabled
  assert_eq "$run_status" "0" "legacy exact-match setup install should succeed"

  strip_whole_file_managed_markers "$repo_path"

  run_manage "$repo_path" status
  assert_eq "$run_status" "0" "legacy exact-match status should succeed"
  assert_contains "$run_output" "Repo state: installed" "legacy exact-match installs should still count as installed"
  assert_not_contains "$run_output" "Repo state: blocked" "legacy exact-match installs should not be blocked"

  run_manage "$repo_path" update
  assert_eq "$run_status" "0" "update should migrate legacy exact-match installs to the marked format"
  assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "$(managed_file_marker "AGENTS.bright-builds.md")" "update should restore the sidecar whole-file marker"
  assert_file_contains "${repo_path}/CONTRIBUTING.md" "$(managed_file_marker "CONTRIBUTING.md")" "update should restore the CONTRIBUTING whole-file marker"
  assert_file_contains "${repo_path}/.github/pull_request_template.md" "$(managed_file_marker ".github/pull_request_template.md")" "update should restore the PR template whole-file marker"
  assert_file_contains "${repo_path}/coding-and-architecture-requirements.audit.md" "$(managed_file_marker "coding-and-architecture-requirements.audit.md")" "update should restore the audit whole-file marker"
  assert_line_equals "${repo_path}/scripts/bright-builds-auto-update.sh" "2" "$(managed_file_marker "scripts/bright-builds-auto-update.sh")" "update should restore the auto-update helper whole-file marker"
  assert_line_equals "${repo_path}/.github/workflows/bright-builds-auto-update.yml" "1" "$(managed_file_marker ".github/workflows/bright-builds-auto-update.yml")" "update should restore the auto-update workflow whole-file marker"
}

test_drifted_whole_file_managed_file_blocks_update_and_force_repairs() {
  local repo_path=""
  local backup_file=""

  repo_path="$(create_repo drifted-managed-file)"

  run_manage "$repo_path" install
  assert_eq "$run_status" "0" "drifted managed file setup install should succeed"

  printf '\nLocal downstream change.\n' >> "${repo_path}/CONTRIBUTING.md"

  run_manage "$repo_path" status
  assert_eq "$run_status" "0" "drifted managed file status should succeed"
  assert_contains "$run_output" "Repo state: blocked" "drifted whole-file managed files should block the repo"
  assert_contains "$run_output" "Blocking paths: CONTRIBUTING.md" "status should list the drifted managed file"

  run_manage "$repo_path" update
  assert_eq "$run_status" "1" "update should fail when a whole-file managed file has downstream edits"

  run_manage "$repo_path" install --force
  assert_eq "$run_status" "0" "force install should repair drifted whole-file managed files"
  backup_file="$(find "${repo_path}/.coding-and-architecture-requirements-backups" -type f -name 'CONTRIBUTING.md' | head -n 1)"
  [[ -n "$backup_file" ]] || fail "expected force install to back up the drifted CONTRIBUTING.md"
  assert_file_contains "${repo_path}/CONTRIBUTING.md" "$(managed_file_marker "CONTRIBUTING.md")" "force install should restore the CONTRIBUTING whole-file marker"
  assert_file_not_contains "${repo_path}/CONTRIBUTING.md" "Local downstream change." "force install should remove the drifted local edit"
}

test_readme_badges_insert_after_h1_and_refresh() {
  local repo_path=""

  repo_path="$(create_repo readme-h1)"
  write_file "${repo_path}/README.md" $'# Demo App\n\nThis line should stay after the badges.\n'
  write_file "${repo_path}/package.json" $'{\n  "engines": {\n    "node": "22"\n  },\n  "devDependencies": {\n    "typescript": "5.8.4",\n    "vite": "7.2.1",\n    "solid-js": "1.8.19"\n  }\n}\n'

  run_manage "$repo_path" install
  assert_eq "$run_status" "0" "install should add README badges after the first H1"
  assert_exact_line_count "${repo_path}/README.md" "$readme_badges_begin" "1"
  assert_exact_line_count "${repo_path}/README.md" "$readme_badges_end" "1"
  assert_line_order "${repo_path}/README.md" "# Demo App" "$readme_badges_begin"
  assert_line_order "${repo_path}/README.md" "$readme_badges_end" "This line should stay after the badges."
  assert_file_contains "${repo_path}/README.md" "Node.js 22" "README should include the verified Node.js badge"
  assert_file_contains "${repo_path}/README.md" "TypeScript 5.8.4" "README should include the detected TypeScript version"
  assert_file_contains "${repo_path}/README.md" "SolidJS 1.8.19" "README should include the detected framework badge"
  assert_file_contains "${repo_path}/README.md" "Vite 7.2.1" "README should include the detected Vite badge"

  write_file "${repo_path}/package.json" $'{\n  "engines": {\n    "node": "22"\n  },\n  "devDependencies": {\n    "typescript": "5.9.2",\n    "vite": "7.3.1",\n    "solid-js": "1.9.0"\n  }\n}\n'

  run_manage "$repo_path" update
  assert_eq "$run_status" "0" "update should refresh detected README badge versions"
  assert_exact_line_count "${repo_path}/README.md" "$readme_badges_begin" "1"
  assert_file_contains "${repo_path}/README.md" "TypeScript 5.9.2" "update should refresh the TypeScript badge version"
  assert_file_contains "${repo_path}/README.md" "SolidJS 1.9.0" "update should refresh the framework badge version"
  assert_file_contains "${repo_path}/README.md" "Vite 7.3.1" "update should refresh the Vite badge version"
  assert_file_contains "${repo_path}/README.md" "This line should stay after the badges." "update should preserve existing README content"
}

test_readme_badges_create_skeleton_and_uninstall_removes_it() {
  local repo_path=""

  repo_path="$(create_repo readme-skeleton)"
  write_file "${repo_path}/package.json" $'{\n  "devDependencies": {\n    "typescript": "5.9.2"\n  }\n}\n'

  run_manage "$repo_path" install
  assert_eq "$run_status" "0" "install should create a README skeleton when verified badges exist"
  assert_file_exists "${repo_path}/README.md"
  assert_file_contains "${repo_path}/README.md" "# readme-skeleton" "generated README should use the repo directory name as the title"
  assert_exact_line_count "${repo_path}/README.md" "$readme_badges_begin" "1"

  run_manage "$repo_path" uninstall
  assert_eq "$run_status" "0" "uninstall should succeed after generating a README skeleton"
  assert_file_missing "${repo_path}/README.md"
}

test_readme_badges_block_existing_top_badges_and_force_repair() {
  local repo_path=""
  local backup_file=""

  repo_path="$(create_repo readme-blocked)"
  write_file "${repo_path}/README.md" $'# Demo App\n\n[![Custom](https://img.shields.io/badge/custom-existing-blue)](https://example.com)\n\nBody text stays here.\n'
  write_file "${repo_path}/package.json" $'{\n  "devDependencies": {\n    "typescript": "5.9.2"\n  }\n}\n'

  run_manage "$repo_path" status
  assert_eq "$run_status" "0" "status should succeed when README badges are ambiguous"
  assert_contains "$run_output" "Repo state: blocked" "existing unmanaged top badges should block installation"
  assert_contains "$run_output" "README badge block: ambiguous" "status should surface the README badge conflict"
  assert_contains "$run_output" "Blocking paths: README.md" "README conflicts should be listed as blocking"

  run_manage "$repo_path" install
  assert_eq "$run_status" "1" "install should fail until the README badge conflict is explicitly forced"

  run_manage "$repo_path" install --force
  assert_eq "$run_status" "0" "force install should repair conflicting README badges"
  backup_file="$(find "${repo_path}/.coding-and-architecture-requirements-backups" -type f -name 'README.md' | head -n 1)"
  [[ -n "$backup_file" ]] || fail "expected force install to back up README.md"

  assert_exact_line_count "${repo_path}/README.md" "$readme_badges_begin" "1"
  assert_file_not_contains "${repo_path}/README.md" "custom-existing-blue" "force repair should remove unmanaged top badges from the insertion zone"
  assert_file_contains "${repo_path}/README.md" "TypeScript 5.9.2" "force repair should insert the managed README badge block"
  assert_file_contains "${repo_path}/README.md" "Body text stays here." "force repair should preserve the README body"
}

test_partial_readme_badge_block_requires_force_repair() {
  local repo_path=""

  repo_path="$(create_repo readme-partial)"
  write_file "${repo_path}/README.md" "$(printf '# Demo App\n\n%s\n[![Custom](https://img.shields.io/badge/custom-partial-blue)](https://example.com)\n\nBody text remains.\n' "$readme_badges_begin")"
  write_file "${repo_path}/package.json" $'{\n  "devDependencies": {\n    "typescript": "5.9.2"\n  }\n}\n'

  run_manage "$repo_path" status
  assert_eq "$run_status" "0" "status should succeed for a partial managed README badge block"
  assert_contains "$run_output" "Repo state: blocked" "partial README badge markers should block the repo"
  assert_contains "$run_output" "README badge block: partial" "status should mark partial README badge blocks explicitly"
  assert_contains "$run_output" "Blocking paths: README.md" "partial README badge blocks should block via README.md"

  run_manage "$repo_path" install --force
  assert_eq "$run_status" "0" "force install should repair a partial managed README badge block"
  assert_exact_line_count "${repo_path}/README.md" "$readme_badges_begin" "1"
  assert_exact_line_count "${repo_path}/README.md" "$readme_badges_end" "1"
  assert_file_contains "${repo_path}/README.md" "TypeScript 5.9.2" "force repair should replace the broken block with managed badges"
  assert_file_contains "${repo_path}/README.md" "Body text remains." "force repair should preserve non-badge README content"
}

test_readme_badges_are_removed_when_no_managed_badges_remain() {
  local repo_path=""

  repo_path="$(create_repo readme-remove)"
  write_file "${repo_path}/README.md" $'# Demo App\n\nBody text remains.\n'
  write_file "${repo_path}/package.json" $'{\n  "devDependencies": {\n    "typescript": "5.9.2"\n  }\n}\n'

  run_manage "$repo_path" install
  assert_eq "$run_status" "0" "install should add README badges before the detector input is removed"
  assert_exact_line_count "${repo_path}/README.md" "$readme_badges_begin" "1"

  rm -f "${repo_path}/package.json"

  run_manage "$repo_path" update
  assert_eq "$run_status" "0" "update should remove the managed README badge block when no managed badges remain"
  assert_file_not_contains "${repo_path}/README.md" "$readme_badges_begin" "update should remove the README badge begin marker when badges are no longer applicable"
  assert_file_contains "${repo_path}/README.md" "Body text remains." "update should keep the README body after removing managed badges"
  assert_file_not_contains "${repo_path}/coding-and-architecture-requirements.audit.md" "README.md (managed badges block)" "audit should stop tracking the README badge block once it is removed"
}

test_update_removes_owner_specific_openlinks_badge_when_owner_changes() {
  local repo_path=""

  repo_path="$(create_repo peter-owner-openlinks-removed)"
  init_git_repo_with_origin "$repo_path" "git@github.com:Peter-Ryszkiewicz/peter-owner-openlinks-removed.git"
  write_file "${repo_path}/README.md" $'# Owner Change\n\nBody text remains.\n'

  run_manage "$repo_path" install
  assert_eq "$run_status" "0" "install should add the owner-specific OpenLinks badge before the owner changes"
  assert_file_contains "${repo_path}/README.md" "OpenLinks profile" "Peter-owned repos should initially receive the OpenLinks badge"

  git -C "$repo_path" remote set-url origin "git@github.com:someone-else/peter-owner-openlinks-removed.git"

  run_manage "$repo_path" update
  assert_eq "$run_status" "0" "update should succeed after the repo owner changes"
  assert_file_not_contains "${repo_path}/README.md" "OpenLinks profile" "update should remove the owner-specific OpenLinks badge when the owner no longer matches"
  assert_file_not_contains "${repo_path}/AGENTS.bright-builds.md" "openlinks-identity-presence" "update should remove owner-specific sidecar guidance when the owner no longer matches"
  assert_file_contains "${repo_path}/README.md" "GitHub Stars" "update should preserve other still-applicable managed README badges"
  assert_file_contains "${repo_path}/README.md" "Body text remains." "update should preserve the rest of the README body"
}

test_rich_readme_badge_detection() {
  local repo_path=""

  repo_path="$(create_repo readme-rich)"
  init_git_repo_with_origin "$repo_path" "git@github.com:bright-builds-llc/readme-rich.git"
  write_file "${repo_path}/README.md" $'# Rich App\n\nBody text.\n'
  write_file "${repo_path}/LICENSE" $'MIT License\n'
  write_file "${repo_path}/.github/workflows/ci.yml" $'name: CI\non: [push]\njobs:\n  build:\n    runs-on: ubuntu-latest\n    steps:\n      - uses: actions/checkout@v4\n      - uses: actions/setup-node@v4\n        with:\n          node-version: 22\n'
  write_file "${repo_path}/.github/workflows/deploy-pages.yml" $'name: Deploy Pages\non: [push]\n'
  write_file "${repo_path}/package.json" $'{\n  "engines": {\n    "node": "22"\n  },\n  "devDependencies": {\n    "typescript": "5.9.2",\n    "vite": "7.3.1",\n    "solid-js": "1.9.0"\n  }\n}\n'
  write_file "${repo_path}/rust-toolchain.toml" $'[toolchain]\nchannel = "1.84.1"\n'
  write_file "${repo_path}/pyproject.toml" $'[project]\nrequires-python = ">=3.11"\n'
  write_file "${repo_path}/go.mod" $'module example.com/rich\n\ngo 1.23.0\n'

  run_manage "$repo_path" install
  assert_eq "$run_status" "0" "install should render the verified rich README badge set"
  assert_file_contains "${repo_path}/README.md" "GitHub Stars" "README should include the GitHub stars badge when origin points to GitHub"
  assert_file_contains "${repo_path}/README.md" "CI" "README should include the CI workflow badge"
  assert_file_contains "${repo_path}/README.md" "Deploy Pages" "README should include the deploy workflow badge"
  assert_file_contains "${repo_path}/README.md" "License" "README should include the license badge"
  assert_file_contains "${repo_path}/README.md" "Node.js 22" "README should include the Node.js badge"
  assert_file_contains "${repo_path}/README.md" "TypeScript 5.9.2" "README should include the TypeScript badge"
  assert_file_contains "${repo_path}/README.md" "SolidJS 1.9.0" "README should include the framework badge"
  assert_file_contains "${repo_path}/README.md" "Vite 7.3.1" "README should include the Vite badge"
  assert_file_contains "${repo_path}/README.md" "Rust 1.84.1" "README should include the Rust badge"
  assert_file_contains "${repo_path}/README.md" "Python >=3.11" "README should include the Python badge"
  assert_file_contains "${repo_path}/README.md" "Go 1.23.0" "README should include the Go badge"
  assert_file_contains "${repo_path}/coding-and-architecture-requirements.audit.md" "README.md (managed badges block)" "audit should track the managed README badge block when present"
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

test_uninstall_preserves_drifted_whole_file_managed_files() {
  local repo_path=""

  repo_path="$(create_repo uninstall-drifted-managed)"

  run_manage "$repo_path" install --auto-update enabled
  assert_eq "$run_status" "0" "install should succeed before drift-preserving uninstall"

  printf '\nKeep this downstream change.\n' >> "${repo_path}/CONTRIBUTING.md"
  printf '\nprintf drifted-helper\n' >> "${repo_path}/scripts/bright-builds-auto-update.sh"

  run_manage "$repo_path" uninstall
  assert_eq "$run_status" "0" "uninstall should succeed when drifted whole-file managed files are present"
  assert_file_missing "${repo_path}/AGENTS.md"
  assert_file_missing "${repo_path}/AGENTS.bright-builds.md"
  assert_file_missing "${repo_path}/.github/pull_request_template.md"
  assert_file_missing "${repo_path}/coding-and-architecture-requirements.audit.md"
  assert_file_missing "${repo_path}/.github/workflows/bright-builds-auto-update.yml"
  assert_file_exists "${repo_path}/CONTRIBUTING.md"
  assert_file_exists "${repo_path}/scripts/bright-builds-auto-update.sh"
  assert_file_contains "${repo_path}/CONTRIBUTING.md" "Keep this downstream change." "uninstall should preserve drifted CONTRIBUTING content"
  assert_file_contains "${repo_path}/scripts/bright-builds-auto-update.sh" "printf drifted-helper" "uninstall should preserve the drifted auto-update helper"
  assert_file_exists "${repo_path}/standards-overrides.md"
}

test_uninstall_removes_agents_when_only_managed_block_remains() {
  local repo_path=""

  repo_path="$(create_repo uninstall-clean)"

  run_manage "$repo_path" install --auto-update enabled
  assert_eq "$run_status" "0" "install should succeed before clean uninstall"

  run_manage "$repo_path" uninstall
  assert_eq "$run_status" "0" "clean uninstall should succeed"
  assert_file_missing "${repo_path}/AGENTS.md"
  assert_file_missing "${repo_path}/scripts/bright-builds-auto-update.sh"
  assert_file_missing "${repo_path}/.github/workflows/bright-builds-auto-update.yml"
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

disable_real_gh_by_default

test_fresh_install_and_reinstall
test_existing_agents_is_installable
test_trusted_repo_owner_enables_auto_update_by_default
test_trusted_github_user_enables_auto_update_by_default
test_peter_ryszkiewicz_owner_gets_openlinks_identity_guidance
test_owner_specific_openlinks_badge_appends_after_detected_badges
test_untracked_auto_update_files_are_ignored_when_disabled
test_auto_update_conflicts_block_when_enabled
test_blocked_conflicts_and_force_install
test_explicit_auto_update_disable_persists_across_update
test_auto_update_enabled_files_are_restored_on_update
test_update_preserves_local_agents_and_overrides
test_legacy_exact_match_install_is_still_installed_and_update_migrates_markers
test_drifted_whole_file_managed_file_blocks_update_and_force_repairs
test_readme_badges_insert_after_h1_and_refresh
test_readme_badges_create_skeleton_and_uninstall_removes_it
test_readme_badges_block_existing_top_badges_and_force_repair
test_partial_readme_badge_block_requires_force_repair
test_readme_badges_are_removed_when_no_managed_badges_remain
test_update_removes_owner_specific_openlinks_badge_when_owner_changes
test_rich_readme_badge_detection
test_old_standalone_install_is_blocked
test_uninstall_preserves_local_agents_and_overrides
test_uninstall_preserves_drifted_whole_file_managed_files
test_uninstall_removes_agents_when_only_managed_block_remains
test_explicit_full_sha_ref_sets_exact_commit
test_unavailable_exact_commit_does_not_block_install

printf 'All manage-downstream integration tests passed.\n'
