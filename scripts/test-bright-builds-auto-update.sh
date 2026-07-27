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
pre_directory_exception_ref="de249d5462e72728085ae270a62b57949e2d2f79"
pre_local_standards_ref="05f8d7a6c9c2e157ec4f922a05273e72dab97676"
run_output=""
run_status=0
test_module_dir="${repo_root}/scripts/test-bright-builds-auto-update"

for test_module in \
	"${test_module_dir}/helpers.sh" \
	"${test_module_dir}/fixtures.sh" \
	"${test_module_dir}/scenarios/update-success.sh" \
	"${test_module_dir}/scenarios/publishing-failures.sh"; do
	# shellcheck source=/dev/null
	source "$test_module"
done

trap cleanup EXIT

test_noop_when_no_changes_exist
test_noop_when_mdformat_is_absent
test_pushes_directly_when_push_succeeds
test_refreshes_managed_standards_files
test_auto_update_adds_directory_exception_support
test_legacy_helper_without_standards_staging_commits_backfilled_standards
test_refreshes_old_managed_canonical_badge_to_flat_default_when_upstream_is_otherwise_unchanged
test_legacy_helper_migrates_prerename_install_with_current_manager
test_legacy_helper_falls_back_from_stale_exact_commit_during_status
test_missing_token_stops_only_when_workflow_changes
test_workflow_permission_failure_skips_pull_request_fallback
test_falls_back_to_pull_request_when_direct_push_fails
test_managed_source_download_failure_stops_before_publish
test_fails_when_repo_state_is_blocked
test_fails_when_repo_state_is_blocked_by_managed_file_drift

printf 'All bright-builds auto-update tests passed.\n'
