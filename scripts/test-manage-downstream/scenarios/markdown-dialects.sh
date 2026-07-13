write_markdown_dialect_fixture() {
	local repo_path="$1"

	write_file "${repo_path}/.mdformat.toml" $'wrap = "keep"\nnumber = false\nend_of_line = "lf"\nvalidate = true\nextensions = ["gfm", "frontmatter"]\n'
	write_file "${repo_path}/docs/PLAN.md" $'---\ntitle: GSD compatibility fixture\nphase: 7\n---\n\n# Plan\n\n| Contract | Value |\n| --- | --- |\n| Marker | canonical and legacy |\n\n<execution-context>\nCanonical wrapper.\n</execution-context>\n\n<execution_context>\nLegacy wrapper remains repository-owned content.\n</execution_context>\n'
}

assert_markdown_dialect_fixture_hashes() {
	local repo_path="$1"
	local expected_config_hash="$2"
	local expected_document_hash="$3"

	assert_eq "$(git hash-object "${repo_path}/.mdformat.toml")" "$expected_config_hash" "Bright Builds should preserve downstream .mdformat.toml bytes"
	assert_eq "$(git hash-object "${repo_path}/docs/PLAN.md")" "$expected_document_hash" "Bright Builds should preserve arbitrary downstream Markdown bytes"
}

test_install_status_and_update_preserve_downstream_markdown_dialect() {
	local config_hash=""
	local document_hash=""
	local repo_path=""
	local repo_without_config=""

	repo_path="$(create_repo markdown-dialect-preservation)"
	write_markdown_dialect_fixture "$repo_path"
	config_hash="$(git hash-object "${repo_path}/.mdformat.toml")"
	document_hash="$(git hash-object "${repo_path}/docs/PLAN.md")"

	run_manage "$repo_path" install
	assert_eq "$run_status" "0" "install should succeed with a downstream Markdown formatter contract"
	assert_markdown_dialect_fixture_hashes "$repo_path" "$config_hash" "$document_hash"

	run_manage "$repo_path" status
	assert_eq "$run_status" "0" "status should succeed with a downstream Markdown formatter contract"
	assert_contains "$run_output" "Repo state: installed" "status should keep the managed install clean"
	assert_markdown_dialect_fixture_hashes "$repo_path" "$config_hash" "$document_hash"

	run_manage "$repo_path" update
	assert_eq "$run_status" "0" "update should succeed with a downstream Markdown formatter contract"
	assert_markdown_dialect_fixture_hashes "$repo_path" "$config_hash" "$document_hash"

	repo_without_config="$(create_repo markdown-dialect-no-config)"
	run_manage "$repo_without_config" install
	assert_eq "$run_status" "0" "install should succeed without downstream formatter configuration"
	assert_file_missing "${repo_without_config}/.mdformat.toml"
}

test_local_formatter_contract_variants() {
	local fake_bin=""
	local formatter_log=""
	local mode=""
	local repo_path=""
	local warning_count=""

	for mode in compatible wrong-version missing-extension; do
		repo_path="$(create_repo "local-mdformat-${mode}")"
		fake_bin="${temp_root}/local-mdformat-${mode}-bin"
		formatter_log="${temp_root}/local-mdformat-${mode}.log"
		create_fake_mdformat_bin "$fake_bin" "$mode" "$formatter_log"

		run_manage_with_path_prefix "$script_path" "$repo_path" "$fake_bin" install
		assert_eq "$run_status" "0" "local install should succeed with ${mode} mdformat"

		if [[ "$mode" == "compatible" ]]; then
			assert_not_contains "$run_output" "no compatible PATH formatter is available" "compatible mdformat should not trigger fallback guidance"
			assert_file_contains "$formatter_log" "--extensions gfm --extensions frontmatter --no-codeformatters --wrap keep --end-of-line lf" "compatible mdformat should receive the explicit dialect contract"
			continue
		fi

		warning_count="$(printf '%s\n' "$run_output" | grep -Fc 'no compatible PATH formatter is available')"
		assert_eq "$warning_count" "1" "${mode} mdformat should warn exactly once"
		assert_contains "$run_output" "mdformat-frontmatter==2.1.2" "fallback guidance should pin the frontmatter extension"
		assert_contains "$run_output" "mdformat-gfm==1.0.0" "fallback guidance should pin the GFM extension"
		if [[ "$mode" == "wrong-version" ]]; then
			assert_file_not_contains "$formatter_log" "--extensions" "wrong-version mdformat should never reach the capability or formatting path"
		else
			assert_eq "$(wc -l <"$formatter_log" | tr -d ' ')" "2" "missing-extension mdformat should only receive version and capability probes"
		fi
	done
}

test_local_missing_formatter_uses_conservative_fallback() {
	local empty_bin="${temp_root}/local-missing-mdformat-bin"
	local path_without_mdformat=""
	local repo_path=""
	local warning_count=""

	mkdir -p "$empty_bin"
	repo_path="$(create_repo local-missing-mdformat)"
	path_without_mdformat="${empty_bin}:$(path_without_command_dir mdformat)"

	set +e
	run_output="$(env PATH="$path_without_mdformat" "$BASH" "$script_path" install --repo-root "$repo_path" 2>&1)"
	run_status=$?
	set -e

	assert_eq "$run_status" "0" "local install should use exact managed sources when mdformat is missing"
	warning_count="$(printf '%s\n' "$run_output" | grep -Fc 'no compatible PATH formatter is available')"
	assert_eq "$warning_count" "1" "missing mdformat should warn exactly once"
}

test_github_actions_replaces_incompatible_path_formatter() {
	local bootstrap_log=""
	local fake_bin=""
	local formatter_log=""
	local mode=""
	local repo_path=""

	for mode in wrong-version missing-extension; do
		repo_path="$(create_repo "github-actions-mdformat-${mode}")"
		run_manage "$repo_path" install
		assert_eq "$run_status" "0" "${mode} GitHub Actions fixture install should succeed"

		fake_bin="${temp_root}/github-actions-mdformat-${mode}-bin"
		formatter_log="${temp_root}/github-actions-mdformat-${mode}.log"
		bootstrap_log="${temp_root}/github-actions-mdformat-${mode}-bootstrap.log"
		create_fake_mdformat_bin "$fake_bin" "$mode" "$formatter_log"
		create_fake_python_mdformat_bootstrap_bin "$fake_bin" "$bootstrap_log"

		set +e
		run_output="$(env GITHUB_ACTIONS=true PATH="${fake_bin}:$(path_without_command_dir mdformat)" "$BASH" "$script_path" status --repo-root "$repo_path" 2>&1)"
		run_status=$?
		set -e

		assert_eq "$run_status" "0" "GitHub Actions should replace ${mode} PATH mdformat"
		assert_contains "$run_output" "Repo state: installed" "pinned bootstrap should preserve clean managed-file matching"
		assert_file_contains "$bootstrap_log" "mdformat==1.0.0" "runtime bootstrap should pin mdformat core"
		assert_file_contains "$bootstrap_log" "mdformat-frontmatter==2.1.2" "runtime bootstrap should pin the frontmatter extension"
		assert_file_contains "$bootstrap_log" "mdformat-gfm==1.0.0" "runtime bootstrap should pin the GFM extension"
		if [[ "$mode" == "wrong-version" ]]; then
			assert_file_not_contains "$formatter_log" "--extensions" "GitHub Actions should reject wrong-version PATH mdformat before capability or formatting calls"
		else
			assert_eq "$(wc -l <"$formatter_log" | tr -d ' ')" "2" "GitHub Actions should use missing-extension PATH mdformat only for version and capability probes"
		fi
	done
}
