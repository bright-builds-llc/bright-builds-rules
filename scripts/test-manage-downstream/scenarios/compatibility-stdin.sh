test_script_only_status_falls_back_from_stale_legacy_exact_commit() {
	local repo_path=""
	local legacy_installer_path=""
	local current_installer_path=""
	local legacy_bundle_root=""
	local current_bundle_root=""
	local script_only_installer_path=""
	local fake_bin=""
	local stale_exact_commit="0000000000000000000000000000000000000000"

	repo_path="$(create_repo script-only-stale-legacy)"
	legacy_installer_path="$(create_legacy_installer_bundle script-only-stale-legacy)"
	current_installer_path="$(create_standalone_installer_bundle script-only-stale-current)"
	legacy_bundle_root="$(cd "$(dirname "$legacy_installer_path")/.." && pwd)"
	current_bundle_root="$(cd "$(dirname "$current_installer_path")/.." && pwd)"
	script_only_installer_path="$(create_script_only_installer_copy script-only-stale-current "$current_installer_path")"
	fake_bin="${temp_root}/script-only-stale-bin"

	write_file "${repo_path}/README.md" $'# Legacy App\n\nBody text remains.\n'

	run_manage_with_script "$legacy_installer_path" "$repo_path" install --auto-update enabled
	assert_eq "$run_status" "0" "legacy installer setup should succeed before stale exact-commit fallback"
	replace_markdown_value "${repo_path}/${legacy_audit_destination}" "Exact commit" "$stale_exact_commit"
	replace_markdown_value "${repo_path}/AGENTS.bright-builds.md" "Exact commit" "$stale_exact_commit"
	create_fake_remote_fetch_bin "$fake_bin" "$current_bundle_root" "$legacy_bundle_root" "$stale_exact_commit"

	run_manage_with_path_prefix "$script_only_installer_path" "$repo_path" "$fake_bin" status
	assert_eq "$run_status" "0" "script-only status should succeed when a legacy exact commit no longer resolves"
	assert_contains "$run_output" "Repo state: installed" "script-only status should still classify the legacy install as installed"
	assert_contains "$run_output" "Recommended action: update" "script-only status should still recommend update"
	assert_contains "$run_output" "Audit trail: ${legacy_audit_destination}" "script-only status should keep the legacy audit trail visible before migration"
	assert_not_contains "$run_output" "Blocking paths:" "script-only status should not block clean legacy installs after fallback"
	assert_not_contains "$run_output" "curl:" "script-only status should suppress comparison fetch fallback noise"
	assert_not_contains "$run_output" "No such file or directory" "script-only status should not surface missing temp-path errors"
}

test_script_only_status_falls_back_when_legacy_exact_commit_is_unavailable() {
	local repo_path=""
	local legacy_installer_path=""
	local current_installer_path=""
	local legacy_bundle_root=""
	local current_bundle_root=""
	local script_only_installer_path=""
	local fake_bin=""

	repo_path="$(create_repo script-only-unavailable-legacy)"
	legacy_installer_path="$(create_legacy_installer_bundle script-only-unavailable-legacy)"
	current_installer_path="$(create_standalone_installer_bundle script-only-unavailable-current)"
	legacy_bundle_root="$(cd "$(dirname "$legacy_installer_path")/.." && pwd)"
	current_bundle_root="$(cd "$(dirname "$current_installer_path")/.." && pwd)"
	script_only_installer_path="$(create_script_only_installer_copy script-only-unavailable-current "$current_installer_path")"
	fake_bin="${temp_root}/script-only-unavailable-bin"

	write_file "${repo_path}/README.md" $'# Legacy App\n\nBody text remains.\n'

	run_manage_with_script "$legacy_installer_path" "$repo_path" install --auto-update enabled
	assert_eq "$run_status" "0" "legacy installer setup should succeed before unavailable exact-commit fallback"
	replace_markdown_value "${repo_path}/${legacy_audit_destination}" "Exact commit" "Unavailable"
	replace_markdown_value "${repo_path}/AGENTS.bright-builds.md" "Exact commit" "Unavailable"
	create_fake_remote_fetch_bin "$fake_bin" "$current_bundle_root" "$legacy_bundle_root"

	run_manage_with_path_prefix "$script_only_installer_path" "$repo_path" "$fake_bin" status
	assert_eq "$run_status" "0" "script-only status should succeed when a legacy exact commit is unavailable"
	assert_contains "$run_output" "Repo state: installed" "script-only status should still treat unavailable legacy provenance as installed"
	assert_contains "$run_output" "Recommended action: update" "script-only status should still recommend update for unavailable legacy provenance"
	assert_not_contains "$run_output" "Blocking paths:" "script-only status should not block unavailable legacy provenance"
	assert_not_contains "$run_output" "curl:" "script-only status should suppress unavailable comparison fetch noise"
	assert_not_contains "$run_output" "No such file or directory" "script-only status should not surface missing temp-path errors for unavailable provenance"
}

test_stdin_status_does_not_emit_bash_source_error() {
	local repo_path=""
	local installer_path=""
	local bundle_root=""
	local fake_bin=""

	repo_path="$(create_repo stdin-status)"
	installer_path="$(create_standalone_installer_bundle stdin-status)"
	bundle_root="$(cd "$(dirname "$installer_path")/.." && pwd)"
	fake_bin="${temp_root}/stdin-status-bin"
	create_fake_remote_fetch_bin "$fake_bin" "$bundle_root" "$bundle_root"

	run_manage_via_stdin_with_path_prefix "$installer_path" "$repo_path" "$fake_bin" status
	assert_eq "$run_status" "0" "stdin status should succeed"
	assert_contains "$run_output" "Repo state: installable" "stdin status should still classify a fresh repo as installable"
	assert_contains "$run_output" "Recommended action: install" "stdin status should still recommend install"
	assert_not_contains "$run_output" "BASH_SOURCE[0]: unbound variable" "stdin status should not emit a BASH_SOURCE error"
	assert_not_contains "$run_output" "No such file or directory" "stdin status should not emit path-resolution noise"
}

test_stdin_missing_remote_module_fails_before_mutation() {
	local repo_path=""
	local installer_path=""
	local moduleless_source_root=""
	local fake_bin=""

	repo_path="$(create_repo stdin-missing-module)"
	installer_path="$(create_standalone_installer_bundle stdin-missing-module)"
	moduleless_source_root="${temp_root}/stdin-missing-module-source"
	fake_bin="${temp_root}/stdin-missing-module-bin"
	mkdir -p "${moduleless_source_root}/scripts" "${moduleless_source_root}/templates" "${moduleless_source_root}/standards"
	cp "$script_path" "${moduleless_source_root}/scripts/manage-downstream.sh"
	cp -R "${repo_root}/templates/." "${moduleless_source_root}/templates/"
	cp -R "${repo_root}/standards/." "${moduleless_source_root}/standards/"
	create_fake_remote_fetch_bin "$fake_bin" "$moduleless_source_root" "$moduleless_source_root"

	run_manage_via_stdin_with_path_prefix "$installer_path" "$repo_path" "$fake_bin" install
	assert_eq "$run_status" "1" "stdin install should fail when a required manager module is missing remotely"
	assert_contains "$run_output" "unable to load Bright Builds manager module scripts/manage-downstream/core.sh" "missing remote module failure should identify the module"
	assert_file_missing "${repo_path}/AGENTS.md"
	assert_file_missing "${repo_path}/bright-builds-rules.audit.md"
}

test_stdin_install_uses_remote_rendering() {
	local repo_path=""
	local installer_path=""
	local bundle_root=""
	local fake_bin=""
	local bundle_exact_commit=""

	repo_path="$(create_repo stdin-install)"
	installer_path="$(create_standalone_installer_bundle stdin-install)"
	bundle_root="$(cd "$(dirname "$installer_path")/.." && pwd)"
	fake_bin="${temp_root}/stdin-install-bin"
	bundle_exact_commit="$(git -C "$bundle_root" rev-parse HEAD)"
	create_fake_remote_fetch_bin "$fake_bin" "$bundle_root" "$bundle_root"

	run_manage_via_stdin_with_path_prefix "$installer_path" "$repo_path" "$fake_bin" install
	assert_eq "$run_status" "0" "stdin install should succeed"
	assert_not_contains "$run_output" "BASH_SOURCE[0]: unbound variable" "stdin install should not emit a BASH_SOURCE error"
	assert_not_contains "$run_output" "No such file or directory" "stdin install should not emit path-resolution noise"
	assert_file_exists "${repo_path}/AGENTS.md"
	assert_file_exists "${repo_path}/AGENTS.bright-builds.md"
	assert_file_exists "${repo_path}/CONTRIBUTING.md"
	assert_file_exists "${repo_path}/.github/pull_request_template.md"
	assert_file_exists "${repo_path}/bright-builds-rules.audit.md"
	assert_file_contains "${repo_path}/AGENTS.bright-builds.md" "Exact commit: \`${bundle_exact_commit}\`" "stdin install should resolve the remote exact commit"
}

test_stdin_update_uses_remote_rendering() {
	local repo_path=""
	local installer_path=""
	local bundle_root=""
	local fake_bin=""

	repo_path="$(create_repo stdin-update)"
	installer_path="$(create_standalone_installer_bundle stdin-update)"
	bundle_root="$(cd "$(dirname "$installer_path")/.." && pwd)"
	fake_bin="${temp_root}/stdin-update-bin"
	create_fake_remote_fetch_bin "$fake_bin" "$bundle_root" "$bundle_root"

	run_manage_with_script "$installer_path" "$repo_path" install
	assert_eq "$run_status" "0" "stdin update setup install should succeed"

	run_manage_via_stdin_with_path_prefix "$installer_path" "$repo_path" "$fake_bin" update
	assert_eq "$run_status" "0" "stdin update should succeed"
	assert_contains "$run_output" "Updated AGENTS.md" "stdin update should refresh the managed AGENTS block"
	assert_contains "$run_output" "Wrote bright-builds-rules.audit.md" "stdin update should refresh the audit trail"
	assert_not_contains "$run_output" "BASH_SOURCE[0]: unbound variable" "stdin update should not emit a BASH_SOURCE error"
	assert_not_contains "$run_output" "No such file or directory" "stdin update should not emit path-resolution noise"
}

test_stdin_update_preserves_files_after_exhausted_managed_source_download() {
	local repo_path=""
	local installer_path=""
	local bundle_root=""
	local fake_bin=""
	local architecture_checksum=""
	local audit_checksum=""
	local architecture_attempts=""

	repo_path="$(create_repo stdin-update-download-failure)"
	installer_path="$(create_standalone_installer_bundle stdin-update-download-failure)"
	bundle_root="$(cd "$(dirname "$installer_path")/.." && pwd)"
	fake_bin="${temp_root}/stdin-update-download-failure-bin"
	create_fake_remote_fetch_bin "$fake_bin" "$bundle_root" "$bundle_root"

	run_manage_with_script "$installer_path" "$repo_path" install
	assert_eq "$run_status" "0" "managed-source failure setup install should succeed"
	architecture_checksum="$(cksum <"${repo_path}/standards/core/architecture.md")"
	audit_checksum="$(cksum <"${repo_path}/bright-builds-rules.audit.md")"
	FAKE_CURL_FAIL_PATH="standards/core/architecture.md"
	FAKE_CURL_FAIL_START_ATTEMPT="2"
	FAKE_CURL_FAIL_ATTEMPTS="always"
	export FAKE_CURL_FAIL_PATH FAKE_CURL_FAIL_START_ATTEMPT FAKE_CURL_FAIL_ATTEMPTS

	run_manage_via_stdin_with_path_prefix "$installer_path" "$repo_path" "$fake_bin" update
	assert_eq "$run_status" "1" "an exhausted required managed-source download should fail update"
	assert_contains "$run_output" "unable to download managed source standards/core/architecture.md" "required download failure should identify the source path"
	assert_eq "$(cksum <"${repo_path}/standards/core/architecture.md")" "$architecture_checksum" "required download failure should preserve the managed destination"
	assert_eq "$(cksum <"${repo_path}/bright-builds-rules.audit.md")" "$audit_checksum" "required download failure should preserve audit metadata"
	[[ -s "${repo_path}/standards/core/architecture.md" ]] || fail "required download failure should not empty the managed destination"
	architecture_attempts="$(awk -F '\t' '$1 == "standards/core/architecture.md" { count++ } END { print count + 0 }' "$FAKE_CURL_ATTEMPT_LOG")"
	assert_eq "$architecture_attempts" "5" "required download should follow one comparison fetch with four bounded attempts"
}

test_stdin_update_retries_transient_managed_source_download() {
	local repo_path=""
	local installer_path=""
	local bundle_root=""
	local fake_bin=""
	local canonical_checksum=""
	local architecture_attempts=""

	repo_path="$(create_repo stdin-update-download-retry)"
	installer_path="$(create_standalone_installer_bundle stdin-update-download-retry)"
	bundle_root="$(cd "$(dirname "$installer_path")/.." && pwd)"
	fake_bin="${temp_root}/stdin-update-download-retry-bin"
	create_fake_remote_fetch_bin "$fake_bin" "$bundle_root" "$bundle_root"

	run_manage_with_script "$installer_path" "$repo_path" install
	assert_eq "$run_status" "0" "managed-source retry setup install should succeed"
	canonical_checksum="$(cksum <"${bundle_root}/standards/core/architecture.md")"
	FAKE_CURL_FAIL_PATH="standards/core/architecture.md"
	FAKE_CURL_FAIL_START_ATTEMPT="2"
	FAKE_CURL_FAIL_ATTEMPTS="2"
	export FAKE_CURL_FAIL_PATH FAKE_CURL_FAIL_START_ATTEMPT FAKE_CURL_FAIL_ATTEMPTS

	run_manage_via_stdin_with_path_prefix "$installer_path" "$repo_path" "$fake_bin" update
	assert_eq "$run_status" "0" "two transient managed-source failures should recover on the third download attempt"
	assert_eq "$(cksum <"${repo_path}/standards/core/architecture.md")" "$canonical_checksum" "recovered download should install canonical content"
	[[ -s "${repo_path}/standards/core/architecture.md" ]] || fail "recovered download should remain non-empty"
	architecture_attempts="$(awk -F '\t' '$1 == "standards/core/architecture.md" { count++ } END { print count + 0 }' "$FAKE_CURL_ATTEMPT_LOG")"
	assert_eq "$architecture_attempts" "4" "required download should succeed after one comparison fetch and three download attempts"
}

test_stdin_update_rejects_empty_managed_source_download() {
	local repo_path=""
	local installer_path=""
	local bundle_root=""
	local fake_bin=""
	local architecture_checksum=""
	local audit_checksum=""
	local architecture_attempts=""

	repo_path="$(create_repo stdin-update-empty-download)"
	installer_path="$(create_standalone_installer_bundle stdin-update-empty-download)"
	bundle_root="$(cd "$(dirname "$installer_path")/.." && pwd)"
	fake_bin="${temp_root}/stdin-update-empty-download-bin"
	create_fake_remote_fetch_bin "$fake_bin" "$bundle_root" "$bundle_root"

	run_manage_with_script "$installer_path" "$repo_path" install
	assert_eq "$run_status" "0" "empty managed-source setup install should succeed"
	architecture_checksum="$(cksum <"${repo_path}/standards/core/architecture.md")"
	audit_checksum="$(cksum <"${repo_path}/bright-builds-rules.audit.md")"
	FAKE_CURL_EMPTY_PATH="standards/core/architecture.md"
	FAKE_CURL_EMPTY_START_ATTEMPT="2"
	export FAKE_CURL_EMPTY_PATH FAKE_CURL_EMPTY_START_ATTEMPT

	run_manage_via_stdin_with_path_prefix "$installer_path" "$repo_path" "$fake_bin" update
	assert_eq "$run_status" "1" "an empty required managed-source response should fail update"
	assert_contains "$run_output" "downloaded managed source is empty:" "empty download failure should explain the validation error"
	assert_contains "$run_output" "standards/core/architecture.md" "empty download failure should identify the source path"
	assert_eq "$(cksum <"${repo_path}/standards/core/architecture.md")" "$architecture_checksum" "empty download should preserve the managed destination"
	assert_eq "$(cksum <"${repo_path}/bright-builds-rules.audit.md")" "$audit_checksum" "empty download should preserve audit metadata"
	[[ -s "${repo_path}/standards/core/architecture.md" ]] || fail "empty download should not empty the managed destination"
	architecture_attempts="$(awk -F '\t' '$1 == "standards/core/architecture.md" { count++ } END { print count + 0 }' "$FAKE_CURL_ATTEMPT_LOG")"
	assert_eq "$architecture_attempts" "2" "empty download should follow one comparison fetch with one required fetch"
}

test_stdin_force_install_repairs_drifted_managed_file() {
	local repo_path=""
	local installer_path=""
	local bundle_root=""
	local fake_bin=""
	local backup_file=""

	repo_path="$(create_repo stdin-force-install)"
	installer_path="$(create_standalone_installer_bundle stdin-force-install)"
	bundle_root="$(cd "$(dirname "$installer_path")/.." && pwd)"
	fake_bin="${temp_root}/stdin-force-install-bin"
	create_fake_remote_fetch_bin "$fake_bin" "$bundle_root" "$bundle_root"

	run_manage_with_script "$installer_path" "$repo_path" install
	assert_eq "$run_status" "0" "stdin force-install setup install should succeed"

	replace_exact_line \
		"${repo_path}/CONTRIBUTING.md" \
		"- Prefer simple, root-cause fixes over broad rewrites." \
		"- Prefer drifted local rewrites over upstream defaults."

	run_manage_via_stdin_with_path_prefix "$installer_path" "$repo_path" "$fake_bin" install --force
	assert_eq "$run_status" "0" "stdin force install should succeed"
	assert_not_contains "$run_output" "BASH_SOURCE[0]: unbound variable" "stdin force install should not emit a BASH_SOURCE error"
	assert_not_contains "$run_output" "No such file or directory" "stdin force install should not emit path-resolution noise"
	backup_file="$(find "${repo_path}/.bright-builds-rules-backups" -type f -name 'CONTRIBUTING.md' | head -n 1)"
	[[ -n "$backup_file" ]] || fail "expected stdin force install to back up the drifted CONTRIBUTING.md"
	assert_exact_line_count "${repo_path}/CONTRIBUTING.md" "$contributing_block_begin" "1"
	assert_exact_line_count "${repo_path}/CONTRIBUTING.md" "$contributing_block_end" "1"
	assert_file_not_contains "${repo_path}/CONTRIBUTING.md" "Prefer drifted local rewrites over upstream defaults." "stdin force install should remove the drifted local block edit"
}

test_drifted_whole_file_managed_file_blocks_update_and_force_repairs() {
	local repo_path=""
	local backup_file=""
	local managed_files_markdown=""

	repo_path="$(create_repo drifted-managed-file)"

	run_manage "$repo_path" install
	assert_eq "$run_status" "0" "whole-file drift setup install should succeed"

	managed_files_markdown=$'- `AGENTS.md (managed block)`\n- `AGENTS.bright-builds.md`\n- `CONTRIBUTING.md`\n- `.github/pull_request_template.md`\n- `bright-builds-rules.audit.md`'
	render_current_whole_file_contributing_compat "${repo_path}/CONTRIBUTING.md"
	render_current_whole_file_audit_compat "${repo_path}/bright-builds-rules.audit.md" "main" "$repo_exact_commit" "bright-builds-rules.audit.md" "disabled" "default disabled" "install" "2026-04-11T00:00:00Z" "$managed_files_markdown"

	printf '\nLocal downstream change.\n' >>"${repo_path}/CONTRIBUTING.md"

	run_manage "$repo_path" status
	assert_eq "$run_status" "0" "drifted whole-file managed file status should succeed"
	assert_contains "$run_output" "Repo state: blocked" "drifted whole-file managed files should block the repo"
	assert_contains "$run_output" "Blocking paths: CONTRIBUTING.md" "status should list the drifted managed file"

	run_manage "$repo_path" update
	assert_eq "$run_status" "1" "update should fail when a whole-file managed file has downstream edits"

	run_manage "$repo_path" install --force
	assert_eq "$run_status" "0" "force install should repair drifted whole-file managed files"
	backup_file="$(find "${repo_path}/.bright-builds-rules-backups" -type f -name 'CONTRIBUTING.md' | head -n 1)"
	[[ -n "$backup_file" ]] || fail "expected force install to back up the drifted CONTRIBUTING.md"
	assert_exact_line_count "${repo_path}/CONTRIBUTING.md" "$contributing_block_begin" "1"
	assert_exact_line_count "${repo_path}/CONTRIBUTING.md" "$contributing_block_end" "1"
	assert_file_not_contains "${repo_path}/CONTRIBUTING.md" "Local downstream change." "force install should remove the drifted local edit"
}

test_drifted_managed_standards_file_blocks_update_and_force_repairs() {
	local repo_path=""
	local backup_file=""

	repo_path="$(create_repo drifted-managed-standards)"

	run_manage "$repo_path" install
	assert_eq "$run_status" "0" "managed standards drift setup install should succeed"

	append_file "${repo_path}/standards/languages/typescript-javascript.md" $'\nLocal downstream standards drift.\n'

	run_manage "$repo_path" status
	assert_eq "$run_status" "0" "drifted standards status should succeed"
	assert_contains "$run_output" "Repo state: blocked" "drifted standards files should block the repo"
	assert_contains "$run_output" "Blocking paths: standards/languages/typescript-javascript.md" "status should list the drifted standards file"

	run_manage "$repo_path" update
	assert_eq "$run_status" "1" "update should fail when a managed standards file has downstream edits"

	run_manage "$repo_path" install --force
	assert_eq "$run_status" "0" "force install should repair drifted standards files"
	backup_file="$(find "${repo_path}/.bright-builds-rules-backups" -type f -path '*/standards/languages/typescript-javascript.md' | head -n 1)"
	[[ -n "$backup_file" ]] || fail "expected force install to back up the drifted standards file"
	assert_file_contains "$backup_file" "Local downstream standards drift." "backup should preserve the drifted standards content"
	assert_file_not_contains "${repo_path}/standards/languages/typescript-javascript.md" "Local downstream standards drift." "force install should restore the managed standards content"
	assert_file_contains "${repo_path}/standards/languages/typescript-javascript.md" "Do Not Add Python Scripts To Bun-Friendly JS/TS Repositories" "force install should restore the TypeScript/JavaScript standards"
}
