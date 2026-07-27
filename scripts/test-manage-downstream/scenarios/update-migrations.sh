test_update_preserves_local_agents_and_overrides() {
	local audit_hash=""
	local archive_hash=""
	local lessons_hash=""
	local repo_path=""

	repo_path="$(create_repo update)"
	write_file "${repo_path}/AGENTS.md" $'# Local AGENTS\n\n- Preserve this.\n'
	write_file "${repo_path}/.codex/tasks/lessons.md" $'# Lessons\n\n## lesson-local | 2026-07-19\n\n1. Date: 2026-07-19\n2. What went wrong: Local fixture.\n3. Preventive rule: Preserve this file.\n4. Trigger signal: A managed update runs.\n'
	write_file "${repo_path}/.codex/tasks/lesson-audits.md" $'# Lesson Audits\n\n## lesson-audit-local | 2026-07-19\n\n- Retained: lesson-local\n'
	write_file "${repo_path}/.codex/tasks/lessons-archive.md" $'# Lesson Archive\n\n## lesson-archived-local | 2026-07-19\n\n- Archive reason: Fixture.\n'
	lessons_hash="$(git -C "$repo_path" hash-object .codex/tasks/lessons.md)"
	audit_hash="$(git -C "$repo_path" hash-object .codex/tasks/lesson-audits.md)"
	archive_hash="$(git -C "$repo_path" hash-object .codex/tasks/lessons-archive.md)"

	run_manage "$repo_path" install
	assert_eq "$run_status" "0" "initial install should succeed before update"

	append_file "${repo_path}/CONTRIBUTING.md" $'\n## Local Contribution Notes\n\nKeep this local contribution rule.\n'
	printf '\n| `custom` | `keep it` | `local` | `owner` | `2026-03-13` |\n' >>"${repo_path}/standards-overrides.md"

	run_manage "$repo_path" status
	assert_eq "$run_status" "0" "status should succeed when CONTRIBUTING has local text outside the managed block"
	assert_contains "$run_output" "Repo state: installed" "local CONTRIBUTING text outside the managed block should not block status"

	run_manage "$repo_path" update --ref integration-test-ref
	assert_eq "$run_status" "0" "update should succeed for the marker-based layout"
	assert_file_contains "${repo_path}/AGENTS.md" "Preserve this." "update should keep local AGENTS content"
	assert_line_order "${repo_path}/AGENTS.md" "Preserve this." "$agents_block_begin"
	assert_exact_line_count "${repo_path}/AGENTS.md" "$agents_block_begin" "1"
	assert_file_contains "${repo_path}/CONTRIBUTING.md" "Keep this local contribution rule." "update should preserve local CONTRIBUTING text outside the managed block"
	assert_exact_line_count "${repo_path}/CONTRIBUTING.md" "$contributing_block_begin" "1"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "Version pin: \`integration-test-ref\`" "update should refresh managed files"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "Exact commit: \`${repo_exact_commit}\`" "update should preserve exact local provenance"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "Frontend experiences should default to dark mode" "update should keep the frontend UI guidance"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "New TypeScript/JavaScript web frontends should default to SolidJS" "update should keep the SolidJS frontend framework guidance"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "link public GitHub commits and CI run-backed build times when URLs are available" "update should keep linked UI provenance guidance"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "open external provenance links in new tabs safely" "update should keep safe new-tab provenance link guidance"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "copyable summaries as optional support affordances" "update should keep the UI provenance guidance"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "Normal install and update must not create or edit downstream lesson, audit, or archive files." "update should refresh the bounded lesson-loading sidecar summary"
	assert_file_contains "${repo_path}/standards/core/local-guidance.md" "## Load And Maintain Active Lessons Within A Bounded Context Budget" "update should refresh the bounded lesson-loading standard"
	assert_file_contains "${repo_path}/standards-overrides.md" "| \`custom\` | \`keep it\` | \`local\` | \`owner\` | \`2026-03-13\` |" "update should preserve local overrides"
	assert_eq "$(git -C "$repo_path" hash-object .codex/tasks/lessons.md)" "$lessons_hash" "update should preserve downstream lessons byte-for-byte"
	assert_eq "$(git -C "$repo_path" hash-object .codex/tasks/lesson-audits.md)" "$audit_hash" "update should preserve downstream lesson audits byte-for-byte"
	assert_eq "$(git -C "$repo_path" hash-object .codex/tasks/lessons-archive.md)" "$archive_hash" "update should preserve downstream lesson archives byte-for-byte"
	assert_markdown_is_mdformat_clean \
		"update should keep downstream AGENTS and CONTRIBUTING markdown mdformat-clean" \
		"${repo_path}/AGENTS.md" \
		"${repo_path}/AGENTS.bright-builds.md" \
		"${repo_path}/CONTRIBUTING.md"
}

test_update_backfills_missing_local_standards() {
	local repo_path=""

	repo_path="$(create_repo backfill-standards)"

	run_manage "$repo_path" install
	assert_eq "$run_status" "0" "backfill setup install should succeed"

	rm -rf "${repo_path}/standards"
	remove_standards_entries_from_audit "${repo_path}/bright-builds-rules.audit.md"

	run_manage "$repo_path" status
	assert_eq "$run_status" "0" "status should succeed for a pre-standards installed repo"
	assert_contains "$run_output" "Repo state: installed" "pre-standards installs should remain updateable"

	run_manage "$repo_path" update
	assert_eq "$run_status" "0" "update should backfill missing local standards"
	assert_managed_standards_exist "$repo_path"
	assert_file_exists "${repo_path}/scripts/bright-builds-check.ts"
	assert_file_missing "${repo_path}/.github/workflows/bright-builds-checks.yml"
	assert_file_contains "${repo_path}/bright-builds-rules.audit.md" "\`standards/languages/typescript-javascript.md\`" "update should add standards to the audit manifest"
	assert_file_contains "${repo_path}/bright-builds-rules.audit.md" "\`scripts/bright-builds-check.ts\`" "update should add the checker to the audit manifest"
	assert_file_contains "${repo_path}/bright-builds-rules.audit.md" "Checks CI: \`disabled\`" "non-GitHub updates should record disabled checks CI"
}

test_update_replaces_pre_lint_guard_checker_notices() {
	local installer_path=""
	local over_budget_normal=""
	local over_budget_template=""
	local repo_path=""
	local warning_budget_normal=""
	local warning_budget_template=""

	installer_path="$(create_pre_lint_guard_installer_bundle pre-lint-guard-checker)"
	repo_path="$(create_repo pre-lint-guard-checker)"
	over_budget_normal='"NOTICE lessons active set exceeds the startup budget; use bounded whole-block loading and audit the ledger when required"'
	over_budget_template='`NOTICE lessons active set exceeds the startup budget; use bounded whole-block loading and audit the ledger when required`'
	warning_budget_normal='"NOTICE lessons active set is at least 75% of the startup budget; check whether the first-crossing audit trigger applies"'
	warning_budget_template='`NOTICE lessons active set is at least 75% of the startup budget; check whether the first-crossing audit trigger applies`'

	run_manage_with_script "$installer_path" "$repo_path" install
	assert_eq "$run_status" "0" "pre-lint-guard checker fixture install should succeed"
	replace_markdown_value "${repo_path}/bright-builds-rules.audit.md" "Exact commit" "$pre_lint_guard_ref"
	replace_markdown_value "${repo_path}/AGENTS.bright-builds.md" "Exact commit" "$pre_lint_guard_ref"
	assert_file_contains "${repo_path}/scripts/bright-builds-check.ts" "$over_budget_template" "fixture should start with the old over-budget template literal"
	assert_file_contains "${repo_path}/scripts/bright-builds-check.ts" "$warning_budget_template" "fixture should start with the old warning-budget template literal"

	run_manage "$repo_path" status
	assert_eq "$run_status" "0" "status should succeed for a clean pre-lint-guard checker"
	assert_contains "$run_output" "Repo state: installed" "clean pre-lint-guard checkers should remain updateable"
	assert_not_contains "$run_output" "Blocking paths: scripts/bright-builds-check.ts" "clean pre-lint-guard checkers should not be treated as drift"

	run_manage "$repo_path" update
	assert_eq "$run_status" "0" "update should refresh a clean pre-lint-guard checker"
	assert_file_contains "${repo_path}/scripts/bright-builds-check.ts" "$over_budget_normal" "update should install the lint-fixed over-budget notice"
	assert_file_contains "${repo_path}/scripts/bright-builds-check.ts" "$warning_budget_normal" "update should install the lint-fixed warning-budget notice"
	assert_file_not_contains "${repo_path}/scripts/bright-builds-check.ts" "$over_budget_template" "update should remove the old over-budget template literal"
	assert_file_not_contains "${repo_path}/scripts/bright-builds-check.ts" "$warning_budget_template" "update should remove the old warning-budget template literal"
}

test_update_adds_directory_exception_support() {
	local allowlist_hash=""
	local current_installer_path=""
	local installer_path=""
	local repo_path=""

	installer_path="$(create_pre_directory_exception_installer_bundle pre-directory-exception)"
	current_installer_path="$(create_history_aware_current_installer_bundle current-directory-exception)"
	repo_path="$(create_repo pre-directory-exception)"
	git -C "$repo_path" init >/dev/null 2>&1

	run_manage_with_script "$installer_path" "$repo_path" install
	assert_eq "$run_status" "0" "pre-directory-exception install should succeed"
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
	assert_eq "$run_status" "1" "pre-directory-exception checker should prove the legacy failure"
	assert_contains "$run_output" "FAIL file-lengths external/vendor-sdk/library.ts" "legacy checker should not understand directory exceptions"

	run_manage_with_script "$current_installer_path" "$repo_path" status
	assert_eq "$run_status" "0" "status should recognize a clean pre-directory-exception install"
	assert_contains "$run_output" "Repo state: installed" "pre-directory-exception install should remain updateable"
	run_manage_with_script "$current_installer_path" "$repo_path" update
	assert_eq "$run_status" "0" "update should install directory exception support"
	assert_eq "$(git -C "$repo_path" hash-object .bright-builds-rules-checks.tsv)" "$allowlist_hash" "update should preserve the directory exception file byte-for-byte"

	set +e
	run_output="$(cd "$repo_path" && bun scripts/bright-builds-check.ts file-lengths 2>&1)"
	run_status=$?
	set -e
	assert_eq "$run_status" "0" "updated checker should honor the directory exception"
	assert_contains "$run_output" "EXCEPTION file-lengths external/vendor-sdk/: excluded 1 tracked source files" "updated checker should report the directory exception"
	assert_not_contains "$run_output" "FAIL file-lengths external/vendor-sdk/library.ts" "updated checker should exclude third-party source"
}

test_pre_frontend_ui_audit_manifest_remains_updateable() {
	local repo_path=""

	repo_path="$(create_repo pre-frontend-ui)"
	init_git_repo_with_origin "$repo_path" "git@github.com:bright-builds-llc/pre-frontend-ui.git"
	write_file "${repo_path}/package.json" $'{\n  "devDependencies": {\n    "typescript": "5.9.2"\n  }\n}\n'

	run_manage "$repo_path" install --auto-update enabled
	assert_eq "$run_status" "0" "pre-frontend-ui setup install should succeed"

	rm -f "${repo_path}/standards/core/frontend-ui.md"
	remove_audit_entry "${repo_path}/bright-builds-rules.audit.md" "standards/core/frontend-ui.md"

	run_manage "$repo_path" status
	assert_eq "$run_status" "0" "status should succeed for a pre-frontend-ui audit manifest"
	assert_contains "$run_output" "Repo state: installed" "pre-frontend-ui audit manifests should remain updateable"
	assert_not_contains "$run_output" "Blocking paths: bright-builds-rules.audit.md" "pre-frontend-ui audit manifests should not be treated as drift"

	run_manage "$repo_path" update
	assert_eq "$run_status" "0" "update should backfill the frontend UI standards page"
	assert_file_exists "${repo_path}/standards/core/frontend-ui.md"
	assert_file_contains "${repo_path}/bright-builds-rules.audit.md" "\`standards/core/frontend-ui.md\`" "update should add frontend UI standards to the audit manifest"
}

test_managed_markdown_status_and_update_bootstrap_mdformat_in_github_actions() {
	local bootstrap_log=""
	local fake_bin=""
	local repo_path=""
	local path_without_mdformat=""

	repo_path="$(create_repo github-actions-mdformat-bootstrap)"
	fake_bin="${temp_root}/github-actions-mdformat-bootstrap-bin"
	bootstrap_log="${temp_root}/github-actions-mdformat-bootstrap.log"

	run_manage "$repo_path" install
	assert_eq "$run_status" "0" "mdformat bootstrap setup install should succeed"

	create_fake_python_mdformat_bootstrap_bin "$fake_bin" "$bootstrap_log"
	path_without_mdformat="${fake_bin}:$(path_without_command_dir mdformat)"
	if env PATH="$path_without_mdformat" "$BASH" -c 'command -v mdformat >/dev/null 2>&1'; then
		fail "test setup failed to remove mdformat from PATH"
	fi

	set +e
	run_output="$(env GITHUB_ACTIONS=true PATH="$path_without_mdformat" "$BASH" "$script_path" status --repo-root "$repo_path" 2>&1)"
	run_status=$?
	set -e
	assert_eq "$run_status" "0" "GitHub Actions status should bootstrap mdformat"
	assert_contains "$run_output" "Repo state: installed" "clean managed Markdown should remain installed after bootstrapping mdformat"
	assert_not_contains "$run_output" "Blocking paths: AGENTS.bright-builds.md" "clean sidecar should not block after bootstrapping mdformat"
	assert_file_contains "$bootstrap_log" "mdformat==1.0.0" "manager bootstrap should install the pinned mdformat version"
	assert_file_contains "$bootstrap_log" "mdformat-frontmatter==2.1.2" "manager bootstrap should install the pinned frontmatter extension"
	assert_file_contains "$bootstrap_log" "mdformat-gfm==1.0.0" "manager bootstrap should install the pinned GFM extension"

	set +e
	run_output="$(env GITHUB_ACTIONS=true PATH="$path_without_mdformat" "$BASH" "$script_path" update --repo-root "$repo_path" 2>&1)"
	run_status=$?
	set -e
	assert_eq "$run_status" "0" "GitHub Actions update should bootstrap mdformat"

	replace_exact_line \
		"${repo_path}/AGENTS.bright-builds.md" \
		"Do not edit this file directly." \
		"Do not edit this file directly. Drift."

	set +e
	run_output="$(env GITHUB_ACTIONS=true PATH="$path_without_mdformat" "$BASH" "$script_path" status --repo-root "$repo_path" 2>&1)"
	run_status=$?
	set -e
	assert_eq "$run_status" "0" "drift status after mdformat bootstrap should still complete"
	assert_contains "$run_output" "Repo state: blocked" "real managed Markdown drift should still block after mdformat bootstrap"
	assert_contains "$run_output" "Blocking paths: AGENTS.bright-builds.md" "real sidecar drift should still name the sidecar"
}

test_pre_local_standards_contributing_block_remains_updateable() {
	local installer_path=""
	local repo_path=""
	local drift_repo_path=""

	installer_path="$(create_pre_local_standards_installer_bundle pre-local-standards)"
	repo_path="$(create_repo pre-local-standards)"

	run_manage_with_script "$installer_path" "$repo_path" install
	assert_eq "$run_status" "0" "pre-local-standards fixture install should succeed"
	replace_markdown_value "${repo_path}/bright-builds-rules.audit.md" "Exact commit" "$pre_local_standards_ref"
	replace_markdown_value "${repo_path}/AGENTS.bright-builds.md" "Exact commit" "$pre_local_standards_ref"
	assert_managed_standards_missing "$repo_path"
	assert_file_contains "${repo_path}/CONTRIBUTING.md" "pinned canonical standards pages" "fixture should use the old clean CONTRIBUTING block"

	run_manage "$repo_path" status
	assert_eq "$run_status" "0" "status should succeed for a clean old CONTRIBUTING block"
	assert_contains "$run_output" "Repo state: installed" "clean old CONTRIBUTING blocks should remain updateable"
	assert_not_contains "$run_output" "Blocking paths: CONTRIBUTING.md" "clean old CONTRIBUTING blocks should not block status"

	run_manage "$repo_path" update
	assert_eq "$run_status" "0" "update should refresh a clean old CONTRIBUTING block and backfill standards"
	assert_managed_standards_exist "$repo_path"
	assert_file_contains "${repo_path}/CONTRIBUTING.md" "local managed standards pages" "update should refresh CONTRIBUTING to the current block"
	assert_file_contains "${repo_path}/bright-builds-rules.audit.md" "\`standards/languages/typescript-javascript.md\`" "update should add standards to the audit manifest"

	drift_repo_path="$(create_repo pre-local-standards-drifted)"
	run_manage_with_script "$installer_path" "$drift_repo_path" install
	assert_eq "$run_status" "0" "drifted pre-local-standards fixture install should succeed"
	replace_markdown_value "${drift_repo_path}/bright-builds-rules.audit.md" "Exact commit" "$pre_local_standards_ref"
	replace_markdown_value "${drift_repo_path}/AGENTS.bright-builds.md" "Exact commit" "$pre_local_standards_ref"
	replace_exact_line \
		"${drift_repo_path}/CONTRIBUTING.md" \
		"- Use the pinned version of the central standards repository as the canonical reference." \
		"- Use downstream edits inside the old managed block."

	run_manage "$drift_repo_path" status
	assert_eq "$run_status" "0" "status should succeed for a drifted old CONTRIBUTING block"
	assert_contains "$run_output" "Repo state: blocked" "edited old CONTRIBUTING blocks should still block status"
	assert_contains "$run_output" "Blocking paths: CONTRIBUTING.md" "status should list the edited old CONTRIBUTING block"
}

test_pre_prompt_auto_update_workflow_remains_updateable() {
	local installer_path=""
	local repo_path=""

	installer_path="$(create_pre_local_standards_installer_bundle pre-prompt-auto-update)"
	repo_path="$(create_repo pre-prompt-auto-update)"

	run_manage_with_script "$installer_path" "$repo_path" install --auto-update enabled
	assert_eq "$run_status" "0" "pre-prompt auto-update fixture install should succeed"
	replace_markdown_value "${repo_path}/bright-builds-rules.audit.md" "Exact commit" "$pre_local_standards_ref"
	replace_markdown_value "${repo_path}/AGENTS.bright-builds.md" "Exact commit" "$pre_local_standards_ref"
	assert_file_exists "${repo_path}/.github/workflows/bright-builds-auto-update.yml"
	assert_file_not_contains "${repo_path}/.github/workflows/bright-builds-auto-update.yml" 'if: ${{ failure() }}' "fixture workflow should not yet include the failure repair prompt"

	run_manage "$repo_path" status
	assert_eq "$run_status" "0" "status should succeed for a clean pre-prompt auto-update workflow"
	assert_contains "$run_output" "Repo state: installed" "clean pre-prompt auto-update workflows should remain updateable"
	assert_not_contains "$run_output" "Repo state: blocked" "clean pre-prompt auto-update workflows should not be blocked"
	assert_not_contains "$run_output" "Blocking paths: .github/workflows/bright-builds-auto-update.yml" "clean pre-prompt auto-update workflows should not be treated as drift"

	run_manage "$repo_path" update
	assert_eq "$run_status" "0" "update should refresh a clean pre-prompt auto-update workflow"
	assert_auto_update_workflow_contains_repair_prompt "$repo_path"
}

test_existing_unmanaged_standards_file_blocks_install_until_force() {
	local repo_path=""
	local backup_file=""

	repo_path="$(create_repo unmanaged-standards-conflict)"
	write_file "${repo_path}/standards/languages/typescript-javascript.md" $'# Local TypeScript Rules\n\nKeep this local file.\n'

	run_manage "$repo_path" status
	assert_eq "$run_status" "0" "status should succeed with an unmanaged standards conflict"
	assert_contains "$run_output" "Repo state: blocked" "unmanaged standards conflicts should block install"
	assert_contains "$run_output" "Blocking paths: standards/languages/typescript-javascript.md" "status should list the conflicting standards path"

	run_manage "$repo_path" install
	assert_eq "$run_status" "1" "install should fail until the standards conflict is explicitly forced"

	run_manage "$repo_path" install --force
	assert_eq "$run_status" "0" "force install should replace conflicting standards files"
	backup_file="$(find "${repo_path}/.bright-builds-rules-backups" -type f -path '*/standards/languages/typescript-javascript.md' | head -n 1)"
	[[ -n "$backup_file" ]] || fail "expected force install to back up the conflicting standards file"
	assert_file_contains "$backup_file" "Keep this local file." "backup should preserve the conflicting local standards content"
	assert_file_contains "${repo_path}/standards/languages/typescript-javascript.md" "Do Not Add Python Scripts To Bun-Friendly JS/TS Repositories" "force install should write the managed TypeScript/JavaScript standards"
}

test_current_whole_file_contributing_install_is_installed_and_update_migrates() {
	local repo_path=""
	local managed_files_markdown=""

	repo_path="$(create_repo current-whole-file-contributing)"

	run_manage "$repo_path" install
	assert_eq "$run_status" "0" "current whole-file migration setup install should succeed"

	managed_files_markdown=$'- `AGENTS.md (managed block)`\n- `AGENTS.bright-builds.md`\n- `CONTRIBUTING.md`\n- `.github/pull_request_template.md`\n- `bright-builds-rules.audit.md`'
	render_current_whole_file_contributing_compat "${repo_path}/CONTRIBUTING.md"
	render_current_whole_file_audit_compat "${repo_path}/bright-builds-rules.audit.md" "main" "$repo_exact_commit" "bright-builds-rules.audit.md" "disabled" "default disabled" "install" "2026-04-11T00:00:00Z" "$managed_files_markdown"

	run_manage "$repo_path" status
	assert_eq "$run_status" "0" "status should succeed for a current clean whole-file CONTRIBUTING install"
	assert_contains "$run_output" "Repo state: installed" "current clean whole-file CONTRIBUTING installs should still count as installed"
	assert_not_contains "$run_output" "Blocking paths: CONTRIBUTING.md" "current clean whole-file CONTRIBUTING installs should not block status"

	run_manage "$repo_path" update
	assert_eq "$run_status" "0" "update should migrate a current clean whole-file CONTRIBUTING install"
	assert_exact_line_count "${repo_path}/CONTRIBUTING.md" "$contributing_block_begin" "1"
	assert_exact_line_count "${repo_path}/CONTRIBUTING.md" "$contributing_block_end" "1"
	assert_file_not_contains "${repo_path}/CONTRIBUTING.md" "$(managed_file_marker "CONTRIBUTING.md")" "update should remove the old CONTRIBUTING whole-file marker"
	assert_file_contains "${repo_path}/bright-builds-rules.audit.md" "CONTRIBUTING.md (managed block)" "audit should describe CONTRIBUTING as a managed block after migration"
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
	assert_exact_line_count "${repo_path}/CONTRIBUTING.md" "$contributing_block_begin" "1"
	assert_exact_line_count "${repo_path}/CONTRIBUTING.md" "$contributing_block_end" "1"
	assert_file_not_contains "${repo_path}/CONTRIBUTING.md" "$(managed_file_marker "CONTRIBUTING.md")" "update should migrate CONTRIBUTING to the bounded-block format"
	assert_file_contains "${repo_path}/.github/pull_request_template.md" "$(managed_file_marker ".github/pull_request_template.md")" "update should restore the PR template whole-file marker"
	assert_file_contains "${repo_path}/bright-builds-rules.audit.md" "$(managed_file_marker "bright-builds-rules.audit.md")" "update should restore the audit whole-file marker"
	assert_line_equals "${repo_path}/scripts/bright-builds-auto-update.sh" "2" "$(managed_file_marker "scripts/bright-builds-auto-update.sh")" "update should restore the auto-update helper whole-file marker"
	assert_line_equals "${repo_path}/.github/workflows/bright-builds-auto-update.yml" "1" "$(managed_file_marker ".github/workflows/bright-builds-auto-update.yml")" "update should restore the auto-update workflow whole-file marker"
	assert_auto_update_workflow_contains_repair_prompt "$repo_path"
}

test_drifted_contributing_block_blocks_update_and_force_repairs() {
	local repo_path=""
	local backup_file=""

	repo_path="$(create_repo drifted-contributing-block)"

	run_manage "$repo_path" install
	assert_eq "$run_status" "0" "drifted CONTRIBUTING block setup install should succeed"

	replace_exact_line \
		"${repo_path}/CONTRIBUTING.md" \
		"- Prefer simple, root-cause fixes over broad rewrites." \
		"- Prefer downstream rewrites over the managed block."

	run_manage "$repo_path" status
	assert_eq "$run_status" "0" "drifted CONTRIBUTING block status should succeed"
	assert_contains "$run_output" "Repo state: blocked" "drifted CONTRIBUTING blocks should block the repo"
	assert_contains "$run_output" "Blocking paths: CONTRIBUTING.md" "status should list the drifted CONTRIBUTING block"

	run_manage "$repo_path" update
	assert_eq "$run_status" "1" "update should fail when the managed CONTRIBUTING block has downstream edits"

	run_manage "$repo_path" install --force
	assert_eq "$run_status" "0" "force install should repair a drifted CONTRIBUTING block"
	backup_file="$(find "${repo_path}/.bright-builds-rules-backups" -type f -name 'CONTRIBUTING.md' | head -n 1)"
	[[ -n "$backup_file" ]] || fail "expected force install to back up the drifted CONTRIBUTING.md"
	assert_exact_line_count "${repo_path}/CONTRIBUTING.md" "$contributing_block_begin" "1"
	assert_exact_line_count "${repo_path}/CONTRIBUTING.md" "$contributing_block_end" "1"
	assert_file_not_contains "${repo_path}/CONTRIBUTING.md" "Prefer downstream rewrites over the managed block." "force install should remove the drifted local block edit"
}

test_prerename_clean_install_is_installed_and_update_migrates_legacy_layout() {
	local repo_path=""
	local installer_path=""

	repo_path="$(create_repo prerename-clean-install)"
	installer_path="$(create_legacy_installer_bundle prerename-clean-install)"
	write_file "${repo_path}/README.md" $'# Legacy App\n\nBody text remains.\n'
	write_file "${repo_path}/package.json" $'{\n  "devDependencies": {\n    "typescript": "5.9.2"\n  }\n}\n'

	run_manage_with_script "$installer_path" "$repo_path" install --auto-update enabled
	assert_eq "$run_status" "0" "legacy installer setup should succeed"
	assert_file_exists "${repo_path}/${legacy_audit_destination}"
	assert_file_contains "${repo_path}/AGENTS.md" "$legacy_agents_block_begin" "legacy install should use the old AGENTS markers"
	assert_file_contains "${repo_path}/README.md" "$legacy_readme_badges_begin" "legacy install should use the old README badge markers"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "$(legacy_managed_file_marker "AGENTS.bright-builds.md")" "legacy install should use the old whole-file marker prefix"

	run_manage "$repo_path" status
	assert_eq "$run_status" "0" "status should succeed for a clean pre-rename install"
	assert_contains "$run_output" "Repo state: installed" "clean pre-rename installs should be treated as installed"
	assert_contains "$run_output" "Recommended action: update" "clean pre-rename installs should recommend update"
	assert_not_contains "$run_output" "Repo state: blocked" "clean pre-rename installs should not be blocked"
	assert_not_contains "$run_output" "Blocking paths:" "clean pre-rename installs should not report blocking paths"
	assert_contains "$run_output" "Audit trail: ${legacy_audit_destination}" "status should surface the legacy audit trail before migration"
	assert_contains "$run_output" "Auto-update: enabled" "status should preserve auto-update state from the legacy audit trail"

	run_manage "$repo_path" update
	assert_eq "$run_status" "0" "update should migrate a clean pre-rename install in place"
	assert_file_missing "${repo_path}/${legacy_audit_destination}"
	assert_file_exists "${repo_path}/bright-builds-rules.audit.md"
	assert_file_not_contains "${repo_path}/AGENTS.md" "$legacy_agents_block_begin" "update should remove the old AGENTS marker family"
	assert_file_contains "${repo_path}/AGENTS.md" "$agents_block_begin" "update should install the new AGENTS marker family"
	assert_file_not_contains "${repo_path}/README.md" "$legacy_readme_badges_begin" "update should remove the old README badge marker family"
	assert_file_contains "${repo_path}/README.md" "$readme_badges_begin" "update should install the new README badge marker family"
	assert_file_not_contains "${repo_path}/AGENTS.bright-builds.md" "$(legacy_managed_file_marker "AGENTS.bright-builds.md")" "update should remove the old whole-file marker prefix from the sidecar"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "$(managed_file_marker "AGENTS.bright-builds.md")" "update should rewrite the sidecar to the new whole-file marker prefix"
	assert_exact_line_count "${repo_path}/CONTRIBUTING.md" "$contributing_block_begin" "1"
	assert_exact_line_count "${repo_path}/CONTRIBUTING.md" "$contributing_block_end" "1"
	assert_file_not_contains "${repo_path}/CONTRIBUTING.md" "$(legacy_managed_file_marker "CONTRIBUTING.md")" "update should rewrite CONTRIBUTING into the new bounded-block format"
	assert_line_equals "${repo_path}/scripts/bright-builds-auto-update.sh" "2" "$(managed_file_marker "scripts/bright-builds-auto-update.sh")" "update should rewrite the helper to the new whole-file marker prefix"
	assert_file_contains "${repo_path}/bright-builds-rules.audit.md" "Source repository: \`https://github.com/bright-builds-llc/bright-builds-rules\`" "migration should rewrite the audit source repository to the new canonical repo"
	assert_file_contains "${repo_path}/bright-builds-rules.audit.md" "Auto-update: \`enabled\`" "migration should preserve auto-update state in the new audit file"
	assert_file_contains "${repo_path}/README.md" "TypeScript 5.9.2" "migration should preserve README badge detection while rewriting marker families"
	assert_file_contains "${repo_path}/README.md" "Bright Builds: Rules" "migration should preserve the managed Bright Builds badge after rewriting the README block"
	assert_file_contains "${repo_path}/README.md" "Body text remains." "migration should preserve README content outside managed regions"
	assert_markdown_is_mdformat_clean \
		"legacy layout migration should keep rewritten downstream Markdown mdformat-clean" \
		"${repo_path}/AGENTS.md" \
		"${repo_path}/AGENTS.bright-builds.md" \
		"${repo_path}/CONTRIBUTING.md" \
		"${repo_path}/README.md"
}
