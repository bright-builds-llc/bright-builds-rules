#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script_path="${repo_root}/scripts/manage-downstream.sh"
temp_root="$(mktemp -d "${TMPDIR:-/tmp}/bright-builds-auto-update-tests.XXXXXX")"
repo_exact_commit="$(git -C "${repo_root}" rev-parse HEAD)"
real_git_path="$(command -v git)"
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

assert_file_exists() {
  local file_path="$1"

  [[ -f "$file_path" ]] || fail "expected file to exist: $file_path"
}

assert_file_contains() {
  local file_path="$1"
  local needle="$2"
  local message="$3"

  grep -Fq "$needle" "$file_path" || fail "${message}: missing '${needle}' in ${file_path}"
}

assert_ref_exists() {
  local git_dir="$1"
  local ref_name="$2"

  git --git-dir="$git_dir" show-ref --verify --quiet "$ref_name" || fail "expected ref to exist: ${ref_name}"
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

create_source_bundle() {
  local name="$1"
  local bundle_root="${temp_root}/${name}-bundle"

  mkdir -p "${bundle_root}/scripts" "${bundle_root}/templates"
  cp "$script_path" "${bundle_root}/scripts/manage-downstream.sh"
  cp -R "${repo_root}/templates/." "${bundle_root}/templates/"
  printf '%s\n' "$bundle_root"
}

init_git_repo() {
  local repo_path="$1"

  git -C "$repo_path" init -b main >/dev/null 2>&1
  git -C "$repo_path" config user.name "Test User"
  git -C "$repo_path" config user.email "test@example.com"
}

create_bare_remote() {
  local name="$1"
  local remote_path="${temp_root}/${name}.git"

  git init --bare "$remote_path" >/dev/null 2>&1
  printf '%s\n' "$remote_path"
}

commit_all() {
  local repo_path="$1"
  local message="$2"

  git -C "$repo_path" add -A
  git -C "$repo_path" commit -m "$message" >/dev/null
}

install_auto_update_repo() {
  local bundle_root="$1"
  local repo_path="$2"

  bash "${bundle_root}/scripts/manage-downstream.sh" install --auto-update enabled --ref "$repo_exact_commit" --repo-root "$repo_path" >/dev/null
}

run_auto_update() {
  local repo_path="$1"
  local path_prefix="$2"

  set +e
  run_output="$(env PATH="${path_prefix}:$PATH" bash "${repo_path}/scripts/bright-builds-auto-update.sh" 2>&1)"
  run_status=$?
  set -e
}

create_fake_curl_bin() {
  local bin_dir="$1"
  local source_root="$2"

  mkdir -p "$bin_dir"
  write_file "${bin_dir}/curl" $'#!/usr/bin/env bash\nset -euo pipefail\noutput=""\nurl=""\nwhile [[ $# -gt 0 ]]; do\n  case "$1" in\n    -o)\n      output="$2"\n      shift 2\n      ;;\n    -f|-s|-S|-L|-fsSL)\n      shift\n      ;;\n    *)\n      url="$1"\n      shift\n      ;;\n  esac\ndone\n[[ -n "$output" ]] || exit 1\nrelative_path="$(printf "%s" "$url" | sed -n "s#^https://raw\\.githubusercontent\\.com/[^/]*/[^/]*/[^/]*/##p")"\n[[ -n "$relative_path" ]] || exit 1\ncp "${FAKE_CURL_SOURCE_ROOT}/${relative_path}" "$output"\n'
  chmod +x "${bin_dir}/curl"
  FAKE_CURL_SOURCE_ROOT="$source_root"
  export FAKE_CURL_SOURCE_ROOT
}

create_fake_git_bin() {
  local bin_dir="$1"
  local log_path="$2"

  mkdir -p "$bin_dir"
  write_file "${bin_dir}/git" $'#!/usr/bin/env bash\nset -euo pipefail\nif [[ "${1:-}" == "push" && "${2:-}" == "origin" && "${3:-}" == "HEAD:main" ]]; then\n  printf "rejected direct push\\n" >> "${FAKE_GIT_LOG}"\n  exit 1\nfi\nexec "${REAL_GIT_PATH}" "$@"\n'
  chmod +x "${bin_dir}/git"
  REAL_GIT_PATH="$real_git_path"
  FAKE_GIT_LOG="$log_path"
  export REAL_GIT_PATH
  export FAKE_GIT_LOG
}

create_fake_gh_bin() {
  local bin_dir="$1"
  local log_path="$2"

  mkdir -p "$bin_dir"
  write_file "${bin_dir}/gh" $'#!/usr/bin/env bash\nset -euo pipefail\nprintf "%s\\n" "$*" >> "${FAKE_GH_LOG}"\ncase "${1:-}" in\n  pr)\n    case "${2:-}" in\n      list)\n        printf "[]"\n        ;;\n      create)\n        ;;\n      *)\n        exit 1\n        ;;\n    esac\n    ;;\n  repo)\n    if [[ "${2:-}" == "view" ]]; then\n      printf "main\\n"\n    else\n      exit 1\n    fi\n    ;;\n  *)\n    exit 1\n    ;;\nesac\n'
  chmod +x "${bin_dir}/gh"
  FAKE_GH_LOG="$log_path"
  export FAKE_GH_LOG
}

test_noop_when_no_changes_exist() {
  local bundle_root=""
  local repo_path=""
  local fake_bin=""
  local commit_count=""

  bundle_root="$(create_source_bundle noop)"
  repo_path="$(create_repo noop-repo)"
  fake_bin="${temp_root}/noop-bin"

  init_git_repo "$repo_path"
  install_auto_update_repo "$bundle_root" "$repo_path"
  commit_all "$repo_path" "Initial managed install"
  create_fake_curl_bin "$fake_bin" "$bundle_root"

  run_auto_update "$repo_path" "$fake_bin"
  assert_eq "$run_status" "0" "auto-update no-op should succeed"
  assert_contains "$run_output" "No managed-file changes detected." "auto-update should report the no-op case"
  commit_count="$(git -C "$repo_path" rev-list --count HEAD)"
  assert_eq "$commit_count" "1" "no-op auto-update should not create a new commit"
}

test_pushes_directly_when_push_succeeds() {
  local bundle_root=""
  local repo_path=""
  local remote_path=""
  local fake_bin=""
  local latest_subject=""

  bundle_root="$(create_source_bundle direct-push)"
  repo_path="$(create_repo direct-push-repo)"
  remote_path="$(create_bare_remote direct-push-origin)"
  fake_bin="${temp_root}/direct-push-bin"

  init_git_repo "$repo_path"
  git -C "$repo_path" remote add origin "$remote_path"
  install_auto_update_repo "$bundle_root" "$repo_path"
  commit_all "$repo_path" "Initial managed install"
  git -C "$repo_path" push -u origin main >/dev/null
  printf '\n- Added direct-push update marker.\n' >> "${bundle_root}/templates/AGENTS.bright-builds.md"
  create_fake_curl_bin "$fake_bin" "$bundle_root"

  run_auto_update "$repo_path" "$fake_bin"
  assert_eq "$run_status" "0" "direct-push auto-update should succeed"
  assert_contains "$run_output" "Pushed managed updates directly to main" "auto-update should report the direct push path"
  latest_subject="$(git --git-dir="$remote_path" log --format=%s -1 refs/heads/main)"
  assert_eq "$latest_subject" "chore: update Bright Builds requirements" "direct push should update the remote default branch"
}

test_falls_back_to_pull_request_when_direct_push_fails() {
  local bundle_root=""
  local repo_path=""
  local remote_path=""
  local fake_bin=""
  local fake_git_log=""
  local fake_gh_log=""

  bundle_root="$(create_source_bundle pr-fallback)"
  repo_path="$(create_repo pr-fallback-repo)"
  remote_path="$(create_bare_remote pr-fallback-origin)"
  fake_bin="${temp_root}/pr-fallback-bin"
  fake_git_log="${temp_root}/pr-fallback-git.log"
  fake_gh_log="${temp_root}/pr-fallback-gh.log"

  init_git_repo "$repo_path"
  git -C "$repo_path" remote add origin "$remote_path"
  install_auto_update_repo "$bundle_root" "$repo_path"
  commit_all "$repo_path" "Initial managed install"
  git -C "$repo_path" push -u origin main >/dev/null
  printf '\n- Added PR fallback update marker.\n' >> "${bundle_root}/templates/AGENTS.bright-builds.md"
  create_fake_curl_bin "$fake_bin" "$bundle_root"
  create_fake_git_bin "$fake_bin" "$fake_git_log"
  create_fake_gh_bin "$fake_bin" "$fake_gh_log"

  run_auto_update "$repo_path" "$fake_bin"
  assert_eq "$run_status" "0" "PR fallback auto-update should succeed"
  assert_contains "$run_output" "Direct push to main failed; falling back to bright-builds/auto-update" "auto-update should report the fallback path"
  assert_contains "$run_output" "Opened pull request from bright-builds/auto-update to main" "auto-update should open the fallback pull request"
  assert_file_contains "$fake_git_log" "rejected direct push" "fake git should record the rejected direct push"
  assert_file_contains "$fake_gh_log" "pr create" "fake gh should record the PR creation"
  assert_ref_exists "$remote_path" "refs/heads/bright-builds/auto-update"
}

test_fails_when_repo_state_is_blocked() {
  local bundle_root=""
  local repo_path=""
  local fake_bin=""
  local commit_count=""

  bundle_root="$(create_source_bundle blocked)"
  repo_path="$(create_repo blocked-repo)"
  fake_bin="${temp_root}/blocked-bin"

  init_git_repo "$repo_path"
  install_auto_update_repo "$bundle_root" "$repo_path"
  commit_all "$repo_path" "Initial managed install"
  rm -f "${repo_path}/AGENTS.bright-builds.md"
  create_fake_curl_bin "$fake_bin" "$bundle_root"

  run_auto_update "$repo_path" "$fake_bin"
  assert_eq "$run_status" "1" "blocked auto-update should fail"
  assert_contains "$run_output" "Repo state: blocked" "auto-update should surface the blocked repo state"
  assert_contains "$run_output" "auto-update requires the repo state to remain installed" "auto-update should stop before mutating blocked repos"
  commit_count="$(git -C "$repo_path" rev-list --count HEAD)"
  assert_eq "$commit_count" "1" "blocked auto-update should not create a new commit"
}

trap cleanup EXIT

test_noop_when_no_changes_exist
test_pushes_directly_when_push_succeeds
test_falls_back_to_pull_request_when_direct_push_fails
test_fails_when_repo_state_is_blocked

printf 'All bright-builds auto-update tests passed.\n'
