test_old_standalone_install_is_blocked() {
	local repo_path=""

	repo_path="$(create_repo old-standalone)"
	write_file "${repo_path}/AGENTS.md" $'# AGENTS.md\n\nUse this file as the thin local adoption layer in a downstream repository.\n'
	write_file "${repo_path}/CONTRIBUTING.md" $'# CONTRIBUTING.md\n'
	write_file "${repo_path}/.github/pull_request_template.md" $'# Pull Request Template\n'
	write_file "${repo_path}/bright-builds-rules.audit.md" $'# Audit Trail\n'

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
	printf '\n| `custom` | `still here` | `local` | `owner` | `2026-03-13` |\n' >>"${repo_path}/standards-overrides.md"

	run_manage "$repo_path" uninstall
	assert_eq "$run_status" "0" "uninstall should succeed"
	assert_file_exists "${repo_path}/AGENTS.md"
	assert_file_contains "${repo_path}/AGENTS.md" "Keep me." "uninstall should keep local AGENTS content"
	assert_file_not_contains "${repo_path}/AGENTS.md" "$agents_block_begin" "uninstall should remove the managed AGENTS block"
	assert_file_missing "${repo_path}/AGENTS.bright-builds.md"
	assert_file_missing "${repo_path}/CONTRIBUTING.md"
	assert_file_missing "${repo_path}/.github/pull_request_template.md"
	assert_file_missing "${repo_path}/bright-builds-rules.audit.md"
	assert_managed_standards_missing "$repo_path"
	assert_file_exists "${repo_path}/standards-overrides.md"
	assert_file_contains "${repo_path}/standards-overrides.md" "| \`custom\` | \`still here\` | \`local\` | \`owner\` | \`2026-03-13\` |" "uninstall should preserve overrides"
}

test_uninstall_preserves_drifted_whole_file_managed_files() {
	local repo_path=""

	repo_path="$(create_repo uninstall-drifted-managed)"

	run_manage "$repo_path" install --auto-update enabled
	assert_eq "$run_status" "0" "install should succeed before drift-preserving uninstall"

	replace_exact_line \
		"${repo_path}/CONTRIBUTING.md" \
		"- Prefer simple, root-cause fixes over broad rewrites." \
		"- Keep this downstream change inside the managed block."
	printf '\nprintf drifted-helper\n' >>"${repo_path}/scripts/bright-builds-auto-update.sh"

	run_manage "$repo_path" uninstall
	assert_eq "$run_status" "0" "uninstall should succeed when drifted managed files are present"
	assert_file_missing "${repo_path}/AGENTS.md"
	assert_file_missing "${repo_path}/AGENTS.bright-builds.md"
	assert_file_missing "${repo_path}/.github/pull_request_template.md"
	assert_file_missing "${repo_path}/bright-builds-rules.audit.md"
	assert_file_missing "${repo_path}/.github/workflows/bright-builds-auto-update.yml"
	assert_managed_standards_missing "$repo_path"
	assert_file_exists "${repo_path}/CONTRIBUTING.md"
	assert_file_exists "${repo_path}/scripts/bright-builds-auto-update.sh"
	assert_file_contains "${repo_path}/CONTRIBUTING.md" "Keep this downstream change inside the managed block." "uninstall should preserve drifted CONTRIBUTING content"
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
	assert_managed_standards_missing "$repo_path"
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
	assert_file_contains "${repo_path}/bright-builds-rules.audit.md" "Exact commit: \`${explicit_sha}\`" "audit trail should use the explicit SHA as the exact commit"

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
	assert_file_contains "${repo_path}/bright-builds-rules.audit.md" "Exact commit: \`Unavailable\`" "audit trail should record unavailable exact-commit provenance"

	run_manage_with_path_prefix "$installer_path" "$repo_path" "$fake_bin" status
	assert_eq "$run_status" "0" "status should still succeed when exact commit is unavailable"
	assert_contains "$run_output" "Pinned commit: Unavailable" "status should surface unavailable exact-commit provenance"
}
