render_template_file() {
	local source_path="$1"
	local output_path="$2"
	local managed_files_markdown="${3:-}"
	local relative_destination="${4:-}"
	local include_managed_file_marker="${5:-enabled}"
	local owner_specific_guidance_override="${6-__CURRENT__}"
	local managed_file_marker_line=""
	local owner_specific_guidance_content=""
	local line=""

	if [[ "$include_managed_file_marker" == "enabled" && -n "$relative_destination" ]]; then
		managed_file_marker_line="$(build_managed_file_marker_line "$relative_destination")"
	fi

	if [[ "$owner_specific_guidance_override" == "__CURRENT__" ]]; then
		owner_specific_guidance_content="$owner_specific_guidance_markdown"
	else
		owner_specific_guidance_content="$owner_specific_guidance_override"
	fi

	{
		while IFS= read -r line || [[ -n "$line" ]]; do
			if [[ "$line" == "$managed_file_marker_placeholder" ||
				"$line" == "# ${managed_file_marker_placeholder}" ||
				"$line" == "// ${managed_file_marker_placeholder}" ]]; then
				if [[ -n "$managed_file_marker_line" ]]; then
					printf '%s\n' "$managed_file_marker_line"
				fi
				continue
			fi

			if [[ "$line" == "REPLACE_WITH_MANAGED_FILES_LIST" ]]; then
				printf '%s\n' "$managed_files_markdown"
				continue
			fi

			if [[ "$line" == "REPLACE_WITH_OWNER_SPECIFIC_GUIDANCE" ]]; then
				if [[ -n "$owner_specific_guidance_content" ]]; then
					printf '%s\n' "$owner_specific_guidance_content"
				fi
				continue
			fi

			line="${line//REPLACE_WITH_REPO_URL/$repo_url}"
			line="${line//REPLACE_WITH_TAG_OR_COMMIT/$ref}"
			line="${line//REPLACE_WITH_EXACT_COMMIT/$exact_commit}"
			line="${line//REPLACE_WITH_TAGGED_STANDARDS_INDEX_URL/$standards_index_url}"
			line="${line//REPLACE_WITH_AUDIT_MANIFEST_PATH/$audit_destination}"
			line="${line//REPLACE_WITH_LAST_OPERATION/$last_operation}"
			line="${line//REPLACE_WITH_LAST_UPDATED_UTC/$last_updated_utc}"
			line="${line//REPLACE_WITH_MANAGED_SIDECAR_PATH/$sidecar_destination}"
			line="${line//REPLACE_WITH_AUTO_UPDATE_MODE/$auto_update_mode}"
			line="${line//REPLACE_WITH_AUTO_UPDATE_REASON/$auto_update_reason}"
			line="${line//REPLACE_WITH_CHECKS_CI_MODE/$checks_ci_mode}"
			line="${line//REPLACE_WITH_CHECKS_CI_REASON/$checks_ci_reason}"
			line="${line//REPLACE_WITH_AUTO_UPDATE_SCRIPT_PATH/$auto_update_script_destination}"
			line="${line//REPLACE_WITH_AUTO_UPDATE_BRANCH/$auto_update_branch}"
			line="${line//REPLACE_WITH_AUTO_UPDATE_COMMIT_MESSAGE/$auto_update_commit_message}"
			line="${line//REPLACE_WITH_AUTO_UPDATE_CRON/$auto_update_cron}"
			printf '%s\n' "$line"
		done <"$source_path"
	} >"$output_path"
}

should_mdformat_whole_file_managed_markdown() {
	local relative_destination="$1"

	case "$relative_destination" in
	"${sidecar_destination}" | ".github/pull_request_template.md" | "${audit_destination}" | "${legacy_audit_destination}")
		return 0
		;;
	*)
		return 1
		;;
	esac
}

maybe_mdformat_whole_file_managed_markdown() {
	local file_path="$1"
	local relative_destination="$2"

	[[ "$relative_destination" == *.md ]] || return 0
	should_mdformat_whole_file_managed_markdown "$relative_destination" || return 0
	ensure_managed_markdown_mdformat || return 0

	run_managed_markdown_mdformat "$file_path" >/dev/null 2>&1 || die "mdformat failed for ${relative_destination}"
}

render_template_to_tmp_path() {
	local source_path="$1"
	local tmp_stem="$2"
	local managed_files_markdown="${3:-}"
	local relative_destination="${4:-}"
	local downloaded_path=""
	local rendered_path=""

	ensure_tmp_dir
	downloaded_path="${tmp_dir}/${tmp_stem}.source"
	rendered_path="${tmp_dir}/${tmp_stem}.rendered"
	rm -f "$downloaded_path" "$rendered_path"

	if ! download_file "$source_path" "$downloaded_path"; then
		return 1
	fi

	if ! render_template_file "$downloaded_path" "$rendered_path" "$managed_files_markdown" "$relative_destination" "enabled"; then
		rm -f "$rendered_path"
		return 1
	fi

	if [[ ! -s "$rendered_path" ]]; then
		printf 'error: rendered managed source is empty: %s\n' "$source_path" >&2
		rm -f "$rendered_path"
		return 1
	fi

	printf '%s\n' "$rendered_path"
}

render_template_to_tmp_path_for_install_state() {
	local source_path="$1"
	local tmp_stem="$2"
	local relative_destination="$3"
	local managed_files_markdown="${4:-}"
	local include_managed_file_marker="${5:-enabled}"
	local compare_downstream_owner="${6-__CURRENT__}"
	local prefer_local_source="${7:-enabled}"
	local compare_repo_url="${current_source:-$repo_url}"
	local compare_requested_ref="${current_ref:-$ref}"
	local compare_exact_commit="${current_exact_commit:-$exact_commit}"
	local compare_entrypoint="${current_entrypoint:-}"
	local compare_auto_update_mode="${current_auto_update:-$auto_update_mode}"
	local compare_auto_update_reason="${current_auto_update_reason:-$auto_update_reason}"
	local compare_checks_ci_mode="${current_checks_ci:-$checks_ci_mode}"
	local compare_checks_ci_reason="${current_checks_ci_reason:-$checks_ci_reason}"
	local compare_owner_specific_guidance_markdown=""
	local compare_last_operation="${current_last_operation:-}"
	local compare_last_updated_utc="${current_last_updated_utc:-}"
	local manager_repo_slug="$repo_slug"
	local manager_requested_ref="$ref"
	local manager_exact_commit="$exact_commit"
	local repo_url=""
	local ref=""
	local exact_commit=""
	local standards_index_url=""
	local auto_update_mode=""
	local auto_update_reason=""
	local checks_ci_mode=""
	local checks_ci_reason=""
	local last_operation=""
	local last_updated_utc=""
	local downloaded_path=""
	local rendered_path=""

	if [[ -z "$compare_entrypoint" ]]; then
		compare_entrypoint="${compare_repo_url}/blob/${compare_requested_ref}/standards/index.md"
	fi

	repo_url="$compare_repo_url"
	ref="$compare_requested_ref"
	exact_commit="$compare_exact_commit"
	standards_index_url="$compare_entrypoint"
	auto_update_mode="$compare_auto_update_mode"
	auto_update_reason="$compare_auto_update_reason"
	checks_ci_mode="$compare_checks_ci_mode"
	checks_ci_reason="$compare_checks_ci_reason"
	last_operation="$compare_last_operation"
	last_updated_utc="$compare_last_updated_utc"

	if [[ "$compare_downstream_owner" == "__CURRENT__" ]]; then
		compare_owner_specific_guidance_markdown="$owner_specific_guidance_markdown"
	else
		compare_owner_specific_guidance_markdown="$(build_owner_specific_guidance_markdown "$compare_downstream_owner")"
	fi

	ensure_tmp_dir
	downloaded_path="${tmp_dir}/${tmp_stem}.source"
	rendered_path="${tmp_dir}/${tmp_stem}.rendered"
	if ! download_file_for_install_state_rendering "$source_path" "$downloaded_path" "$compare_repo_url" "$compare_requested_ref" "$compare_exact_commit" "$manager_repo_slug" "$manager_requested_ref" "$manager_exact_commit" "$prefer_local_source"; then
		printf '\n'
		return 0
	fi

	if ! render_template_file "$downloaded_path" "$rendered_path" "$managed_files_markdown" "$relative_destination" "$include_managed_file_marker" "$compare_owner_specific_guidance_markdown"; then
		rm -f "$rendered_path"
		printf '\n'
		return 0
	fi

	if [[ ! -s "$rendered_path" ]]; then
		rm -f "$rendered_path"
		printf '\n'
		return 0
	fi

	printf '%s\n' "$rendered_path"
}

rewrite_rendered_file_for_legacy_identity() {
	local input_path="$1"
	local output_path="$2"
	local relative_destination="$3"
	local line=""
	local skip_legacy_helper_fallback_block=0
	local skip_legacy_helper_manifest_function=0
	local skip_legacy_helper_manifest_loop=0
	local skip_legacy_helper_token_block=0
	local skip_legacy_helper_token_function=0
	local skip_legacy_helper_token_fallback_depth=0
	local skip_legacy_workflow_repair_prompt=0
	local skip_next_legacy_workflow_blank=0
	local previous_auto_update_line_blank=0

	# Legacy state matching renders current sources backward, so new token-only
	# sections must disappear without weakening exact-match drift detection.
	{
		while IFS= read -r line || [[ -n "$line" ]]; do
			if [[ "$relative_destination" == "$auto_update_workflow_destination" && "$skip_next_legacy_workflow_blank" -eq 1 ]]; then
				skip_next_legacy_workflow_blank=0
				[[ -n "$line" ]] || continue
			fi
			if [[ "$relative_destination" == "$auto_update_workflow_destination" && "$skip_legacy_workflow_repair_prompt" -eq 1 ]]; then
				if [[ "$line" == "          Never print or paste the token value. External adopters should replace the token-file path with their own secure local path." ]]; then
					skip_legacy_workflow_repair_prompt=0
				fi
				continue
			fi
			if [[ "$relative_destination" == "$auto_update_script_destination" && "$skip_legacy_helper_fallback_block" -eq 1 ]]; then
				if [[ "$line" == "fi" ]]; then
					skip_legacy_helper_fallback_block=0
				fi
				continue
			fi
			if [[ "$relative_destination" == "$auto_update_script_destination" && "$skip_legacy_helper_manifest_function" -eq 1 ]]; then
				if [[ "$line" == "}" ]]; then
					skip_legacy_helper_manifest_function=0
				fi
				continue
			fi
			if [[ "$relative_destination" == "$auto_update_script_destination" && "$skip_legacy_helper_manifest_loop" -eq 1 ]]; then
				if [[ "$line" == *'done < <(print_audit_manifest_paths)' ]]; then
					skip_legacy_helper_manifest_loop=0
				fi
				continue
			fi
			if [[ "$relative_destination" == "$auto_update_script_destination" && "$skip_legacy_helper_token_function" -eq 1 ]]; then
				if [[ "$line" == "}" ]]; then
					skip_legacy_helper_token_function=0
				fi
				continue
			fi
			if [[ "$relative_destination" == "$auto_update_script_destination" && "$skip_legacy_helper_token_block" -eq 1 ]]; then
				if [[ "$line" == "fi" ]]; then
					skip_legacy_helper_token_block=0
				fi
				continue
			fi
			if [[ "$relative_destination" == "$auto_update_script_destination" && "$skip_legacy_helper_token_fallback_depth" -gt 0 ]]; then
				if [[ "$line" =~ ^[[:space:]]*if\ .* ]]; then
					skip_legacy_helper_token_fallback_depth=$((skip_legacy_helper_token_fallback_depth + 1))
				elif [[ "$line" =~ ^[[:space:]]*fi$ ]]; then
					skip_legacy_helper_token_fallback_depth=$((skip_legacy_helper_token_fallback_depth - 1))
				fi
				continue
			fi

			line="${line//bright-builds-rules-managed-file: /coding-and-architecture-requirements-managed-file: }"
			line="${line//${agents_block_begin}/${legacy_agents_block_begin}}"
			line="${line//${agents_block_end}/${legacy_agents_block_end}}"
			line="${line//${readme_badges_begin}/${legacy_readme_badges_begin}}"
			line="${line//${readme_badges_end}/${legacy_readme_badges_end}}"
			line="${line//Bright Builds Rules default workflow/Bright Builds default workflow}"
			line="${line//Bright Builds Rules defaults/Bright Builds defaults}"
			line="${line//Bright Builds Rules standards page/Bright Builds standards page}"
			line="${line//Bright Builds Rules guidance/Bright Builds guidance}"
			line="${line//Bright Builds Rules specification./Bright Builds specification.}"
			line="${line//Bright Builds Rules spec./Bright Builds spec.}"
			line="${line//Bright Builds Rules block/Bright Builds block}"

			case "$relative_destination" in
			"${agents_destination}")
				line="${line//# Bright Builds Rules/# Bright Builds Standards}"
				;;
			"${audit_destination}" | "${legacy_audit_destination}")
				line="${line//# Bright Builds Rules Audit Trail/# Coding and Architecture Requirements Audit Trail}"
				line="${line//This file records that this repository is using the Bright Builds Rules and shows where the managed adoption files came from./This file records that this repository is using the Bright Builds coding and architecture requirements and shows where the managed adoption files came from.}"
				;;
			"${auto_update_workflow_destination}")
				if [[ "$line" == *"BRIGHT_BUILDS_PUSH_TOKEN_CONFIGURED:"* ]]; then
					continue
				fi
				if [[ "$line" == "          4. If downstream drift/configuration caused it, report the downstream fix and do not hand-edit fully managed files." ]]; then
					skip_next_legacy_workflow_blank=1
				fi
				if [[ "$line" == "          If the failure mentions BRIGHT_BUILDS_PUSH_TOKEN, repository access, or \"without workflows permission\", run this repair flow from the Bright Builds operator workstation:" ]]; then
					skip_legacy_workflow_repair_prompt=1
					continue
				fi
				;;
			"${auto_update_script_destination}")
				if [[ "$line" == '# Managed upstream by bright-builds-rules.' ]]; then
					continue
				fi
				if [[ "$line" == '# If this helper needs a fix, open an upstream PR or issue instead of editing the downstream managed copy.' ]]; then
					continue
				fi
				if [[ "$line" == 'auto_update_workflow_path=".github/workflows/bright-builds-auto-update.yml"' ||
					"$line" == 'checks_workflow_path=".github/workflows/bright-builds-checks.yml"' ||
					"$line" == 'bright_builds_push_token_file="/Users/peterryszkiewicz/Repos/BRIGHT_BUILDS_PUSH_TOKEN.txt"' ||
					"$line" == 'direct_push_output_path="${tmp_dir}/direct-push.output"' ||
					"$line" == 'fallback_push_output_path="${tmp_dir}/fallback-push.output"' ]]; then
					continue
				fi
				if [[ "$line" == "print_push_token_repair() {" ||
					"$line" == "push_failure_requires_token_repair() {" ||
					"$line" == "run_git_push() {" ||
					"$line" == "workflow_update_is_staged() {" ||
					"$line" == "managed_workflow_update_is_staged() {" ||
					"$line" == "fail_for_push_token() {" ]]; then
					skip_legacy_helper_token_function=1
					continue
				fi
				if [[ "$line" == 'print_audit_manifest_paths() {' ]]; then
					skip_legacy_helper_manifest_function=1
					continue
				fi
				if [[ "$line" == $'\twhile IFS= read -r relative_path; do' ]]; then
					skip_legacy_helper_manifest_loop=1
					continue
				fi
				case "$line" in
				*"standards/"*" \\")
					continue
					;;
				*".github/workflows/bright-builds-checks.yml"* | *"scripts/bright-builds-check.ts"*)
					continue
					;;
				esac
				if [[ "$line" == 'legacy_audit_path="coding-and-architecture-requirements.audit.md"' ]]; then
					continue
				fi
				if [[ "$line" == *'bright-builds-rules.audit.md \' ]]; then
					line="${line//bright-builds-rules.audit.md/coding-and-architecture-requirements.audit.md}"
				elif [[ "$line" == *'coding-and-architecture-requirements.audit.md \' ]]; then
					continue
				fi
				if [[ "$line" == 'if [[ ! -f "$audit_path" && -f "$legacy_audit_path" ]]; then' ]]; then
					skip_legacy_helper_fallback_block=1
					continue
				fi
				if [[ "$line" == 'if workflow_update_is_staged && [[ "${BRIGHT_BUILDS_PUSH_TOKEN_CONFIGURED:-}" == "false" ]]; then' ||
					"$line" == 'if managed_workflow_update_is_staged && [[ "${BRIGHT_BUILDS_PUSH_TOKEN_CONFIGURED:-}" == "false" ]]; then' ||
					"$line" == 'if push_failure_requires_token_repair "$direct_push_output_path"; then' ]]; then
					skip_legacy_helper_token_block=1
					continue
				fi
				if [[ "$line" == 'if run_git_push "$direct_push_output_path" origin HEAD:"${default_branch}"; then' ]]; then
					line='if git push origin HEAD:"${default_branch}" >/dev/null 2>&1; then'
				fi
				if [[ "$line" == 'if ! run_git_push "$fallback_push_output_path" --force-with-lease origin HEAD:"${update_branch}"; then' ]]; then
					printf '%s\n' 'git push --force-with-lease origin HEAD:"${update_branch}" >/dev/null'
					skip_legacy_helper_token_fallback_depth=1
					continue
				fi
				if [[ "$line" == 'status_output="$(bash "$installer_path" status --repo "$repo_slug" --ref "$ref" --repo-root "$repo_root" 2>&1)"' ]]; then
					line='status_output="$(bash "$installer_path" status --repo-root "$repo_root" 2>&1)"'
				fi
				if [[ "$line" == 'update_output="$(bash "$installer_path" update --repo "$repo_slug" --ref "$ref" --repo-root "$repo_root" 2>&1)"' ]]; then
					line='update_output="$(bash "$installer_path" update --repo-root "$repo_root" 2>&1)"'
				fi
				if [[ "$line" == 'git -c user.name="$github_actions_name" -c user.email="$github_actions_email" commit -m "$commit_message" >/dev/null' ]]; then
					printf '%s\n' 'git config user.name "$github_actions_name"'
					printf '%s\n' 'git config user.email "$github_actions_email"'
					printf '\n'
					line='git commit -m "$commit_message" >/dev/null'
				fi
				line="${line//git add -f -A --/git add -A --}"
				line="${line//Automated Bright Builds Rules update./Automated Bright Builds requirements update.}"
				;;
			esac

			if [[ "$relative_destination" == "$auto_update_script_destination" ]]; then
				if [[ "$line" =~ ^[[:space:]]*$ ]]; then
					if [[ "$previous_auto_update_line_blank" -eq 1 ]]; then
						continue
					fi
					previous_auto_update_line_blank=1
				else
					previous_auto_update_line_blank=0
				fi
			fi

			printf '%s\n' "$line"
		done <"$input_path"
	} >"$output_path"
}

render_template_to_legacy_identity_tmp_path_for_install_state() {
	local source_path="$1"
	local tmp_stem="$2"
	local relative_destination="$3"
	local managed_files_markdown="${4:-}"
	local include_managed_file_marker="${5:-enabled}"
	local compare_downstream_owner="${6-__CURRENT__}"
	local compare_repo_url="${current_source:-$legacy_bright_builds_url}"
	local compare_requested_ref="${current_ref:-$ref}"
	local compare_exact_commit="${current_exact_commit:-$exact_commit}"
	local compare_entrypoint="${current_entrypoint:-}"
	local compare_auto_update_mode="${current_auto_update:-$auto_update_mode}"
	local compare_auto_update_reason="${current_auto_update_reason:-$auto_update_reason}"
	local compare_checks_ci_mode="${current_checks_ci:-$checks_ci_mode}"
	local compare_checks_ci_reason="${current_checks_ci_reason:-$checks_ci_reason}"
	local compare_last_operation="${current_last_operation:-}"
	local compare_last_updated_utc="${current_last_updated_utc:-}"
	local compare_owner_specific_guidance_markdown=""
	local manager_repo_slug="$repo_slug"
	local manager_requested_ref="$ref"
	local manager_exact_commit="$exact_commit"
	local repo_url=""
	local ref=""
	local exact_commit=""
	local standards_index_url=""
	local auto_update_mode=""
	local auto_update_reason=""
	local checks_ci_mode=""
	local checks_ci_reason=""
	local last_operation=""
	local last_updated_utc=""
	local audit_destination="$legacy_audit_destination"
	local managed_file_marker_prefix="$legacy_managed_file_marker_prefix"
	local auto_update_commit_message="$legacy_auto_update_commit_message"
	local downloaded_path=""
	local rendered_path=""
	local compat_rendered_path=""

	if [[ -z "$compare_entrypoint" ]]; then
		compare_entrypoint="${compare_repo_url}/blob/${compare_requested_ref}/standards/index.md"
	fi

	repo_url="$compare_repo_url"
	ref="$compare_requested_ref"
	exact_commit="$compare_exact_commit"
	standards_index_url="$compare_entrypoint"
	auto_update_mode="$compare_auto_update_mode"
	auto_update_reason="$compare_auto_update_reason"
	checks_ci_mode="$compare_checks_ci_mode"
	checks_ci_reason="$compare_checks_ci_reason"
	last_operation="$compare_last_operation"
	last_updated_utc="$compare_last_updated_utc"

	if [[ "$compare_downstream_owner" == "__CURRENT__" ]]; then
		compare_owner_specific_guidance_markdown="$owner_specific_guidance_markdown"
	else
		compare_owner_specific_guidance_markdown="$(build_owner_specific_guidance_markdown "$compare_downstream_owner")"
	fi

	ensure_tmp_dir
	downloaded_path="${tmp_dir}/${tmp_stem}.legacy.source"
	rendered_path="${tmp_dir}/${tmp_stem}.legacy.rendered"
	compat_rendered_path="${tmp_dir}/${tmp_stem}.legacy.compat.rendered"
	if ! download_file_for_install_state_rendering "$source_path" "$downloaded_path" "" "" "" "$manager_repo_slug" "$manager_requested_ref" "$manager_exact_commit"; then
		printf '\n'
		return 0
	fi

	if ! render_template_file "$downloaded_path" "$rendered_path" "$managed_files_markdown" "$relative_destination" "$include_managed_file_marker" "$compare_owner_specific_guidance_markdown"; then
		rm -f "$rendered_path"
		printf '\n'
		return 0
	fi

	if [[ ! -s "$rendered_path" ]] ||
		! rewrite_rendered_file_for_legacy_identity "$rendered_path" "$compat_rendered_path" "$relative_destination" ||
		[[ ! -s "$compat_rendered_path" ]]; then
		rm -f "$rendered_path" "$compat_rendered_path"
		printf '\n'
		return 0
	fi

	printf '%s\n' "$compat_rendered_path"
}

prerename_compat_source_path_for_relative_destination() {
	local relative_destination="$1"

	case "$relative_destination" in
	"${sidecar_destination}")
		printf '%s\n' "$prerename_compat_sidecar_source"
		;;
	"CONTRIBUTING.md")
		printf '%s\n' "$prerename_compat_contributing_source"
		;;
	".github/pull_request_template.md")
		printf '%s\n' "$prerename_compat_pull_request_template_source"
		;;
	"${audit_destination}" | "${legacy_audit_destination}")
		printf '%s\n' "$prerename_compat_audit_source"
		;;
	"${auto_update_script_destination}")
		printf '%s\n' "$prerename_compat_auto_update_script_source"
		;;
	"${auto_update_workflow_destination}")
		printf '%s\n' "$prerename_compat_auto_update_workflow_source"
		;;
	esac
}

current_whole_file_compat_source_path_for_relative_destination() {
	local relative_destination="$1"

	case "$relative_destination" in
	"${audit_destination}" | "${legacy_audit_destination}")
		printf '%s\n' "$current_audit_whole_file_compat_source"
		;;
	esac
}

render_template_to_prerename_compat_tmp_path_for_install_state() {
	local tmp_stem="$1"
	local relative_destination="$2"
	local managed_files_markdown="${3:-}"
	local include_managed_file_marker="${4:-enabled}"
	local compare_downstream_owner="${5-__CURRENT__}"
	local compare_repo_url="${current_source:-$legacy_bright_builds_url}"
	local compare_requested_ref="${current_ref:-$ref}"
	local compare_exact_commit="${current_exact_commit:-$exact_commit}"
	local compare_entrypoint="${current_entrypoint:-}"
	local compare_auto_update_mode="${current_auto_update:-$auto_update_mode}"
	local compare_auto_update_reason="${current_auto_update_reason:-$auto_update_reason}"
	local compare_checks_ci_mode="${current_checks_ci:-$checks_ci_mode}"
	local compare_checks_ci_reason="${current_checks_ci_reason:-$checks_ci_reason}"
	local compare_last_operation="${current_last_operation:-}"
	local compare_last_updated_utc="${current_last_updated_utc:-}"
	local compare_owner_specific_guidance_markdown=""
	local manager_repo_slug="$repo_slug"
	local manager_requested_ref="$ref"
	local manager_exact_commit="$exact_commit"
	local compat_source_path=""
	local repo_url=""
	local ref=""
	local exact_commit=""
	local standards_index_url=""
	local auto_update_mode=""
	local auto_update_reason=""
	local checks_ci_mode=""
	local checks_ci_reason=""
	local last_operation=""
	local last_updated_utc=""
	local audit_destination="$legacy_audit_destination"
	local managed_file_marker_prefix="$legacy_managed_file_marker_prefix"
	local auto_update_commit_message="$legacy_auto_update_commit_message"
	local downloaded_path=""
	local rendered_path=""

	compat_source_path="$(prerename_compat_source_path_for_relative_destination "$relative_destination")"
	if [[ -z "$compat_source_path" ]]; then
		printf '\n'
		return 0
	fi

	if [[ -z "$compare_entrypoint" ]]; then
		compare_entrypoint="${compare_repo_url}/blob/${compare_requested_ref}/standards/index.md"
	fi

	repo_url="$compare_repo_url"
	ref="$compare_requested_ref"
	exact_commit="$compare_exact_commit"
	standards_index_url="$compare_entrypoint"
	auto_update_mode="$compare_auto_update_mode"
	auto_update_reason="$compare_auto_update_reason"
	checks_ci_mode="$compare_checks_ci_mode"
	checks_ci_reason="$compare_checks_ci_reason"
	last_operation="$compare_last_operation"
	last_updated_utc="$compare_last_updated_utc"

	if [[ "$compare_downstream_owner" == "__CURRENT__" ]]; then
		compare_owner_specific_guidance_markdown="$owner_specific_guidance_markdown"
	else
		compare_owner_specific_guidance_markdown="$(build_owner_specific_guidance_markdown "$compare_downstream_owner")"
	fi

	ensure_tmp_dir
	downloaded_path="${tmp_dir}/${tmp_stem}.prerename-compat.source"
	rendered_path="${tmp_dir}/${tmp_stem}.prerename-compat.rendered"
	if ! download_file_for_install_state_rendering "$compat_source_path" "$downloaded_path" "" "" "" "$manager_repo_slug" "$manager_requested_ref" "$manager_exact_commit"; then
		printf '\n'
		return 0
	fi

	if ! render_template_file "$downloaded_path" "$rendered_path" "$managed_files_markdown" "$relative_destination" "$include_managed_file_marker" "$compare_owner_specific_guidance_markdown"; then
		rm -f "$rendered_path"
		printf '\n'
		return 0
	fi

	if [[ ! -s "$rendered_path" ]]; then
		rm -f "$rendered_path"
		printf '\n'
		return 0
	fi

	printf '%s\n' "$rendered_path"
}

write_rendered_file() {
	local source_path="$1"
	local relative_destination="$2"
	local managed_files_markdown="${3:-}"
	local destination_path="${repo_root}/${relative_destination}"
	local rendered_path=""
	local updated_path=""

	if ! rendered_path="$(render_template_to_tmp_path "$source_path" "$(basename "$relative_destination")" "$managed_files_markdown" "$relative_destination")"; then
		die "unable to prepare managed file ${relative_destination} from ${source_path}"
	fi

	mkdir -p "$(dirname "$destination_path")"
	ensure_tmp_dir
	updated_path="${tmp_dir}/$(basename "$relative_destination").write"
	cp "$rendered_path" "$updated_path"
	maybe_mdformat_whole_file_managed_markdown "$updated_path" "$relative_destination"
	mv "$updated_path" "$destination_path"
	note "Wrote ${relative_destination}"
}
