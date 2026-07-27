test_noop_when_no_changes_exist() {
	local bundle_root=""
	local config_hash=""
	local repo_path=""
	local fake_bin=""
	local commit_count=""
	local document_hash=""

	bundle_root="$(create_source_bundle noop)"
	repo_path="$(create_repo noop-repo)"
	fake_bin="${temp_root}/noop-bin"

	init_git_repo "$repo_path"
	install_auto_update_repo "$bundle_root" "$repo_path"
	write_markdown_dialect_fixture "$repo_path"
	config_hash="$(git -C "$repo_path" hash-object .mdformat.toml)"
	document_hash="$(git -C "$repo_path" hash-object docs/PLAN.md)"
	commit_all "$repo_path" "Initial managed install"
	create_fake_curl_bin "$fake_bin" "$bundle_root"

	run_auto_update "$repo_path" "$fake_bin" "false"
	assert_eq "$run_status" "0" "auto-update no-op should succeed"
	assert_contains "$run_output" "No managed-file changes detected." "auto-update should report the no-op case"
	assert_markdown_dialect_fixture_hashes "$repo_path" "$config_hash" "$document_hash"
	commit_count="$(git -C "$repo_path" rev-list --count HEAD)"
	assert_eq "$commit_count" "1" "no-op auto-update should not create a new commit"
}

test_noop_when_mdformat_is_absent() {
	local bootstrap_log=""
	local bundle_root=""
	local repo_path=""
	local fake_bin=""
	local commit_count=""
	local path_without_mdformat=""

	bundle_root="$(create_source_bundle noop-no-mdformat)"
	repo_path="$(create_repo noop-no-mdformat-repo)"
	fake_bin="${temp_root}/noop-no-mdformat-bin"

	init_git_repo "$repo_path"
	install_auto_update_repo "$bundle_root" "$repo_path"
	assert_file_contains "${repo_path}/.github/workflows/bright-builds-auto-update.yml" "actions/setup-python@v6" "managed workflow should set up Python for mdformat"
	assert_file_contains "${repo_path}/.github/workflows/bright-builds-auto-update.yml" "python-version: '3.13'" "managed workflow should pin the Python version used for mdformat"
	assert_file_contains "${repo_path}/.github/workflows/bright-builds-auto-update.yml" "mdformat==1.0.0" "managed workflow should install the pinned mdformat version"
	assert_file_contains "${repo_path}/.github/workflows/bright-builds-auto-update.yml" "mdformat-frontmatter==2.1.2" "managed workflow should install the pinned frontmatter extension"
	assert_file_contains "${repo_path}/.github/workflows/bright-builds-auto-update.yml" "mdformat-gfm==1.0.0" "managed workflow should install the pinned GFM extension"
	commit_all "$repo_path" "Initial managed install"
	create_fake_curl_bin "$fake_bin" "$bundle_root"
	bootstrap_log="${temp_root}/noop-no-mdformat-python.log"
	create_fake_python_mdformat_bootstrap_bin "$fake_bin" "$bootstrap_log"
	path_without_mdformat="${fake_bin}:$(path_without_command_dir mdformat)"
	if env PATH="$path_without_mdformat" "$BASH" -c 'command -v mdformat >/dev/null 2>&1'; then
		fail "test setup failed to remove mdformat from PATH"
	fi

	set +e
	run_output="$(env GITHUB_ACTIONS=true PATH="$path_without_mdformat" "$BASH" "${repo_path}/scripts/bright-builds-auto-update.sh" 2>&1)"
	run_status=$?
	set -e

	assert_eq "$run_status" "0" "auto-update no-op should succeed without mdformat"
	assert_contains "$run_output" "Repo state: installed" "auto-update should classify clean managed Markdown as installed without mdformat"
	assert_contains "$run_output" "No managed-file changes detected." "auto-update should report no changes without mdformat"
	assert_file_contains "$bootstrap_log" "mdformat==1.0.0" "auto-update manager fallback should install the pinned mdformat version"
	assert_file_contains "$bootstrap_log" "mdformat-frontmatter==2.1.2" "auto-update manager fallback should install the pinned frontmatter extension"
	assert_file_contains "$bootstrap_log" "mdformat-gfm==1.0.0" "auto-update manager fallback should install the pinned GFM extension"
	commit_count="$(git -C "$repo_path" rev-list --count HEAD)"
	assert_eq "$commit_count" "1" "no-mdformat auto-update should not create a new commit"
}

test_pushes_directly_when_push_succeeds() {
	local bundle_root=""
	local config_hash=""
	local repo_path=""
	local remote_path=""
	local fake_bin=""
	local latest_subject=""
	local local_name_before=""
	local local_email_before=""
	local local_name_after=""
	local local_email_after=""
	local latest_author_name=""
	local latest_author_email=""
	local document_hash=""
	local changed_paths=""

	bundle_root="$(create_source_bundle direct-push)"
	repo_path="$(create_repo direct-push-repo)"
	remote_path="$(create_bare_remote direct-push-origin)"
	fake_bin="${temp_root}/direct-push-bin"

	init_git_repo "$repo_path"
	git -C "$repo_path" remote add origin "$remote_path"
	write_file "${repo_path}/package.json" $'{\n  "devDependencies": {\n    "typescript": "5.9.2"\n  }\n}\n'
	install_auto_update_repo "$bundle_root" "$repo_path"
	write_markdown_dialect_fixture "$repo_path"
	config_hash="$(git -C "$repo_path" hash-object .mdformat.toml)"
	document_hash="$(git -C "$repo_path" hash-object docs/PLAN.md)"
	assert_file_contains "${repo_path}/.github/workflows/bright-builds-auto-update.yml" 'BRIGHT_BUILDS_PUSH_TOKEN: ${{ secrets.BRIGHT_BUILDS_PUSH_TOKEN || github.token }}' "managed workflow should expose the optional dedicated push token"
	assert_file_contains "${repo_path}/.github/workflows/bright-builds-auto-update.yml" 'BRIGHT_BUILDS_PUSH_TOKEN_CONFIGURED: ${{ secrets.BRIGHT_BUILDS_PUSH_TOKEN != '"'"''"'"' }}' "managed workflow should expose whether the dedicated token is configured"
	assert_file_contains "${repo_path}/.github/workflows/bright-builds-auto-update.yml" 'token: ${{ secrets.BRIGHT_BUILDS_PUSH_TOKEN || github.token }}' "managed workflow should pass the dedicated token to checkout"
	assert_file_contains "${repo_path}/.github/workflows/bright-builds-auto-update.yml" 'GH_TOKEN: ${{ env.BRIGHT_BUILDS_PUSH_TOKEN }}' "managed workflow should export GH_TOKEN for the helper"
	assert_file_contains "${repo_path}/.github/workflows/bright-builds-auto-update.yml" 'GITHUB_TOKEN: ${{ env.BRIGHT_BUILDS_PUSH_TOKEN }}' "managed workflow should export GITHUB_TOKEN for the helper"
	assert_file_contains "${repo_path}/.github/workflows/bright-builds-auto-update.yml" 'if: ${{ failure() }}' "managed workflow should print the repair prompt only on failure"
	assert_file_contains "${repo_path}/.github/workflows/bright-builds-auto-update.yml" "actions/setup-python@v6" "managed workflow should set up Python for mdformat"
	assert_file_contains "${repo_path}/.github/workflows/bright-builds-auto-update.yml" "python-version: '3.13'" "managed workflow should pin the Python version used for mdformat"
	assert_file_contains "${repo_path}/.github/workflows/bright-builds-auto-update.yml" "mdformat==1.0.0" "managed workflow should install the pinned mdformat version"
	assert_file_contains "${repo_path}/.github/workflows/bright-builds-auto-update.yml" "mdformat-frontmatter==2.1.2" "managed workflow should install the pinned frontmatter extension"
	assert_file_contains "${repo_path}/.github/workflows/bright-builds-auto-update.yml" "mdformat-gfm==1.0.0" "managed workflow should install the pinned GFM extension"
	assert_file_contains "${repo_path}/.github/workflows/bright-builds-auto-update.yml" "https://github.com/bright-builds-llc/bright-builds-rules" "managed workflow should point the repair prompt to the upstream repo"
	assert_file_contains "${repo_path}/.github/workflows/bright-builds-auto-update.yml" 'Run URL: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}' "managed workflow should include the downstream run URL expression"
	assert_file_contains "${repo_path}/.github/workflows/bright-builds-auto-update.yml" "Managed workflow: .github/workflows/bright-builds-auto-update.yml" "managed workflow should name the managed workflow path"
	assert_file_contains "${repo_path}/.github/workflows/bright-builds-auto-update.yml" "Managed helper: scripts/bright-builds-auto-update.sh" "managed workflow should name the managed helper path"
	assert_file_contains "${repo_path}/.github/workflows/bright-builds-auto-update.yml" "prepare a pull request against https://github.com/bright-builds-llc/bright-builds-rules" "managed workflow should direct upstream managed fixes to an upstream PR"
	assert_file_contains "${repo_path}/.github/workflows/bright-builds-auto-update.yml" "chmod 600 /Users/peterryszkiewicz/Repos/BRIGHT_BUILDS_PUSH_TOKEN.txt" "managed workflow should print the exact token-file permission command"
	assert_file_contains "${repo_path}/.github/workflows/bright-builds-auto-update.yml" "test -s /Users/peterryszkiewicz/Repos/BRIGHT_BUILDS_PUSH_TOKEN.txt" "managed workflow should print the exact non-empty token-file check"
	assert_file_contains "${repo_path}/.github/workflows/bright-builds-auto-update.yml" 'gh secret set BRIGHT_BUILDS_PUSH_TOKEN -R ${{ github.repository }} < /Users/peterryszkiewicz/Repos/BRIGHT_BUILDS_PUSH_TOKEN.txt' "managed workflow should print the exact token repair command"
	assert_file_contains "${repo_path}/.github/workflows/bright-builds-auto-update.yml" 'gh workflow run bright-builds-auto-update.yml -R ${{ github.repository }}' "managed workflow should print the exact workflow dispatch command"
	assert_file_contains "${repo_path}/.github/workflows/bright-builds-auto-update.yml" 'gh run list -R ${{ github.repository }} --workflow bright-builds-auto-update.yml --limit 1' "managed workflow should print the exact run lookup command"
	assert_file_contains "${repo_path}/.github/workflows/bright-builds-auto-update.yml" 'gh run watch RUN_ID -R ${{ github.repository }} --exit-status' "managed workflow should print the exact run watch command"
	commit_all "$repo_path" "Initial managed install"
	git -C "$repo_path" push -u origin main >/dev/null
	printf '\n- Added direct-push update marker.\n' >>"${bundle_root}/templates/AGENTS.bright-builds.md"
	git -C "$bundle_root" add -A
	git -C "$bundle_root" commit -m "Bundle update" >/dev/null
	create_fake_curl_bin "$fake_bin" "$bundle_root"
	local_name_before="$(git -C "$repo_path" config --local user.name)"
	local_email_before="$(git -C "$repo_path" config --local user.email)"
	assert_eq "$local_name_before" "Test User" "direct-push auto-update should start with the repo-local user.name"
	assert_eq "$local_email_before" "test@example.com" "direct-push auto-update should start with the repo-local user.email"

	run_auto_update "$repo_path" "$fake_bin" "false"
	assert_eq "$run_status" "0" "direct-push auto-update should succeed"
	assert_contains "$run_output" "Pushed managed updates directly to main" "auto-update should report the direct push path"
	assert_markdown_dialect_fixture_hashes "$repo_path" "$config_hash" "$document_hash"
	changed_paths="$(git -C "$repo_path" diff --name-only HEAD^)"
	assert_not_contains "$changed_paths" ".mdformat.toml" "auto-update commit should not stage downstream formatter configuration"
	assert_not_contains "$changed_paths" "docs/PLAN.md" "auto-update commit should not stage arbitrary downstream Markdown"
	local_name_after="$(git -C "$repo_path" config --local user.name)"
	local_email_after="$(git -C "$repo_path" config --local user.email)"
	assert_eq "$local_name_after" "Test User" "direct-push auto-update should preserve the repo-local user.name"
	assert_eq "$local_email_after" "test@example.com" "direct-push auto-update should preserve the repo-local user.email"
	latest_author_name="$(git --git-dir="$remote_path" log --format=%an -1 refs/heads/main)"
	latest_author_email="$(git --git-dir="$remote_path" log --format=%ae -1 refs/heads/main)"
	assert_eq "$latest_author_name" "github-actions[bot]" "direct push should author the auto-update commit as github-actions[bot]"
	assert_eq "$latest_author_email" "41898282+github-actions[bot]@users.noreply.github.com" "direct push should author the auto-update commit with the GitHub Actions bot email"
	latest_subject="$(git --git-dir="$remote_path" log --format=%s -1 refs/heads/main)"
	assert_eq "$latest_subject" "chore: update Bright Builds Rules" "direct push should update the remote default branch"
}

test_refreshes_managed_standards_files() {
	local audit_hash=""
	local archive_hash=""
	local bundle_root=""
	local repo_path=""
	local remote_path=""
	local fake_bin=""
	local latest_subject=""
	local lessons_hash=""
	local over_budget_normal=""
	local over_budget_template=""
	local warning_budget_normal=""
	local warning_budget_template=""

	bundle_root="$(create_source_bundle standards-refresh)"
	write_legacy_checker_notice_literals "${bundle_root}/templates/bright-builds-check.ts"
	git -C "$bundle_root" add -A
	git -C "$bundle_root" commit -m "Old checker template" >/dev/null
	over_budget_normal='"NOTICE lessons active set exceeds the startup budget; use bounded whole-block loading and audit the ledger when required"'
	over_budget_template='`NOTICE lessons active set exceeds the startup budget; use bounded whole-block loading and audit the ledger when required`'
	warning_budget_normal='"NOTICE lessons active set is at least 75% of the startup budget; check whether the first-crossing audit trigger applies"'
	warning_budget_template='`NOTICE lessons active set is at least 75% of the startup budget; check whether the first-crossing audit trigger applies`'
	repo_path="$(create_repo standards-refresh-repo)"
	remote_path="$(create_bare_remote standards-refresh-origin)"
	fake_bin="${temp_root}/standards-refresh-bin"

	init_git_repo "$repo_path"
	git -C "$repo_path" remote add origin "https://github.com/example/standards-refresh.git"
	git -C "$repo_path" config \
		"url.file://${remote_path}.insteadOf" \
		"https://github.com/example/standards-refresh.git"
	install_auto_update_repo "$bundle_root" "$repo_path"
	assert_file_exists "${repo_path}/.github/workflows/bright-builds-checks.yml"
	assert_file_contains "${repo_path}/scripts/bright-builds-check.ts" "$over_budget_template" "fixture should start with the old over-budget template literal"
	assert_file_contains "${repo_path}/scripts/bright-builds-check.ts" "$warning_budget_template" "fixture should start with the old warning-budget template literal"
	write_file "${repo_path}/.codex/tasks/lessons.md" $'# Lessons\n\n## lesson-local | 2026-07-19\n\n1. Date: 2026-07-19\n2. What went wrong: Local fixture.\n3. Preventive rule: Preserve this file.\n4. Trigger signal: A managed update runs.\n'
	write_file "${repo_path}/.codex/tasks/lesson-audits.md" $'# Lesson Audits\n\n## lesson-audit-local | 2026-07-19\n\n- Retained: lesson-local\n'
	write_file "${repo_path}/.codex/tasks/lessons-archive.md" $'# Lesson Archive\n\n## lesson-archived-local | 2026-07-19\n\n- Archive reason: Fixture.\n'
	lessons_hash="$(git -C "$repo_path" hash-object .codex/tasks/lessons.md)"
	audit_hash="$(git -C "$repo_path" hash-object .codex/tasks/lesson-audits.md)"
	archive_hash="$(git -C "$repo_path" hash-object .codex/tasks/lessons-archive.md)"
	commit_all "$repo_path" "Initial managed install"
	git -C "$repo_path" push -u origin main >/dev/null
	cp "${repo_root}/templates/bright-builds-check.ts" "${bundle_root}/templates/bright-builds-check.ts"
	printf '\n- Added auto-update lesson-standard marker.\n' >>"${bundle_root}/standards/core/local-guidance.md"
	printf '\n- Added auto-update lesson-sidecar marker.\n' >>"${bundle_root}/templates/AGENTS.bright-builds.md"
	printf '\n// Added scheduled checker marker.\n' >>"${bundle_root}/templates/bright-builds-check.ts"
	printf '\n# Added scheduled checks-workflow marker.\n' >>"${bundle_root}/templates/bright-builds-checks.yml"
	git -C "$bundle_root" add -A
	git -C "$bundle_root" commit -m "Standards update" >/dev/null
	create_fake_curl_bin "$fake_bin" "$bundle_root"

	run_auto_update "$repo_path" "$fake_bin"
	assert_eq "$run_status" "0" "standards auto-update should succeed"
	assert_contains "$run_output" "Pushed managed updates directly to main" "standards auto-update should use the direct push path"
	assert_file_contains "${repo_path}/standards/core/local-guidance.md" "Added auto-update lesson-standard marker." "auto-update should refresh the managed lesson-loading standard"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "Added auto-update lesson-sidecar marker." "auto-update should refresh the managed lesson-loading sidecar"
	assert_file_contains "${repo_path}/scripts/bright-builds-check.ts" "Added scheduled checker marker." "auto-update should refresh the managed starter checker"
	assert_file_contains "${repo_path}/scripts/bright-builds-check.ts" "$over_budget_normal" "auto-update should install the lint-fixed over-budget notice"
	assert_file_contains "${repo_path}/scripts/bright-builds-check.ts" "$warning_budget_normal" "auto-update should install the lint-fixed warning-budget notice"
	assert_file_not_contains "${repo_path}/scripts/bright-builds-check.ts" "$over_budget_template" "auto-update should remove the old non-interpolated over-budget template literal"
	assert_file_not_contains "${repo_path}/scripts/bright-builds-check.ts" "$warning_budget_template" "auto-update should remove the old non-interpolated warning-budget template literal"
	assert_file_contains "${repo_path}/.github/workflows/bright-builds-checks.yml" "Added scheduled checks-workflow marker." "auto-update should refresh the managed checks workflow"
	assert_eq "$(git -C "$repo_path" hash-object .codex/tasks/lessons.md)" "$lessons_hash" "auto-update should preserve downstream lessons byte-for-byte"
	assert_eq "$(git -C "$repo_path" hash-object .codex/tasks/lesson-audits.md)" "$audit_hash" "auto-update should preserve downstream lesson audits byte-for-byte"
	assert_eq "$(git -C "$repo_path" hash-object .codex/tasks/lessons-archive.md)" "$archive_hash" "auto-update should preserve downstream lesson archives byte-for-byte"
	latest_subject="$(git --git-dir="$remote_path" log --format=%s -1 refs/heads/main)"
	assert_eq "$latest_subject" "chore: update Bright Builds Rules" "standards refresh should create the standard auto-update commit"
	if ! git --git-dir="$remote_path" show refs/heads/main:scripts/bright-builds-check.ts | grep -Fq "Added scheduled checker marker."; then
		fail "scheduled auto-update should commit the refreshed starter checker"
	fi
	if ! git --git-dir="$remote_path" show refs/heads/main:.github/workflows/bright-builds-checks.yml | grep -Fq "Added scheduled checks-workflow marker."; then
		fail "scheduled auto-update should commit the refreshed checks workflow"
	fi
}

test_auto_update_adds_directory_exception_support() {
	local allowlist_hash=""
	local current_bundle_root=""
	local fake_bin=""
	local old_bundle_root=""
	local remote_path=""
	local repo_path=""

	old_bundle_root="$(create_pre_directory_exception_source_bundle directory-exception-old)"
	current_bundle_root="$(create_source_bundle directory-exception-current)"
	repo_path="$(create_repo directory-exception-repo)"
	remote_path="$(create_bare_remote directory-exception-origin)"
	fake_bin="${temp_root}/directory-exception-bin"

	init_git_repo "$repo_path"
	git -C "$repo_path" remote add origin "$remote_path"
	install_auto_update_repo "$old_bundle_root" "$repo_path"
	replace_markdown_value "${repo_path}/bright-builds-rules.audit.md" "Exact commit" "$pre_directory_exception_ref"
	replace_markdown_value "${repo_path}/AGENTS.bright-builds.md" "Exact commit" "$pre_directory_exception_ref"
	mkdir -p "${repo_path}/external/vendor-sdk"
	printf 'line\n%.0s' {1..629} >"${repo_path}/external/vendor-sdk/library.ts"
	write_file \
		"${repo_path}/.bright-builds-rules-checks.tsv" \
		$'file-lengths\texternal/vendor-sdk/\tThird-party source maintained upstream\n'
	git -C "$repo_path" add -A
	allowlist_hash="$(git -C "$repo_path" hash-object .bright-builds-rules-checks.tsv)"

	set +e
	run_output="$(cd "$repo_path" && bun scripts/bright-builds-check.ts file-lengths 2>&1)"
	run_status=$?
	set -e
	assert_eq "$run_status" "1" "pre-directory-exception checker should prove the scheduled-update failure"
	assert_contains "$run_output" "FAIL file-lengths external/vendor-sdk/library.ts" "old scheduled checker should not understand directory exceptions"

	commit_all "$repo_path" "Initial managed install"
	git -C "$repo_path" push -u origin main >/dev/null
	create_fake_curl_bin \
		"$fake_bin" \
		"$current_bundle_root" \
		"$current_bundle_root" \
		"$current_bundle_root" \
		"" \
		"" \
		"$pre_directory_exception_ref" \
		"$old_bundle_root"

	run_auto_update "$repo_path" "$fake_bin"
	assert_eq "$run_status" "0" "auto-update should install directory exception support"
	assert_contains "$run_output" "Pushed managed updates directly to main" "directory exception update should use the direct push path"
	assert_eq "$(git -C "$repo_path" hash-object .bright-builds-rules-checks.tsv)" "$allowlist_hash" "auto-update should preserve the directory exception file byte-for-byte"

	set +e
	run_output="$(cd "$repo_path" && bun scripts/bright-builds-check.ts file-lengths 2>&1)"
	run_status=$?
	set -e
	assert_eq "$run_status" "0" "auto-updated checker should honor the directory exception"
	assert_contains "$run_output" "EXCEPTION file-lengths external/vendor-sdk/: excluded 1 tracked source files" "auto-updated checker should report the directory exception"
	assert_not_contains "$run_output" "FAIL file-lengths external/vendor-sdk/library.ts" "auto-updated checker should exclude third-party source"
}

test_legacy_helper_without_standards_staging_commits_backfilled_standards() {
	local old_bundle_root=""
	local current_bundle_root=""
	local repo_path=""
	local remote_path=""
	local fake_bin=""
	local commit_count=""
	local latest_subject=""

	old_bundle_root="$(create_pre_local_standards_source_bundle legacy-standards-shim-old)"
	current_bundle_root="$(create_source_bundle legacy-standards-shim-current)"
	repo_path="$(create_repo legacy-standards-shim-repo)"
	remote_path="$(create_bare_remote legacy-standards-shim-origin)"
	fake_bin="${temp_root}/legacy-standards-shim-bin"

	init_git_repo "$repo_path"
	git -C "$repo_path" remote add origin "$remote_path"
	install_auto_update_repo "$old_bundle_root" "$repo_path"
	write_file "${repo_path}/.gitignore" $'core\n'
	replace_markdown_value "${repo_path}/bright-builds-rules.audit.md" "Exact commit" "$pre_local_standards_ref"
	replace_markdown_value "${repo_path}/AGENTS.bright-builds.md" "Exact commit" "$pre_local_standards_ref"
	assert_file_not_contains "${repo_path}/scripts/bright-builds-auto-update.sh" "standards/languages/typescript-javascript.md" "fixture helper should lack standards staging"
	[[ ! -f "${repo_path}/standards/languages/typescript-javascript.md" ]] || fail "old fixture should not install local standards"
	commit_all "$repo_path" "Initial pre-local-standards managed install"
	git -C "$repo_path" push -u origin main >/dev/null
	create_fake_curl_bin "$fake_bin" "$current_bundle_root" "$old_bundle_root" "$current_bundle_root" "" "$old_bundle_root"

	run_auto_update "$repo_path" "$fake_bin" "legacy-unset"
	assert_eq "$run_status" "0" "legacy helper without standards staging should converge through the current manager"
	assert_contains "$run_output" "Repo state: installed" "legacy helper should classify the old clean install as installed"
	assert_contains "$run_output" "Legacy Bright Builds workflow notice" "current manager should warn legacy helpers before publishing a workflow change"
	assert_contains "$run_output" "gh secret set BRIGHT_BUILDS_PUSH_TOKEN -R bright-builds-llc/test-repo" "legacy helper advisory should include the exact secret repair command"
	assert_contains "$run_output" "Staged managed standards and starter checks for legacy auto-update helper compatibility." "current manager should stage standards and starter checks for the old helper"
	assert_contains "$run_output" "Pushed managed updates directly to main" "legacy helper should publish the converged update"
	assert_file_exists "${repo_path}/standards/languages/typescript-javascript.md"
	assert_file_exists "${repo_path}/scripts/bright-builds-check.ts"
	assert_file_contains "${repo_path}/CONTRIBUTING.md" "local managed standards pages" "update should refresh the old clean CONTRIBUTING block"
	assert_file_contains "${repo_path}/scripts/bright-builds-auto-update.sh" "print_audit_manifest_paths" "updated helper should use manifest-based staging"
	assert_file_contains "${repo_path}/bright-builds-rules.audit.md" "\`standards/languages/typescript-javascript.md\`" "updated audit should list managed standards"
	assert_file_contains "${repo_path}/bright-builds-rules.audit.md" "\`scripts/bright-builds-check.ts\`" "updated audit should list the managed starter checker"
	if ! git --git-dir="$remote_path" ls-tree -r --name-only refs/heads/main | grep -Fxq "standards/languages/typescript-javascript.md"; then
		fail "legacy helper update should commit the backfilled standards file"
	fi
	if ! git --git-dir="$remote_path" ls-tree -r --name-only refs/heads/main | grep -Fxq "standards/core/frontend-ui.md"; then
		fail "legacy helper update should force-add ignored managed standards/core files"
	fi
	if ! git --git-dir="$remote_path" ls-tree -r --name-only refs/heads/main | grep -Fxq "scripts/bright-builds-check.ts"; then
		fail "legacy helper update should commit the backfilled starter checker"
	fi
	commit_count="$(git -C "$repo_path" rev-list --count HEAD)"
	assert_eq "$commit_count" "2" "legacy helper standards convergence should create one update commit"
	latest_subject="$(git --git-dir="$remote_path" log --format=%s -1 refs/heads/main)"
	assert_eq "$latest_subject" "chore: update Bright Builds Rules" "legacy helper standards convergence should create the standard auto-update commit"
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
	local local_name_before=""
	local local_email_before=""
	local local_name_after=""
	local local_email_after=""

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
	local_name_before="$(git -C "$repo_path" config --local user.name)"
	local_email_before="$(git -C "$repo_path" config --local user.email)"
	assert_eq "$local_name_before" "Test User" "legacy helper auto-update should start with the repo-local user.name"
	assert_eq "$local_email_before" "test@example.com" "legacy helper auto-update should start with the repo-local user.email"

	run_auto_update "$repo_path" "$fake_bin"
	assert_eq "$run_status" "0" "legacy helper auto-update should succeed by migrating the install through the current manager"
	assert_contains "$run_output" "Repo state: installed" "legacy helper run should classify the repo as installed before migration"
	local_name_after="$(git -C "$repo_path" config --local user.name)"
	local_email_after="$(git -C "$repo_path" config --local user.email)"
	assert_eq "$local_name_after" "Test User" "legacy helper auto-update should preserve the repo-local user.name"
	assert_eq "$local_email_after" "test@example.com" "legacy helper auto-update should preserve the repo-local user.email"
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
