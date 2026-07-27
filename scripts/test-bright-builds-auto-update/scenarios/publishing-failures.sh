test_missing_token_stops_only_when_workflow_changes() {
	local bundle_root=""
	local repo_path=""
	local fake_bin=""
	local commit_count=""

	bundle_root="$(create_source_bundle missing-token-workflow)"
	repo_path="$(create_repo missing-token-workflow-repo)"
	fake_bin="${temp_root}/missing-token-workflow-bin"

	init_git_repo "$repo_path"
	install_auto_update_repo "$bundle_root" "$repo_path"
	commit_all "$repo_path" "Initial managed install"
	printf '\n# Token-required workflow update fixture.\n' >>"${bundle_root}/templates/bright-builds-auto-update.yml"
	git -C "$bundle_root" add -A
	git -C "$bundle_root" commit -m "Workflow update" >/dev/null
	create_fake_curl_bin "$fake_bin" "$bundle_root"

	run_auto_update "$repo_path" "$fake_bin" "false"
	assert_eq "$run_status" "1" "workflow updates should require the dedicated push token"
	assert_contains "$run_output" "Bright Builds push-token repair required." "missing-token workflow updates should print the targeted repair heading"
	assert_contains "$run_output" "gh secret set BRIGHT_BUILDS_PUSH_TOKEN -R bright-builds-llc/test-repo" "missing-token workflow updates should print the exact secret repair command"
	assert_contains "$run_output" "gh run watch RUN_ID -R bright-builds-llc/test-repo --exit-status" "missing-token workflow updates should print the exact rerun watch command"
	assert_not_contains "$run_output" "Direct push to main failed" "missing-token workflow updates should stop before attempting a push"
	commit_count="$(git -C "$repo_path" rev-list --count HEAD)"
	assert_eq "$commit_count" "1" "missing-token workflow updates should not create a commit"
}

test_workflow_permission_failure_skips_pull_request_fallback() {
	local bundle_root=""
	local repo_path=""
	local remote_path=""
	local fake_bin=""
	local fake_git_log=""
	local fake_gh_log=""

	bundle_root="$(create_source_bundle workflow-permission)"
	repo_path="$(create_repo workflow-permission-repo)"
	remote_path="$(create_bare_remote workflow-permission-origin)"
	fake_bin="${temp_root}/workflow-permission-bin"
	fake_git_log="${temp_root}/workflow-permission-git.log"
	fake_gh_log="${temp_root}/workflow-permission-gh.log"

	init_git_repo "$repo_path"
	git -C "$repo_path" remote add origin "$remote_path"
	install_auto_update_repo "$bundle_root" "$repo_path"
	commit_all "$repo_path" "Initial managed install"
	git -C "$repo_path" push -u origin main >/dev/null
	printf '\n# Under-scoped token workflow fixture.\n' >>"${bundle_root}/templates/bright-builds-auto-update.yml"
	git -C "$bundle_root" add -A
	git -C "$bundle_root" commit -m "Workflow update" >/dev/null
	create_fake_curl_bin "$fake_bin" "$bundle_root"
	create_fake_git_bin "$fake_bin" "$fake_git_log" "workflow-permission"
	create_fake_gh_bin "$fake_bin" "$fake_gh_log"
	write_file "$fake_gh_log" ""

	run_auto_update "$repo_path" "$fake_bin" "true"
	assert_eq "$run_status" "1" "under-scoped configured tokens should fail with targeted guidance"
	assert_contains "$run_output" "without workflows permission" "auto-update should preserve the classified push error"
	assert_contains "$run_output" "Bright Builds push-token repair required." "workflow-permission failures should print targeted repair guidance"
	assert_not_contains "$run_output" "falling back to bright-builds/auto-update" "workflow-permission failures should skip the futile branch fallback"
	assert_file_not_contains "$fake_git_log" "unexpected fallback push" "workflow-permission failures should not attempt another push"
	assert_file_not_contains "$fake_gh_log" "pr create" "workflow-permission failures should not attempt PR creation"
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

test_managed_source_download_failure_stops_before_publish() {
	local bundle_root=""
	local repo_path=""
	local remote_path=""
	local fake_bin=""
	local fake_gh_log=""
	local fake_git_push_log=""
	local architecture_hash=""
	local audit_hash=""
	local initial_commit=""
	local remote_commit=""
	local commit_count=""
	local architecture_attempts=""
	local worktree_status=""

	bundle_root="$(create_source_bundle managed-source-download-failure)"
	repo_path="$(create_repo managed-source-download-failure-repo)"
	remote_path="$(create_bare_remote managed-source-download-failure-origin)"
	fake_bin="${temp_root}/managed-source-download-failure-bin"
	fake_gh_log="${temp_root}/managed-source-download-failure-gh.log"
	fake_git_push_log="${temp_root}/managed-source-download-failure-git-push.log"

	init_git_repo "$repo_path"
	git -C "$repo_path" remote add origin "$remote_path"
	install_auto_update_repo "$bundle_root" "$repo_path"
	commit_all "$repo_path" "Initial managed install"
	git -C "$repo_path" push -u origin main >/dev/null
	architecture_hash="$(git -C "$repo_path" hash-object standards/core/architecture.md)"
	audit_hash="$(git -C "$repo_path" hash-object bright-builds-rules.audit.md)"
	initial_commit="$(git -C "$repo_path" rev-parse HEAD)"
	create_fake_curl_bin "$fake_bin" "$bundle_root"
	create_fake_gh_bin "$fake_bin" "$fake_gh_log"
	write_file "$fake_gh_log" ""
	write_file "$fake_git_push_log" ""
	FAKE_GIT_PUSH_LOG="$fake_git_push_log"
	FAKE_CURL_FAIL_PATH="standards/core/architecture.md"
	FAKE_CURL_FAIL_START_ATTEMPT="3"
	FAKE_CURL_FAIL_ATTEMPTS="always"
	export FAKE_GIT_PUSH_LOG FAKE_CURL_FAIL_PATH FAKE_CURL_FAIL_START_ATTEMPT FAKE_CURL_FAIL_ATTEMPTS

	run_auto_update "$repo_path" "$fake_bin"
	assert_eq "$run_status" "1" "exhausted managed-source retries should fail auto-update"
	assert_contains "$run_output" "unable to download managed source standards/core/architecture.md" "auto-update failure should identify the required source path"
	assert_contains "$run_output" "error: update failed" "auto-update should stop at the manager failure boundary"
	assert_eq "$(git -C "$repo_path" hash-object standards/core/architecture.md)" "$architecture_hash" "failed auto-update should preserve local managed content"
	assert_eq "$(git -C "$repo_path" hash-object bright-builds-rules.audit.md)" "$audit_hash" "failed auto-update should preserve local audit metadata"
	remote_commit="$(git --git-dir="$remote_path" rev-parse refs/heads/main)"
	assert_eq "$remote_commit" "$initial_commit" "failed auto-update should preserve the remote default branch"
	commit_count="$(git -C "$repo_path" rev-list --count HEAD)"
	assert_eq "$commit_count" "1" "failed auto-update should not create a local update commit"
	worktree_status="$(git -C "$repo_path" status --short --untracked-files=all)"
	assert_eq "$worktree_status" "" "failed auto-update should leave the downstream worktree unchanged"
	assert_file_not_contains "$fake_git_push_log" "push" "failed auto-update should not attempt a direct or fallback push"
	assert_file_not_contains "$fake_gh_log" "pr create" "failed auto-update should not create a pull request"
	if git --git-dir="$remote_path" show-ref --verify --quiet refs/heads/bright-builds/auto-update; then
		fail "failed auto-update should not create the fallback branch"
	fi
	architecture_attempts="$(awk -F '\t' '$1 == "standards/core/architecture.md" { count++ } END { print count + 0 }' "$FAKE_CURL_ATTEMPT_LOG")"
	assert_eq "$architecture_attempts" "6" "auto-update should perform two comparison fetches before four bounded required attempts"
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
