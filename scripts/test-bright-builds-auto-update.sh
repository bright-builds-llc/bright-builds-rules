#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script_path="${repo_root}/scripts/manage-downstream.sh"
temp_root="$(mktemp -d "${TMPDIR:-/tmp}/bright-builds-auto-update-tests.XXXXXX")"
repo_exact_commit="$(git -C "${repo_root}" rev-parse HEAD)"
real_git_path="$(command -v git)"
legacy_bright_builds_url="https://github.com/bright-builds-llc/coding-and-architecture-requirements"
legacy_bright_builds_raw_base_url="https://raw.githubusercontent.com/bright-builds-llc/coding-and-architecture-requirements/main"
current_bright_builds_url="https://github.com/bright-builds-llc/bright-builds-rules"
current_bright_builds_raw_base_url="https://raw.githubusercontent.com/bright-builds-llc/bright-builds-rules/main"
legacy_audit_destination="coding-and-architecture-requirements.audit.md"
legacy_repo_ref="0d5dce1^"
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
	printf '%s' "$content" >"$file_path"
}

legacy_bright_builds_canonical_badge() {
	printf '[![Bright Builds Requirements](%s/public/badges/bright-builds.svg)](%s)\n' "$legacy_bright_builds_raw_base_url" "$legacy_bright_builds_url"
}

current_bright_builds_canonical_badge() {
	printf '[![Bright Builds Rules](%s/public/badges/bright-builds-rules.svg)](%s)\n' "$current_bright_builds_raw_base_url" "$current_bright_builds_url"
}

current_bright_builds_flat_badge() {
	printf '[![Bright Builds: Rules](%s/public/badges/bright-builds-rules-flat.svg)](%s)\n' "$current_bright_builds_raw_base_url" "$current_bright_builds_url"
}

insert_line_before_marker() {
	local file_path="$1"
	local marker="$2"
	local inserted_line="$3"
	local updated_path="${file_path}.updated"

	awk -v marker="$marker" -v inserted_line="$inserted_line" '
    $0 == marker && inserted == 0 {
      print inserted_line
      print ""
      inserted = 1
    }

    {
      print
    }
  ' "$file_path" >"$updated_path"
	mv "$updated_path" "$file_path"
}

replace_exact_line() {
	local file_path="$1"
	local old_line="$2"
	local new_line="$3"
	local updated_path="${file_path}.updated"

	awk -v old_line="$old_line" -v new_line="$new_line" '
    $0 == old_line && replaced == 0 {
      print new_line
      replaced = 1
      next
    }

    {
      print
    }
  ' "$file_path" >"$updated_path"
	mv "$updated_path" "$file_path"
}

replace_markdown_value() {
	local file_path="$1"
	local label="$2"
	local replacement="$3"
	local updated_path="${file_path}.updated"

	awk -v label="$label" -v replacement="$replacement" '
    index($0, "- " label ": `") == 1 && replaced == 0 {
      print "- " label ": `" replacement "`"
      replaced = 1
      next
    }

    {
      print
    }
  ' "$file_path" >"$updated_path"
	mv "$updated_path" "$file_path"
}

create_source_bundle() {
	local name="$1"
	local bundle_root="${temp_root}/${name}-bundle"

	mkdir -p "${bundle_root}/scripts" "${bundle_root}/templates"
	cp "$script_path" "${bundle_root}/scripts/manage-downstream.sh"
	cp -R "${repo_root}/templates/." "${bundle_root}/templates/"
	git -C "$bundle_root" init -b main >/dev/null 2>&1
	git -C "$bundle_root" config user.name "Bundle User"
	git -C "$bundle_root" config user.email "bundle@example.com"
	git -C "$bundle_root" add -A
	git -C "$bundle_root" commit -m "Initial bundle" >/dev/null
	printf '%s\n' "$bundle_root"
}

create_legacy_source_bundle() {
	local name="$1"
	local bundle_root="${temp_root}/${name}-legacy-bundle"
	local path=""

	mkdir -p "${bundle_root}/scripts" "${bundle_root}/templates"
	for path in \
		"scripts/manage-downstream.sh" \
		"templates/AGENTS.md" \
		"templates/AGENTS.bright-builds.md" \
		"templates/CONTRIBUTING.md" \
		"templates/pull_request_template.md" \
		"templates/coding-and-architecture-requirements.audit.md" \
		"templates/standards-overrides.md" \
		"templates/bright-builds-auto-update.sh" \
		"templates/bright-builds-auto-update.yml"; do
		mkdir -p "${bundle_root}/$(dirname "$path")"
		git -C "${repo_root}" show "${legacy_repo_ref}:${path}" >"${bundle_root}/${path}"
	done
	chmod +x "${bundle_root}/scripts/manage-downstream.sh"
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

	bash "${bundle_root}/scripts/manage-downstream.sh" install --auto-update enabled --ref main --repo-root "$repo_path" >/dev/null
}

run_auto_update() {
	local repo_path="$1"
	local path_prefix="$2"

	set +e
	run_output="$(env GITHUB_ACTIONS=true PATH="${path_prefix}:$PATH" bash "${repo_path}/scripts/bright-builds-auto-update.sh" 2>&1)"
	run_status=$?
	set -e
}

create_fake_curl_bin() {
	local bin_dir="$1"
	local current_source_root="$2"
	local legacy_source_root="${3:-$current_source_root}"
	local legacy_script_source_root="${4:-$current_source_root}"
	local stale_ref="${5:-}"

	mkdir -p "$bin_dir"
	write_file "${bin_dir}/curl" $'#!/usr/bin/env bash\nset -euo pipefail\noutput=""\nurl=""\nwhile [[ $# -gt 0 ]]; do\n  case "$1" in\n    -o)\n      output="$2"\n      shift 2\n      ;;\n    -f|-s|-S|-L|-fsSL)\n      shift\n      ;;\n    *)\n      url="$1"\n      shift\n      ;;\n  esac\ndone\n[[ -n "$output" ]] || exit 1\nrepo_slug="$(printf "%s" "$url" | sed -n "s#^https://raw\\.githubusercontent\\.com/\\([^/]*/[^/]*\\)/[^/]*/.*#\\1#p")"\nrequested_ref="$(printf "%s" "$url" | sed -n "s#^https://raw\\.githubusercontent\\.com/[^/]*/[^/]*/\\([^/]*\\)/.*#\\1#p")"\nrelative_path="$(printf "%s" "$url" | sed -n "s#^https://raw\\.githubusercontent\\.com/[^/]*/[^/]*/[^/]*/##p")"\n[[ -n "$repo_slug" && -n "$requested_ref" && -n "$relative_path" ]] || exit 1\ncase "$repo_slug" in\n  bright-builds-llc/bright-builds-rules)\n    source_root="${FAKE_CURL_CURRENT_SOURCE_ROOT}"\n    ;;\n  bright-builds-llc/coding-and-architecture-requirements)\n    if [[ "$relative_path" == "scripts/manage-downstream.sh" ]]; then\n      source_root="${FAKE_CURL_LEGACY_SCRIPT_SOURCE_ROOT}"\n    else\n      source_root="${FAKE_CURL_LEGACY_SOURCE_ROOT}"\n    fi\n    ;;\n  *)\n    source_root=""\n    ;;\nesac\nif [[ -z "$source_root" ]]; then\n  printf "curl: (22) The requested URL returned error: 404\\n" >&2\n  exit 22\nfi\nif [[ -n "${FAKE_CURL_STALE_REF:-}" && "$repo_slug" == "bright-builds-llc/coding-and-architecture-requirements" && "$requested_ref" == "${FAKE_CURL_STALE_REF}" ]]; then\n  printf "curl: (22) The requested URL returned error: 404\\n" >&2\n  exit 22\nfi\nif "${REAL_GIT_PATH}" -C "$source_root" rev-parse --verify "${requested_ref}^{commit}" >/dev/null 2>&1; then\n  if "${REAL_GIT_PATH}" -C "$source_root" cat-file -e "${requested_ref}:${relative_path}" >/dev/null 2>&1; then\n    "${REAL_GIT_PATH}" -C "$source_root" show "${requested_ref}:${relative_path}" > "$output"\n    exit 0\n  fi\nfi\nif [[ -f "${source_root}/${relative_path}" ]]; then\n  cp "${source_root}/${relative_path}" "$output"\n  exit 0\nfi\nprintf "curl: (22) The requested URL returned error: 404\\n" >&2\nexit 22\n'
	chmod +x "${bin_dir}/curl"
	write_file "${bin_dir}/git" $'#!/usr/bin/env bash\nset -euo pipefail\nif [[ "${1:-}" == "ls-remote" && "${2:-}" == "https://github.com/bright-builds-llc/bright-builds-rules.git" ]]; then\n  ref="${3:-}"\n  [[ -n "$ref" ]] || exit 1\n  commit="$("${REAL_GIT_PATH}" -C "${FAKE_GIT_SOURCE_ROOT}" rev-parse "${ref}^{commit}")"\n  printf "%s\\t%s\\n" "$commit" "$ref"\n  exit 0\nfi\nexec "${REAL_GIT_PATH}" "$@"\n'
	chmod +x "${bin_dir}/git"
	FAKE_CURL_CURRENT_SOURCE_ROOT="$current_source_root"
	FAKE_CURL_LEGACY_SOURCE_ROOT="$legacy_source_root"
	FAKE_CURL_LEGACY_SCRIPT_SOURCE_ROOT="$legacy_script_source_root"
	FAKE_CURL_STALE_REF="$stale_ref"
	FAKE_GIT_SOURCE_ROOT="$current_source_root"
	REAL_GIT_PATH="$real_git_path"
	export FAKE_CURL_CURRENT_SOURCE_ROOT
	export FAKE_CURL_LEGACY_SOURCE_ROOT
	export FAKE_CURL_LEGACY_SCRIPT_SOURCE_ROOT
	export FAKE_CURL_STALE_REF
	export FAKE_GIT_SOURCE_ROOT
	export REAL_GIT_PATH
}

create_fake_git_bin() {
	local bin_dir="$1"
	local log_path="$2"

	mkdir -p "$bin_dir"
	write_file "${bin_dir}/git" $'#!/usr/bin/env bash\nset -euo pipefail\nif [[ "${1:-}" == "ls-remote" && "${2:-}" == "https://github.com/bright-builds-llc/bright-builds-rules.git" ]]; then\n  ref="${3:-}"\n  [[ -n "$ref" ]] || exit 1\n  commit="$("${REAL_GIT_PATH}" -C "${FAKE_GIT_SOURCE_ROOT}" rev-parse "${ref}^{commit}")"\n  printf "%s\\t%s\\n" "$commit" "$ref"\n  exit 0\nfi\nif [[ "${1:-}" == "push" && "${2:-}" == "origin" && "${3:-}" == "HEAD:main" ]]; then\n  printf "rejected direct push\\n" >> "${FAKE_GIT_LOG}"\n  exit 1\nfi\nexec "${REAL_GIT_PATH}" "$@"\n'
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
	write_file "${repo_path}/package.json" $'{\n  "devDependencies": {\n    "typescript": "5.9.2"\n  }\n}\n'
	install_auto_update_repo "$bundle_root" "$repo_path"
	commit_all "$repo_path" "Initial managed install"
	git -C "$repo_path" push -u origin main >/dev/null
	printf '\n- Added direct-push update marker.\n' >>"${bundle_root}/templates/AGENTS.bright-builds.md"
	git -C "$bundle_root" add -A
	git -C "$bundle_root" commit -m "Bundle update" >/dev/null
	create_fake_curl_bin "$fake_bin" "$bundle_root"

	run_auto_update "$repo_path" "$fake_bin"
	assert_eq "$run_status" "0" "direct-push auto-update should succeed"
	assert_contains "$run_output" "Pushed managed updates directly to main" "auto-update should report the direct push path"
	latest_subject="$(git --git-dir="$remote_path" log --format=%s -1 refs/heads/main)"
	assert_eq "$latest_subject" "chore: update Bright Builds Rules" "direct push should update the remote default branch"
}

test_refreshes_old_managed_canonical_badge_to_flat_default_when_upstream_is_otherwise_unchanged() {
	local bundle_root=""
	local repo_path=""
	local remote_path=""
	local fake_bin=""
	local latest_subject=""
	local old_managed_badge=""
	local current_badge=""

	bundle_root="$(create_source_bundle readme-legacy-repair)"
	repo_path="$(create_repo readme-legacy-repair-repo)"
	remote_path="$(create_bare_remote readme-legacy-repair-origin)"
	fake_bin="${temp_root}/readme-legacy-repair-bin"

	init_git_repo "$repo_path"
	git -C "$repo_path" remote add origin "$remote_path"
	write_file "${repo_path}/package.json" $'{\n  "devDependencies": {\n    "typescript": "5.9.2"\n  }\n}\n'
	install_auto_update_repo "$bundle_root" "$repo_path"
	old_managed_badge="$(current_bright_builds_canonical_badge)"
	current_badge="$(current_bright_builds_flat_badge)"
	replace_exact_line "${repo_path}/README.md" "$current_badge" "$old_managed_badge"
	commit_all "$repo_path" "Initial managed install"
	git -C "$repo_path" push -u origin main >/dev/null
	create_fake_curl_bin "$fake_bin" "$bundle_root"

	run_auto_update "$repo_path" "$fake_bin"
	assert_eq "$run_status" "0" "auto-update should refresh the old managed canonical badge to the flat default even when the upstream bundle is otherwise unchanged"
	assert_contains "$run_output" "Pushed managed updates directly to main" "auto-update should publish the managed badge default refresh"
	assert_file_not_contains "${repo_path}/README.md" "$old_managed_badge" "auto-update should remove the old managed canonical badge"
	assert_file_contains "${repo_path}/README.md" "$current_badge" "auto-update should write the flat managed Bright Builds badge"
	latest_subject="$(git --git-dir="$remote_path" log --format=%s -1 refs/heads/main)"
	assert_eq "$latest_subject" "chore: update Bright Builds Rules" "managed badge default refresh should create the standard auto-update commit"
}

test_legacy_helper_migrates_prerename_install_with_current_manager() {
	local legacy_bundle_root=""
	local current_bundle_root=""
	local repo_path=""
	local remote_path=""
	local fake_bin=""
	local commit_count=""

	legacy_bundle_root="$(create_legacy_source_bundle legacy-helper)"
	current_bundle_root="$(create_source_bundle legacy-helper-current)"
	repo_path="$(create_repo legacy-helper-repo)"
	remote_path="$(create_bare_remote legacy-helper-origin)"
	fake_bin="${temp_root}/legacy-helper-bin"

	init_git_repo "$repo_path"
	git -C "$repo_path" remote add origin "$remote_path"
	write_file "${repo_path}/README.md" $'# Legacy App\n\nBody text remains.\n'
	write_file "${repo_path}/package.json" $'{\n  "devDependencies": {\n    "typescript": "5.9.2"\n  }\n}\n'
	bash "${legacy_bundle_root}/scripts/manage-downstream.sh" install --auto-update enabled --ref main --repo-root "$repo_path" >/dev/null
	assert_file_exists "${repo_path}/${legacy_audit_destination}"
	commit_all "$repo_path" "Initial legacy managed install"
	git -C "$repo_path" push -u origin main >/dev/null
	create_fake_curl_bin "$fake_bin" "$current_bundle_root" "$legacy_bundle_root" "$current_bundle_root"

	run_auto_update "$repo_path" "$fake_bin"
	assert_eq "$run_status" "0" "legacy helper auto-update should succeed by migrating the install through the current manager"
	assert_contains "$run_output" "Repo state: installed" "legacy helper run should classify the repo as installed before migration"
	assert_file_exists "${repo_path}/${legacy_audit_destination}"
	assert_file_exists "${repo_path}/bright-builds-rules.audit.md"
	assert_file_contains "${repo_path}/AGENTS.md" "<!-- bright-builds-rules-managed:begin -->" "legacy helper migration should rewrite AGENTS markers"
	assert_file_contains "${repo_path}/README.md" "<!-- bright-builds-rules-readme-badges:begin -->" "legacy helper migration should rewrite README badge markers"
	assert_file_contains "${repo_path}/scripts/bright-builds-auto-update.sh" "bright-builds-rules.audit.md" "legacy helper migration should rewrite the helper to the new audit path"
	assert_file_contains "${repo_path}/bright-builds-rules.audit.md" "Source repository: \`https://github.com/bright-builds-llc/bright-builds-rules\`" "legacy helper migration should write the new audit manifest"
	commit_count="$(git -C "$repo_path" rev-list --count HEAD)"
	assert_eq "$commit_count" "2" "legacy helper migration should create one update commit"
}

test_legacy_helper_falls_back_from_stale_exact_commit_during_status() {
	local legacy_bundle_root=""
	local current_bundle_root=""
	local repo_path=""
	local remote_path=""
	local fake_bin=""
	local commit_count=""
	local stale_exact_commit="0000000000000000000000000000000000000000"

	legacy_bundle_root="$(create_legacy_source_bundle legacy-stale-exact)"
	current_bundle_root="$(create_source_bundle legacy-stale-exact-current)"
	repo_path="$(create_repo legacy-stale-exact-repo)"
	remote_path="$(create_bare_remote legacy-stale-exact-origin)"
	fake_bin="${temp_root}/legacy-stale-exact-bin"

	init_git_repo "$repo_path"
	git -C "$repo_path" remote add origin "$remote_path"
	write_file "${repo_path}/README.md" $'# Legacy App\n\nBody text remains.\n'
	write_file "${repo_path}/package.json" $'{\n  "devDependencies": {\n    "typescript": "5.9.2"\n  }\n}\n'
	bash "${legacy_bundle_root}/scripts/manage-downstream.sh" install --auto-update enabled --ref main --repo-root "$repo_path" >/dev/null
	replace_markdown_value "${repo_path}/${legacy_audit_destination}" "Exact commit" "$stale_exact_commit"
	replace_markdown_value "${repo_path}/AGENTS.bright-builds.md" "Exact commit" "$stale_exact_commit"
	commit_all "$repo_path" "Initial legacy managed install"
	git -C "$repo_path" push -u origin main >/dev/null
	create_fake_curl_bin "$fake_bin" "$current_bundle_root" "$legacy_bundle_root" "$current_bundle_root" "$stale_exact_commit"

	run_auto_update "$repo_path" "$fake_bin"
	assert_eq "$run_status" "0" "legacy helper auto-update should recover when the legacy exact commit no longer resolves"
	assert_contains "$run_output" "Repo state: installed" "legacy helper auto-update should still classify the repo as installed before migration"
	assert_file_exists "${repo_path}/bright-builds-rules.audit.md"
	assert_file_contains "${repo_path}/AGENTS.md" "<!-- bright-builds-rules-managed:begin -->" "stale exact-commit fallback should still migrate the AGENTS markers"
	assert_file_contains "${repo_path}/scripts/bright-builds-auto-update.sh" "bright-builds-rules.audit.md" "stale exact-commit fallback should still rewrite the helper to the new audit path"
	assert_not_contains "$run_output" "curl:" "legacy helper auto-update should suppress comparison fetch fallback noise"
	assert_not_contains "$run_output" "No such file or directory" "legacy helper auto-update should not surface missing temp-path errors"
	commit_count="$(git -C "$repo_path" rev-list --count HEAD)"
	assert_eq "$commit_count" "2" "stale exact-commit fallback should still create one update commit"
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
	printf '\n- Added PR fallback update marker.\n' >>"${bundle_root}/templates/AGENTS.bright-builds.md"
	git -C "$bundle_root" add -A
	git -C "$bundle_root" commit -m "Bundle update" >/dev/null
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

test_fails_when_repo_state_is_blocked_by_managed_file_drift() {
	local bundle_root=""
	local repo_path=""
	local fake_bin=""
	local commit_count=""

	bundle_root="$(create_source_bundle blocked-drift)"
	repo_path="$(create_repo blocked-drift-repo)"
	fake_bin="${temp_root}/blocked-drift-bin"

	init_git_repo "$repo_path"
	install_auto_update_repo "$bundle_root" "$repo_path"
	commit_all "$repo_path" "Initial managed install"
	printf '\nDrifted downstream edit.\n' >>"${repo_path}/AGENTS.bright-builds.md"
	create_fake_curl_bin "$fake_bin" "$bundle_root"

	run_auto_update "$repo_path" "$fake_bin"
	assert_eq "$run_status" "1" "drift-blocked auto-update should fail"
	assert_contains "$run_output" "Repo state: blocked" "auto-update should surface the blocked repo state when a managed file drifts"
	assert_contains "$run_output" "Blocking paths: AGENTS.bright-builds.md" "auto-update should surface the drifted managed file path"
	assert_contains "$run_output" "auto-update requires the repo state to remain installed" "auto-update should stop before mutating drifted repos"
	commit_count="$(git -C "$repo_path" rev-list --count HEAD)"
	assert_eq "$commit_count" "1" "drift-blocked auto-update should not create a new commit"
}

trap cleanup EXIT

test_noop_when_no_changes_exist
test_pushes_directly_when_push_succeeds
test_refreshes_old_managed_canonical_badge_to_flat_default_when_upstream_is_otherwise_unchanged
test_legacy_helper_migrates_prerename_install_with_current_manager
test_legacy_helper_falls_back_from_stale_exact_commit_during_status
test_falls_back_to_pull_request_when_direct_push_fails
test_fails_when_repo_state_is_blocked
test_fails_when_repo_state_is_blocked_by_managed_file_drift

printf 'All bright-builds auto-update tests passed.\n'
