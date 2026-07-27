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
	assert_contains "$run_output" "Checks CI: disabled" "non-GitHub fresh repos should disable managed checks CI"
	assert_contains "$run_output" "Checks CI reason: non-GitHub repository" "fresh status should explain why checks CI is disabled"

	run_manage "$repo_path" install
	assert_eq "$run_status" "0" "fresh install should succeed"

	assert_file_exists "${repo_path}/AGENTS.md"
	assert_file_exists "${repo_path}/AGENTS.bright-builds.md"
	assert_file_exists "${repo_path}/CONTRIBUTING.md"
	assert_file_exists "${repo_path}/.github/pull_request_template.md"
	assert_file_exists "${repo_path}/bright-builds-rules.audit.md"
	assert_file_exists "${repo_path}/scripts/bright-builds-check.ts"
	assert_file_exists "${repo_path}/standards-overrides.md"
	assert_managed_standards_exist "$repo_path"
	assert_file_contains "${repo_path}/standards/languages/typescript-javascript.md" "Do Not Add Python Scripts To Bun-Friendly JS/TS Repositories" "fresh install should copy the TypeScript/JavaScript standards page"
	assert_file_contains "${repo_path}/standards/core/local-guidance.md" "## Load And Maintain Active Lessons Within A Bounded Context Budget" "fresh install should distribute the bounded lesson-loading standard"
	assert_file_contains "${repo_path}/standards/core/local-guidance.md" "24,000 bytes" "fresh install should distribute the default lesson byte budget"
	assert_file_contains "${repo_path}/standards/core/local-guidance.md" "8,000 tokens" "fresh install should distribute the default lesson token budget"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "Normal install and update must not create or edit downstream lesson, audit, or archive files." "fresh install should distribute the bounded lesson-loading sidecar summary"
	assert_file_missing "${repo_path}/tasks/lessons.md"
	assert_file_missing "${repo_path}/tasks/lesson-audits.md"
	assert_file_missing "${repo_path}/tasks/lessons-archive.md"
	assert_file_missing "${repo_path}/.codex/tasks/lessons.md"
	assert_file_missing "${repo_path}/.codex/tasks/lesson-audits.md"
	assert_file_missing "${repo_path}/.codex/tasks/lessons-archive.md"
	assert_file_missing "${repo_path}/README.md"
	assert_file_missing "${repo_path}/scripts/bright-builds-auto-update.sh"
	assert_file_missing "${repo_path}/.github/workflows/bright-builds-auto-update.yml"
	assert_file_missing "${repo_path}/.github/workflows/bright-builds-checks.yml"
	assert_file_missing "${repo_path}/.bright-builds-rules-checks.tsv"
	assert_markdown_is_mdformat_clean \
		"fresh install should write mdformat-clean downstream Markdown" \
		"${repo_path}/AGENTS.md" \
		"${repo_path}/AGENTS.bright-builds.md" \
		"${repo_path}/CONTRIBUTING.md" \
		"${repo_path}/.github/pull_request_template.md" \
		"${repo_path}/bright-builds-rules.audit.md" \
		"${repo_path}/standards-overrides.md" \
		"${repo_path}/standards/index.md" \
		"${repo_path}/standards/core/architecture.md" \
		"${repo_path}/standards/core/code-shape.md" \
		"${repo_path}/standards/core/frontend-ui.md" \
		"${repo_path}/standards/core/local-guidance.md" \
		"${repo_path}/standards/core/operability.md" \
		"${repo_path}/standards/core/testing.md" \
		"${repo_path}/standards/core/verification.md" \
		"${repo_path}/standards/languages/rust.md" \
		"${repo_path}/standards/languages/typescript-javascript.md"

	assert_file_contains "${repo_path}/AGENTS.md" "\`AGENTS.md\` is the entrypoint for repo-local instructions, not the complete Bright Builds Rules specification." "root AGENTS should define AGENTS as the local entrypoint rather than the full spec"
	assert_file_contains "${repo_path}/AGENTS.md" "This managed block is owned upstream by \`bright-builds-rules\`." "root AGENTS managed block should direct fixes upstream"
	assert_file_contains "${repo_path}/AGENTS.md" "Before plan, review, implementation, or audit work:" "root AGENTS should require the layered reading order"
	assert_file_contains "${repo_path}/AGENTS.md" "If you have not done that yet, stop and load those sources before continuing." "root AGENTS should require stop-and-load behavior before work"
	assert_file_contains "${repo_path}/AGENTS.md" "Use this routing map when deciding what to load next:" "root AGENTS should include the compact routing map"
	assert_file_contains "${repo_path}/AGENTS.md" "generated-file ownership, CI-only suites, or recurring workflow facts" "root AGENTS should route repo-local workflow questions back to local guidance"
	assert_file_contains "${repo_path}/AGENTS.md" "managed standards page \`standards/core/architecture.md\`" "root AGENTS should route architecture questions to the local standards page"
	assert_file_contains "${repo_path}/AGENTS.md" "managed standards page \`standards/core/frontend-ui.md\`" "root AGENTS should route frontend UI questions to the local standards page"
	assert_file_contains "${repo_path}/AGENTS.md" "managed standards page \`standards/core/testing.md\`" "root AGENTS should route unit-test expectations to the local standards page"
	assert_file_contains "${repo_path}/AGENTS.md" "matching managed standards page under \`standards/languages/\`" "root AGENTS should route language-specific questions to the local language pages"
	assert_file_contains "${repo_path}/AGENTS.md" "Keep recurring repo-specific workflow facts, commands, and links in a \`## Repo-Local Guidance\` section elsewhere in this file." "root AGENTS should direct repos to keep local guidance in AGENTS"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "Do not edit this file directly." "sidecar should contain the managed warning"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "installed from \`https://github.com/bright-builds-llc/bright-builds-rules\`" "sidecar should name the canonical source"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "If this managed file needs a fix, open an upstream PR or issue against \`bright-builds-rules\`" "sidecar should direct fixes upstream"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "Exact commit: \`${repo_exact_commit}\`" "sidecar should record the exact local commit"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "$(managed_file_marker "AGENTS.bright-builds.md")" "sidecar should include the whole-file managed marker"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "Record recurring repo-specific workflow facts in \`AGENTS.md\` under \`## Repo-Local Guidance\`" "sidecar should distinguish local guidance from standards overrides"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "\`AGENTS.md\` is the entrypoint for repo-local instructions, not a complete Bright Builds Rules spec." "sidecar should state that AGENTS is not the full Bright Builds Rules spec"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "before plan, review, implementation, or audit work." "sidecar should require loading standards sources before work"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "In plan, review, and audit outputs, briefly acknowledge which local guidance, sidecar, overrides, or standards pages materially informed the answer." "sidecar should require brief source acknowledgment for plan review and audit work"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "## Routing hints" "sidecar should include the compact routing section"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "Use this file, \`AGENTS.bright-builds.md\`, for the Bright Builds Rules default workflow" "sidecar should position itself as the detailed Bright Builds Rules layer"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "managed standards page \`standards/core/code-shape.md\`" "sidecar should route code-shape questions to the local code-shape page"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "managed standards page \`standards/core/frontend-ui.md\`" "sidecar should route frontend UI questions to the local frontend UI page"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "managed standards page \`standards/core/verification.md\`" "sidecar should route verification questions to the local verification page"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "matching managed standards page under \`standards/languages/\`" "sidecar should route language-specific questions to the local language pages"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "internal nullable or optional names with \`maybe\`" "sidecar should include the expanded maybe-prefix naming guidance"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "Frontend experiences should default to dark mode" "sidecar should include the frontend UI dark-mode guidance"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "New TypeScript/JavaScript web frontends should default to SolidJS" "sidecar should include the SolidJS frontend framework guidance"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "link public GitHub commits and CI run-backed build times when URLs are available" "sidecar should include linked UI provenance guidance"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "open external provenance links in new tabs safely" "sidecar should include safe new-tab provenance link guidance"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "copyable summaries as optional support affordances" "sidecar should include the UI provenance guidance"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "foreign-language logic inside strings" "sidecar should include the no-foreign-code-in-strings guidance"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "rerunnable when sensible" "sidecar should include the rerunnable script guidance"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "repo-defined gitignored location" "sidecar should point scripts at a repo-defined gitignored log location"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "Before substantive implementation work, sync first: fetch remote state before editing" "sidecar should include the pre-work checkout sync guidance"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "prefer rebasing onto the latest upstream or the repo's equivalent sync path" "sidecar should require rebase-first sync wording"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "if a worktree starts detached, assume the repo default branch, often \`main\`" "sidecar should include the detached-worktree default-branch hint"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "resolve any sync conflicts before proceeding" "sidecar should require conflict resolution before work"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "bootstrap or dependency-sync step when dependencies or tools may be stale" "sidecar should include dependency prep guidance"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "Before committing, run the relevant repo-native verification steps for the changed paths, including repository-compatible Markdown or shell formatter checks when supported tools are already available and local guidance does not define a clearer workflow, and do not commit if they fail." "sidecar should include the pass-before-commit verification rule"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "Prefer the repo's own verify/check/validate entrypoint when it exists" "sidecar should prefer repo-owned verification entrypoints"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "If hook-managed verification is detected and local docs are silent, ask before duplicating it manually." "sidecar should include the hook-aware prompting rule"
	assert_file_not_contains "${repo_path}/AGENTS.bright-builds.md" "openlinks-identity-presence" "non-matching owners should not receive the OpenLinks identity guidance"
	assert_file_contains "${repo_path}/CONTRIBUTING.md" "# Bright Builds Contribution Defaults" "CONTRIBUTING should include the managed contribution defaults heading"
	assert_file_contains "${repo_path}/CONTRIBUTING.md" "This managed block is owned upstream by \`bright-builds-rules\`." "CONTRIBUTING should direct fixes upstream through the managed block notice"
	assert_file_contains "${repo_path}/CONTRIBUTING.md" "Keep repo-local contribution guidance outside this managed block." "CONTRIBUTING should preserve local contribution guidance outside the managed block"
	assert_file_contains "${repo_path}/CONTRIBUTING.md" "Before plan, review, implementation, or audit work, read local \`AGENTS.md\`, \`AGENTS.bright-builds.md\`, \`standards-overrides.md\` when present, and the local managed standards pages relevant to the task; if that has not happened yet, stop and load them before continuing." "CONTRIBUTING should require the layered reading order"
	assert_file_contains "${repo_path}/CONTRIBUTING.md" "internal nullable or optional names with \`maybe\`" "CONTRIBUTING should include the expanded maybe-prefix naming guidance"
	assert_exact_line_count "${repo_path}/CONTRIBUTING.md" "$contributing_block_begin" "1"
	assert_exact_line_count "${repo_path}/CONTRIBUTING.md" "$contributing_block_end" "1"
	assert_file_not_contains "${repo_path}/CONTRIBUTING.md" "$(managed_file_marker "CONTRIBUTING.md")" "CONTRIBUTING should no longer use a whole-file managed marker"
	assert_file_contains "${repo_path}/CONTRIBUTING.md" "foreign-language logic inside strings" "CONTRIBUTING should include the no-foreign-code-in-strings guidance"
	assert_file_contains "${repo_path}/CONTRIBUTING.md" "rerunnable when sensible" "CONTRIBUTING should include the rerunnable script guidance"
	assert_file_contains "${repo_path}/CONTRIBUTING.md" "breadcrumb-heavy logs and summaries" "CONTRIBUTING should require breadcrumb-heavy logs and summaries"
	assert_file_contains "${repo_path}/CONTRIBUTING.md" "Before substantive implementation work, sync first: fetch remote state before editing" "CONTRIBUTING should require pre-work checkout sync"
	assert_file_contains "${repo_path}/CONTRIBUTING.md" "prefer rebasing onto the latest upstream or the repo's equivalent sync path" "CONTRIBUTING should prefer rebase-first sync wording"
	assert_file_contains "${repo_path}/CONTRIBUTING.md" "if a worktree starts detached, assume the repo default branch, often \`main\`" "CONTRIBUTING should include the detached-worktree default-branch hint"
	assert_file_contains "${repo_path}/CONTRIBUTING.md" "resolve any sync conflicts before proceeding" "CONTRIBUTING should require conflict resolution before work"
	assert_file_contains "${repo_path}/CONTRIBUTING.md" "bootstrap or dependency-sync step when dependencies or tools may be stale" "CONTRIBUTING should include dependency prep guidance"
	assert_file_contains "${repo_path}/CONTRIBUTING.md" "Before committing, run the relevant repo-native verification steps for the changed paths, including repository-compatible Markdown or shell formatter checks when supported tools are already available and local guidance does not define a clearer workflow, and do not commit if they fail." "CONTRIBUTING should require pass-before-commit verification"
	assert_file_contains "${repo_path}/CONTRIBUTING.md" "Heavy integration, end-to-end, or external-service suites may stay pre-push or CI-only" "CONTRIBUTING should allow documented CI-only heavy suites"
	assert_file_contains "${repo_path}/CONTRIBUTING.md" "briefly name the local guidance, sidecar, overrides, or standards pages that materially informed the work" "CONTRIBUTING should require brief source acknowledgment for standards-driven plan review and audit work"
	assert_file_contains "${repo_path}/.github/pull_request_template.md" "Relevant repo-native verification ran and passed when applicable" "PR template should use flexible verification wording"
	assert_file_contains "${repo_path}/.github/pull_request_template.md" "$(managed_file_marker ".github/pull_request_template.md")" "PR template should include the whole-file managed marker"
	assert_file_contains "${repo_path}/.github/pull_request_template.md" "This template is managed upstream by \`bright-builds-rules\`." "PR template should direct fixes upstream"
	assert_file_contains "${repo_path}/.github/pull_request_template.md" "Any CI-only or hook-owned verification exception is documented" "PR template should capture verification exceptions"
	assert_file_contains "${repo_path}/.github/pull_request_template.md" "briefly names the local guidance, sidecar, overrides, or standards pages that materially informed it" "PR template should require brief source acknowledgment when standards-driven plan review or audit work informed the change"
	assert_file_contains "${repo_path}/standards-overrides.md" "hook-owned or leaves heavy suites to CI" "overrides template should mention verification exceptions"
	assert_file_contains "${repo_path}/bright-builds-rules.audit.md" "Exact commit: \`${repo_exact_commit}\`" "audit trail should record the exact local commit"
	assert_file_contains "${repo_path}/bright-builds-rules.audit.md" "This audit trail is managed upstream by \`bright-builds-rules\`." "audit trail should direct fixes upstream"
	assert_file_contains "${repo_path}/bright-builds-rules.audit.md" "Auto-update: \`disabled\`" "audit trail should record the disabled auto-update setting"
	assert_file_contains "${repo_path}/bright-builds-rules.audit.md" "Auto-update reason: \`default disabled\`" "audit trail should record why auto-update stayed disabled"
	assert_file_contains "${repo_path}/bright-builds-rules.audit.md" "Checks CI: \`disabled\`" "audit trail should record disabled checks CI"
	assert_file_contains "${repo_path}/bright-builds-rules.audit.md" "Checks CI reason: \`non-GitHub repository\`" "audit trail should record the checks CI reason"
	assert_file_contains "${repo_path}/bright-builds-rules.audit.md" "\`scripts/bright-builds-check.ts\`" "audit trail should list the managed checker"
	assert_file_contains "${repo_path}/scripts/bright-builds-check.ts" "$(managed_file_marker "scripts/bright-builds-check.ts")" "checker should include the TypeScript whole-file marker"
	assert_file_contains "${repo_path}/bright-builds-rules.audit.md" "\`standards/languages/typescript-javascript.md\`" "audit trail should list the managed standards corpus"
	assert_file_contains "${repo_path}/bright-builds-rules.audit.md" "$(managed_file_marker "bright-builds-rules.audit.md")" "audit trail should include the whole-file managed marker"

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
	write_file "${repo_path}/CONTRIBUTING.md" $'# Local CONTRIBUTING\n\nLocal team guidance.\n'

	run_manage "$repo_path" status
	assert_eq "$run_status" "0" "existing AGENTS status should succeed"
	assert_contains "$run_output" "Repo state: installable" "existing local AGENTS and CONTRIBUTING files should still be installable"

	run_manage "$repo_path" install
	assert_eq "$run_status" "0" "install should append managed blocks to existing local AGENTS and CONTRIBUTING files"
	assert_file_contains "${repo_path}/AGENTS.md" "Keep this instruction." "local AGENTS content should remain"
	assert_exact_line_count "${repo_path}/AGENTS.md" "$agents_block_begin" "1"
	assert_exact_line_count "${repo_path}/AGENTS.md" "$agents_block_end" "1"
	assert_line_order "${repo_path}/AGENTS.md" "Keep this instruction." "$agents_block_begin"
	assert_file_contains "${repo_path}/CONTRIBUTING.md" "Local team guidance." "local CONTRIBUTING content should remain"
	assert_exact_line_count "${repo_path}/CONTRIBUTING.md" "$contributing_block_begin" "1"
	assert_exact_line_count "${repo_path}/CONTRIBUTING.md" "$contributing_block_end" "1"
	assert_line_order "${repo_path}/CONTRIBUTING.md" "Local team guidance." "$contributing_block_begin"
	assert_markdown_is_mdformat_clean \
		"install should append mdformat-clean managed AGENTS and CONTRIBUTING blocks" \
		"${repo_path}/AGENTS.md" \
		"${repo_path}/AGENTS.bright-builds.md" \
		"${repo_path}/CONTRIBUTING.md"
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
	assert_file_exists "${repo_path}/scripts/bright-builds-check.ts"
	assert_file_exists "${repo_path}/.github/workflows/bright-builds-checks.yml"
	assert_file_contains "${repo_path}/bright-builds-rules.audit.md" "Auto-update: \`enabled\`" "audit should record enabled auto-update"
	assert_file_contains "${repo_path}/bright-builds-rules.audit.md" "Auto-update reason: \`trusted repo owner pRizz\`" "audit should record the repo-owner trust decision"
	assert_file_contains "${repo_path}/bright-builds-rules.audit.md" "Checks CI: \`enabled\`" "GitHub-backed installs should record enabled checks CI"
	assert_file_contains "${repo_path}/.github/workflows/bright-builds-checks.yml" "bun scripts/bright-builds-check.ts all" "checks workflow should run the managed checker"
	assert_file_contains "${repo_path}/.github/workflows/bright-builds-checks.yml" "bun-version: \"1.3.9\"" "checks workflow should pin Bun"
	assert_command_succeeds \
		"installed starter checker should run successfully" \
		bash -c 'cd "$1" && bun scripts/bright-builds-check.ts all' _ "$repo_path"
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
	assert_auto_update_workflow_contains_repair_prompt "$repo_path"
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
	assert_file_contains "${repo_path}/bright-builds-rules.audit.md" "Auto-update reason: \`trusted GitHub user pRizz\`" "audit should record the GitHub-user trust decision"
}

test_managed_checks_conflicts_force_repair_and_uninstall() {
	local repo_path=""
	local conflict_repo_path=""
	local backup_file=""

	repo_path="$(create_repo managed-checks-lifecycle)"
	init_git_repo_with_origin "$repo_path" "git@github.com:someone-else/managed-checks-lifecycle.git"

	run_manage "$repo_path" install
	assert_eq "$run_status" "0" "GitHub-backed checks lifecycle install should succeed"
	assert_file_exists "${repo_path}/scripts/bright-builds-check.ts"
	assert_file_exists "${repo_path}/.github/workflows/bright-builds-checks.yml"

	append_file "${repo_path}/scripts/bright-builds-check.ts" $'\nconsole.log("downstream drift");\n'
	run_manage "$repo_path" status
	assert_eq "$run_status" "0" "drifted checker status should complete"
	assert_contains "$run_output" "Repo state: blocked" "a drifted managed checker should block updates"
	assert_contains "$run_output" "Blocking paths: scripts/bright-builds-check.ts" "status should identify the drifted checker"

	run_manage "$repo_path" install --force
	assert_eq "$run_status" "0" "force install should back up and repair a drifted checker"
	backup_file="$(find "${repo_path}/.bright-builds-rules-backups" -type f -path '*/scripts/bright-builds-check.ts' | head -n 1)"
	[[ -n "$backup_file" ]] || fail "force install should back up the drifted checker"
	assert_file_not_contains "${repo_path}/scripts/bright-builds-check.ts" "downstream drift" "force install should restore the managed checker"

	append_file "${repo_path}/.github/workflows/bright-builds-checks.yml" $'\n# downstream workflow drift\n'
	run_manage "$repo_path" status
	assert_eq "$run_status" "0" "drifted checks workflow status should complete"
	assert_contains "$run_output" "Repo state: blocked" "a drifted managed checks workflow should block updates"
	assert_contains "$run_output" ".github/workflows/bright-builds-checks.yml" "status should identify the drifted checks workflow"

	run_manage "$repo_path" install --force
	assert_eq "$run_status" "0" "force install should back up and repair a drifted checks workflow"
	backup_file="$(find "${repo_path}/.bright-builds-rules-backups" -type f -path '*/.github/workflows/bright-builds-checks.yml' | head -n 1)"
	[[ -n "$backup_file" ]] || fail "force install should back up the drifted checks workflow"
	assert_file_not_contains "${repo_path}/.github/workflows/bright-builds-checks.yml" "downstream workflow drift" "force install should restore the managed checks workflow"

	write_file \
		"${repo_path}/.bright-builds-rules-checks.tsv" \
		$'file-lengths\tscripts/bright-builds-check.ts\tTemporary local exception\n'
	run_manage "$repo_path" uninstall
	assert_eq "$run_status" "0" "uninstall should remove clean managed checks"
	assert_file_missing "${repo_path}/scripts/bright-builds-check.ts"
	assert_file_missing "${repo_path}/.github/workflows/bright-builds-checks.yml"
	assert_file_exists "${repo_path}/.bright-builds-rules-checks.tsv"

	conflict_repo_path="$(create_repo managed-checks-conflict)"
	init_git_repo_with_origin "$conflict_repo_path" "git@github.com:someone-else/managed-checks-conflict.git"
	write_file "${conflict_repo_path}/.github/workflows/bright-builds-checks.yml" $'name: Local checks\n'
	run_manage "$conflict_repo_path" status
	assert_eq "$run_status" "0" "checks workflow conflict status should complete"
	assert_contains "$run_output" "Repo state: blocked" "an existing checks workflow should block fresh install"
	assert_contains "$run_output" ".github/workflows/bright-builds-checks.yml" "status should identify the checks workflow conflict"
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
	assert_file_contains "${repo_path}/README.md" "Bright Builds: Rules" "Peter-owned repos should include the flat Bright Builds badge"
	assert_file_contains "${repo_path}/README.md" "OpenLinks profile" "Peter-owned repos should receive the owner-specific OpenLinks README badge"
	assert_line_order "${repo_path}/README.md" "GitHub Stars" "Bright Builds: Rules"
	assert_line_order "${repo_path}/README.md" "Bright Builds: Rules" "OpenLinks profile"
	assert_line_order "${repo_path}/README.md" "GitHub Stars" "OpenLinks profile"
	assert_markdown_is_mdformat_clean \
		"Peter-owned installs should keep AGENTS and README mdformat-clean" \
		"${repo_path}/AGENTS.md" \
		"${repo_path}/AGENTS.bright-builds.md" \
		"${repo_path}/README.md"
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
	assert_file_contains "${repo_path}/README.md" "Bright Builds: Rules" "Peter-owned repos should include the flat Bright Builds badge"
	assert_file_contains "${repo_path}/README.md" "public/badges/bright-builds-rules-flat.svg" "Peter-owned repos should use the flat Bright Builds badge path"
	assert_file_contains "${repo_path}/README.md" "OpenLinks profile" "Peter-owned repos should append the OpenLinks badge"
	assert_line_order "${repo_path}/README.md" "Vite 7.3.1" "Bright Builds: Rules"
	assert_line_order "${repo_path}/README.md" "Bright Builds: Rules" "OpenLinks profile"
	assert_line_order "${repo_path}/README.md" "Vite 7.3.1" "OpenLinks profile"
	assert_markdown_is_mdformat_clean \
		"owner-specific badge insertion should keep README and AGENTS mdformat-clean" \
		"${repo_path}/AGENTS.md" \
		"${repo_path}/AGENTS.bright-builds.md" \
		"${repo_path}/README.md"
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
	write_file "${repo_path}/.github/pull_request_template.md" $'# Local Pull Request Template\n'

	run_manage "$repo_path" status
	assert_eq "$run_status" "0" "blocked repo status should succeed"
	assert_contains "$run_output" "Repo state: blocked" "repo with conflicting managed files should be blocked"
	assert_contains "$run_output" "Recommended action: install --force" "blocked repo should recommend force install"
	assert_contains "$run_output" "Blocking paths: .github/pull_request_template.md" "blocked repo should list the managed conflict"

	run_manage "$repo_path" install
	assert_eq "$run_status" "1" "install should fail for blocked repos"
	assert_contains "$run_output" "Prefer fixing the managed source in bright-builds-rules via upstream PR or issue." "blocked install failure should steer users to upstream fixes"

	run_manage "$repo_path" install --force
	assert_eq "$run_status" "0" "force install should succeed"
	assert_contains "$run_output" "Legacy backup: .bright-builds-rules-backups/" "force install should report the backup root"

	backup_file="$(find "${repo_path}/.bright-builds-rules-backups" -type f -name 'pull_request_template.md' | head -n 1)"
	[[ -n "$backup_file" ]] || fail "expected force install to back up the PR template"

	assert_file_contains "${repo_path}/AGENTS.md" "# Local AGENTS" "force install should preserve an unmarked AGENTS.md"
	assert_exact_line_count "${repo_path}/AGENTS.md" "$agents_block_begin" "1"
	assert_file_contains "${repo_path}/.github/pull_request_template.md" "# Pull Request Template" "force install should replace the PR template with the managed template"
}

test_explicit_auto_update_disable_persists_across_update() {
	local repo_path=""

	repo_path="$(create_repo auto-update-disabled)"
	init_git_repo_with_origin "$repo_path" "git@github.com:bright-builds-llc/auto-update-disabled.git"

	run_manage "$repo_path" install --auto-update disabled
	assert_eq "$run_status" "0" "explicit disable install should succeed"
	assert_file_missing "${repo_path}/scripts/bright-builds-auto-update.sh"
	assert_file_missing "${repo_path}/.github/workflows/bright-builds-auto-update.yml"
	assert_file_contains "${repo_path}/bright-builds-rules.audit.md" "Auto-update: \`disabled\`" "audit should record the explicit disable"
	assert_file_contains "${repo_path}/bright-builds-rules.audit.md" "Auto-update reason: \`explicit\`" "audit should record the explicit override"

	run_manage "$repo_path" update
	assert_eq "$run_status" "0" "update should preserve an explicit disable without restating the flag"
	assert_file_missing "${repo_path}/scripts/bright-builds-auto-update.sh"
	assert_file_missing "${repo_path}/.github/workflows/bright-builds-auto-update.yml"
	assert_file_contains "${repo_path}/bright-builds-rules.audit.md" "Auto-update: \`disabled\`" "update should keep the disabled setting"
	assert_file_contains "${repo_path}/bright-builds-rules.audit.md" "Auto-update reason: \`explicit\`" "update should keep the explicit reason"
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
	assert_auto_update_workflow_contains_repair_prompt "$repo_path"
	assert_file_contains "${repo_path}/bright-builds-rules.audit.md" "Auto-update: \`enabled\`" "audit should keep the enabled state"
	assert_file_contains "${repo_path}/bright-builds-rules.audit.md" "Auto-update reason: \`explicit\`" "audit should keep the explicit enable reason"
}
