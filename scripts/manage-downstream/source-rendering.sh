download_file() {
	local source_path="$1"
	local output_path="$2"
	local maybe_local_source_path=""

	maybe_local_source_path="${local_source_root}/${source_path}"

	if [[ -n "$local_source_root" && -f "$maybe_local_source_path" ]]; then
		cp "$maybe_local_source_path" "$output_path"
		return
	fi

	require_command curl
	curl -fsSL "${raw_base}/${source_path}" -o "$output_path"
}

download_file_if_available_from_raw_base() {
	local candidate_raw_base="$1"
	local source_path="$2"
	local output_path="$3"

	[[ -n "$candidate_raw_base" ]] || return 1

	require_command curl
	rm -f "$output_path"
	if curl -fsSL "${candidate_raw_base}/${source_path}" -o "$output_path" >/dev/null 2>&1; then
		return 0
	fi

	rm -f "$output_path"
	return 1
}

download_file_if_available_from_local_git_ref() {
	local source_path="$1"
	local output_path="$2"
	local candidate_ref="$3"

	[[ -n "$local_source_root" ]] || return 1
	[[ -n "$candidate_ref" ]] || return 1
	[[ "$candidate_ref" != "$exact_commit_unavailable" ]] || return 1
	command -v git >/dev/null 2>&1 || return 1
	git -C "$local_source_root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
	git -C "$local_source_root" cat-file -e "${candidate_ref}:${source_path}" >/dev/null 2>&1 || return 1
	git -C "$local_source_root" show "${candidate_ref}:${source_path}" >"$output_path"
}

download_file_for_install_state_candidate() {
	local source_path="$1"
	local output_path="$2"
	local candidate_repo_slug="$3"
	local candidate_ref="$4"
	local candidate_raw_base=""

	[[ -n "$candidate_repo_slug" ]] || return 1
	[[ -n "$candidate_ref" ]] || return 1
	[[ "$candidate_ref" != "$exact_commit_unavailable" ]] || return 1

	if download_file_if_available_from_local_git_ref "$source_path" "$output_path" "$candidate_ref"; then
		return 0
	fi

	candidate_raw_base="https://raw.githubusercontent.com/${candidate_repo_slug}/${candidate_ref}"
	download_file_if_available_from_raw_base "$candidate_raw_base" "$source_path" "$output_path"
}

download_file_for_install_state_rendering() {
	local source_path="$1"
	local output_path="$2"
	local compare_repo_url="$3"
	local compare_requested_ref="$4"
	local compare_exact_commit="$5"
	local manager_repo_slug="$6"
	local manager_requested_ref="$7"
	local manager_exact_commit="$8"
	local prefer_local_source="${9:-enabled}"
	local maybe_local_source_path=""
	local compare_repo_slug=""

	compare_repo_slug="$(extract_repo_slug_from_url "$compare_repo_url")"
	maybe_local_source_path="${local_source_root}/${source_path}"
	if [[ "$prefer_local_source" == "enabled" && "$compare_exact_commit" == "$manager_exact_commit" && -n "$local_source_root" && -f "$maybe_local_source_path" ]]; then
		cp "$maybe_local_source_path" "$output_path"
		return 0
	fi

	if download_file_for_install_state_candidate "$source_path" "$output_path" "$compare_repo_slug" "$compare_exact_commit"; then
		return 0
	fi

	if download_file_for_install_state_candidate "$source_path" "$output_path" "$compare_repo_slug" "$compare_requested_ref"; then
		return 0
	fi

	if [[ -z "$compare_repo_slug" ]] || is_legacy_source_repository_url "$compare_repo_url"; then
		if download_file_for_install_state_candidate "$source_path" "$output_path" "$manager_repo_slug" "$manager_exact_commit"; then
			return 0
		fi

		if download_file_for_install_state_candidate "$source_path" "$output_path" "$manager_repo_slug" "$manager_requested_ref"; then
			return 0
		fi
	fi

	rm -f "$output_path"
	return 1
}

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
			if [[ "$line" == "$managed_file_marker_placeholder" ]]; then
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

	mdformat "$file_path" >/dev/null 2>&1 || die "mdformat failed for ${relative_destination}"
}

resolve_exact_commit() {
	local resolved_commit=""
	local remote_url=""
	local ls_remote_output=""

	if is_full_commit_sha "$ref"; then
		exact_commit="$(normalize_commit_sha "$ref")"
		return
	fi

	if command -v git >/dev/null 2>&1 && [[ -n "$local_source_root" ]]; then
		if resolved_commit="$(git -C "$local_source_root" rev-parse HEAD 2>/dev/null)" && is_full_commit_sha "$resolved_commit"; then
			exact_commit="$(normalize_commit_sha "$resolved_commit")"
			return
		fi
	fi

	if ! command -v git >/dev/null 2>&1; then
		exact_commit="$exact_commit_unavailable"
		return
	fi

	remote_url="https://github.com/${repo_slug}.git"

	if ! ls_remote_output="$(git ls-remote "$remote_url" "$ref" "$ref^{}" 2>/dev/null)" || [[ -z "$ls_remote_output" ]]; then
		exact_commit="$exact_commit_unavailable"
		return
	fi

	resolved_commit="$(printf '%s\n' "$ls_remote_output" | awk '
    $2 ~ /\^\{\}$/ {
      print $1
      found = 1
      exit
    }

    NR == 1 && first == "" {
      first = $1
    }

    END {
      if (found != 1 && first != "") {
        print first
      }
    }
  ')"

	if is_full_commit_sha "$resolved_commit"; then
		exact_commit="$(normalize_commit_sha "$resolved_commit")"
		return
	fi

	exact_commit="$exact_commit_unavailable"
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
	download_file "$source_path" "$downloaded_path"
	render_template_file "$downloaded_path" "$rendered_path" "$managed_files_markdown" "$relative_destination" "enabled"
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

	render_template_file "$downloaded_path" "$rendered_path" "$managed_files_markdown" "$relative_destination" "$include_managed_file_marker" "$compare_owner_specific_guidance_markdown"
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
	local previous_auto_update_line_blank=0

	{
		while IFS= read -r line || [[ -n "$line" ]]; do
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
			"${auto_update_script_destination}")
				if [[ "$line" == '# Managed upstream by bright-builds-rules.' ]]; then
					continue
				fi
				if [[ "$line" == '# If this helper needs a fix, open an upstream PR or issue instead of editing the downstream managed copy.' ]]; then
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

	render_template_file "$downloaded_path" "$rendered_path" "$managed_files_markdown" "$relative_destination" "$include_managed_file_marker" "$compare_owner_specific_guidance_markdown"
	rewrite_rendered_file_for_legacy_identity "$rendered_path" "$compat_rendered_path" "$relative_destination"
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

	render_template_file "$downloaded_path" "$rendered_path" "$managed_files_markdown" "$relative_destination" "$include_managed_file_marker" "$compare_owner_specific_guidance_markdown"
	printf '%s\n' "$rendered_path"
}

write_rendered_file() {
	local source_path="$1"
	local relative_destination="$2"
	local managed_files_markdown="${3:-}"
	local destination_path="${repo_root}/${relative_destination}"
	local rendered_path=""
	local updated_path=""

	rendered_path="$(render_template_to_tmp_path "$source_path" "$(basename "$relative_destination")" "$managed_files_markdown" "$relative_destination")"
	mkdir -p "$(dirname "$destination_path")"
	ensure_tmp_dir
	updated_path="${tmp_dir}/$(basename "$relative_destination").write"
	cp "$rendered_path" "$updated_path"
	maybe_mdformat_whole_file_managed_markdown "$updated_path" "$relative_destination"
	mv "$updated_path" "$destination_path"
	note "Wrote ${relative_destination}"
}
