#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script_path="${repo_root}/scripts/manage-downstream.sh"
test_module_dir="${repo_root}/scripts/test-manage-downstream"
agents_block_begin="<!-- bright-builds-rules-managed:begin -->"
agents_block_end="<!-- bright-builds-rules-managed:end -->"
contributing_block_begin="<!-- bright-builds-rules-contributing:begin -->"
contributing_block_end="<!-- bright-builds-rules-contributing:end -->"
readme_badges_begin="<!-- bright-builds-rules-readme-badges:begin -->"
readme_badges_end="<!-- bright-builds-rules-readme-badges:end -->"
legacy_agents_block_begin="<!-- coding-and-architecture-requirements-managed:begin -->"
legacy_agents_block_end="<!-- coding-and-architecture-requirements-managed:end -->"
legacy_readme_badges_begin="<!-- coding-and-architecture-requirements-readme-badges:begin -->"
legacy_readme_badges_end="<!-- coding-and-architecture-requirements-readme-badges:end -->"
legacy_audit_destination="coding-and-architecture-requirements.audit.md"
legacy_repo_ref="0d5dce1^"
pre_lint_guard_ref="85588ad75ba23d917a58ecf0a9b911922cc5ffab"
pre_directory_exception_ref="de249d5462e72728085ae270a62b57949e2d2f79"
pre_local_standards_ref="05f8d7a6c9c2e157ec4f922a05273e72dab97676"
temp_root="$(mktemp -d "${TMPDIR:-/tmp}/bright-builds-rules-tests.XXXXXX")"
repo_exact_commit="$(git -C "${repo_root}" rev-parse HEAD)"
real_git_path="$(command -v git)"
default_fake_bin="${temp_root}/default-fake-bin"
legacy_bright_builds_url="https://github.com/bright-builds-llc/coding-and-architecture-requirements"
legacy_bright_builds_raw_base_url="https://raw.githubusercontent.com/bright-builds-llc/coding-and-architecture-requirements/main"
current_bright_builds_url="https://github.com/bright-builds-llc/bright-builds-rules"
current_bright_builds_raw_base_url="https://raw.githubusercontent.com/bright-builds-llc/bright-builds-rules/main"
run_output=""
run_status=0

for test_module in \
	"${test_module_dir}/helpers.sh" \
	"${test_module_dir}/fixtures.sh" \
	"${test_module_dir}/scenarios/install-update-status.sh" \
	"${test_module_dir}/scenarios/update-migrations.sh" \
	"${test_module_dir}/scenarios/markdown-dialects.sh" \
	"${test_module_dir}/scenarios/compatibility-stdin.sh" \
	"${test_module_dir}/scenarios/readme-badges.sh" \
	"${test_module_dir}/scenarios/uninstall.sh"; do
	# shellcheck source=/dev/null
	source "$test_module"
done

trap cleanup EXIT

disable_real_gh_by_default

test_fresh_install_and_reinstall
test_existing_agents_is_installable
test_trusted_repo_owner_enables_auto_update_by_default
test_trusted_github_user_enables_auto_update_by_default
test_installed_checker_supports_directory_exceptions
test_managed_checks_conflicts_force_repair_and_uninstall
test_peter_ryszkiewicz_owner_gets_openlinks_identity_guidance
test_owner_specific_openlinks_badge_appends_after_detected_badges
test_untracked_auto_update_files_are_ignored_when_disabled
test_auto_update_conflicts_block_when_enabled
test_blocked_conflicts_and_force_install
test_explicit_auto_update_disable_persists_across_update
test_auto_update_enabled_files_are_restored_on_update
test_update_preserves_local_agents_and_overrides
test_update_backfills_missing_local_standards
test_update_replaces_pre_lint_guard_checker_notices
test_update_adds_directory_exception_support
test_pre_frontend_ui_audit_manifest_remains_updateable
test_managed_markdown_status_and_update_bootstrap_mdformat_in_github_actions
test_install_status_and_update_preserve_downstream_markdown_dialect
test_local_formatter_contract_variants
test_local_missing_formatter_uses_conservative_fallback
test_github_actions_replaces_incompatible_path_formatter
test_pre_local_standards_contributing_block_remains_updateable
test_pre_prompt_auto_update_workflow_remains_updateable
test_existing_unmanaged_standards_file_blocks_install_until_force
test_current_whole_file_contributing_install_is_installed_and_update_migrates
test_legacy_exact_match_install_is_still_installed_and_update_migrates_markers
test_drifted_contributing_block_blocks_update_and_force_repairs
test_prerename_clean_install_is_installed_and_update_migrates_legacy_layout
test_script_only_status_falls_back_from_stale_legacy_exact_commit
test_script_only_status_falls_back_when_legacy_exact_commit_is_unavailable
test_stdin_status_does_not_emit_bash_source_error
test_stdin_missing_remote_module_fails_before_mutation
test_stdin_install_uses_remote_rendering
test_stdin_update_uses_remote_rendering
test_stdin_update_preserves_files_after_exhausted_managed_source_download
test_stdin_update_retries_transient_managed_source_download
test_stdin_update_rejects_empty_managed_source_download
test_stdin_force_install_repairs_drifted_managed_file
test_drifted_whole_file_managed_file_blocks_update_and_force_repairs
test_drifted_managed_standards_file_blocks_update_and_force_repairs
test_readme_badges_insert_after_h1_and_refresh
test_update_replaces_old_managed_canonical_badge_with_flat_default
test_readme_badges_create_skeleton_and_uninstall_removes_it
test_readme_badges_block_existing_top_badges_and_force_repair
test_partial_readme_badge_block_requires_force_repair
test_readme_badges_are_removed_when_no_managed_badges_remain
test_status_and_update_repair_legacy_bright_builds_badge_above_managed_block
test_update_normalizes_legacy_bright_builds_badges_outside_insertion_zone
test_update_does_not_rewrite_unknown_bright_builds_like_badges
test_update_removes_owner_specific_openlinks_badge_when_owner_changes
test_rich_readme_badge_detection
test_old_standalone_install_is_blocked
test_uninstall_preserves_local_agents_and_overrides
test_uninstall_preserves_drifted_whole_file_managed_files
test_uninstall_removes_agents_when_only_managed_block_remains
test_explicit_full_sha_ref_sets_exact_commit
test_unavailable_exact_commit_does_not_block_install

printf 'All manage-downstream integration tests passed.\n'
