remove_or_update_contributing_file_for_uninstall() {
	local destination_path="${repo_root}/${contributing_destination}"
	local state=""
	local updated_path=""
	local trimmed_path=""

	state="$(resolve_contributing_file_state)"

	case "$state" in
	block-clean)
		ensure_tmp_dir
		updated_path="${tmp_dir}/CONTRIBUTING.unmanaged"
		trimmed_path="${tmp_dir}/CONTRIBUTING.trimmed"
		remove_contributing_block "$destination_path" "$updated_path"
		trim_trailing_blank_lines "$updated_path" "$trimmed_path"

		if file_has_non_whitespace "$trimmed_path"; then
			cp "$trimmed_path" "$destination_path"
			note "Updated ${contributing_destination}"
		else
			rm -f "$destination_path"
			note "Removed ${contributing_destination}"
		fi
		;;
	partial | block-drifted)
		note "Skipped ${contributing_destination} because the managed block has downstream edits"
		;;
	whole-file-clean)
		rm -f "$destination_path"
		note "Removed ${contributing_destination}"
		;;
	unmanaged-or-whole-file-drifted)
		if [[ -f "$destination_path" ]]; then
			note "Skipped ${contributing_destination} because it has downstream edits"
		fi
		;;
	esac
}

sync_auto_update_files() {
	if [[ "$auto_update_mode" == "enabled" ]]; then
		write_rendered_file "$auto_update_script_source" "$auto_update_script_destination"
		write_rendered_file "$auto_update_workflow_source" "$auto_update_workflow_destination"
		return
	fi

	if [[ "$current_auto_update" == "enabled" ]]; then
		remove_auto_update_files
	fi
}

managed_auto_update_helper_lacks_standards_staging() {
	local helper_path="${repo_root}/${auto_update_script_destination}"
	local managed_marker=""

	[[ -f "$helper_path" ]] || return 1
	managed_marker="$(build_managed_file_marker_line "$auto_update_script_destination")"
	grep -Fxq "$managed_marker" "$helper_path" || return 1
	! grep -Fq "standards/languages/typescript-javascript.md" "$helper_path"
}

record_legacy_auto_update_helper_staging_need() {
	local operation="$1"

	legacy_auto_update_helper_needs_standards_staging=0

	[[ "$operation" == "update" ]] || return 0
	[[ "${GITHUB_ACTIONS:-}" == "true" ]] || return 0
	[[ "$auto_update_mode" == "enabled" || "$current_auto_update" == "enabled" ]] || return 0
	managed_auto_update_helper_lacks_standards_staging || return 0

	legacy_auto_update_helper_needs_standards_staging=1
}

stage_legacy_auto_update_standards_for_github_actions() {
	[[ "$legacy_auto_update_helper_needs_standards_staging" -eq 1 ]] || return 0
	[[ "${GITHUB_ACTIONS:-}" == "true" ]] || return 0
	command -v git >/dev/null 2>&1 || return 0

	if ! git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		return 0
	fi

	git -C "$repo_root" add -f -A -- "${managed_standards_paths[@]}"
	note "Staged managed standards for legacy auto-update helper compatibility."
}

write_or_update_readme_file() {
	local destination_path="${repo_root}/${readme_destination}"
	local current_state=""
	local rendered_block_path=""
	local base_path=""
	local updated_path=""
	local trimmed_path=""
	local normalized_path=""
	local remove_insertion_zone_legacy=0

	current_state="$(resolve_readme_badge_state)"

	if [[ "$readme_has_managed_badges" -eq 1 ]]; then
		remove_insertion_zone_legacy=1
	fi

	if [[ "$readme_has_managed_badges" -ne 1 ]]; then
		if [[ -f "$destination_path" ]]; then
			ensure_tmp_dir
			normalized_path="${tmp_dir}/README.normalized"
			trimmed_path="${tmp_dir}/README.normalized.trimmed"

			if [[ "$current_state" == "present" ]]; then
				updated_path="${tmp_dir}/README.unmanaged"
				remove_readme_badges_block "$destination_path" "$updated_path"
				normalize_legacy_bright_builds_readme_badges "$updated_path" "$normalized_path" 0
			else
				normalize_legacy_bright_builds_readme_badges "$destination_path" "$normalized_path" 0
			fi

			trim_trailing_blank_lines "$normalized_path" "$trimmed_path"

			if ! cmp -s "$destination_path" "$trimmed_path"; then
				if file_has_non_whitespace "$trimmed_path"; then
					cp "$trimmed_path" "$destination_path"
					note "Updated ${readme_destination}"
				else
					rm -f "$destination_path"
					note "Removed ${readme_destination}"
				fi
			fi
		fi

		if [[ "$current_state" == "present" ]]; then
			current_state="absent"
		fi

		readme_badge_state="$(resolve_readme_badge_state)"
		return
	fi

	rendered_block_path="$(render_readme_badges_block_to_tmp_path)"

	if [[ ! -f "$destination_path" ]] || ! file_has_non_whitespace "$destination_path"; then
		ensure_tmp_dir
		updated_path="${tmp_dir}/README.generated"
		{
			build_readme_title
			printf '\n'
			cat "$rendered_block_path"
		} >"$updated_path"
		cp "$updated_path" "$destination_path"
		note "Wrote ${readme_destination}"
		readme_badge_state="$(resolve_readme_badge_state)"
		return
	fi

	case "$current_state" in
	partial | ambiguous)
		die "${readme_destination} contains conflicting badge content. Re-run install --force to back up and repair it."
		;;
	esac

	ensure_tmp_dir
	base_path="${tmp_dir}/README.base"
	updated_path="${tmp_dir}/README.updated"
	trimmed_path="${tmp_dir}/README.updated.trimmed"

	if [[ "$current_state" == "present" ]]; then
		remove_readme_badges_block "$destination_path" "$base_path"
	else
		cp "$destination_path" "$base_path"
	fi

	normalize_legacy_bright_builds_readme_badges "$base_path" "$updated_path" "$remove_insertion_zone_legacy"
	cp "$updated_path" "$base_path"

	insert_readme_badges_block "$base_path" "$updated_path" "$rendered_block_path"
	trim_trailing_blank_lines "$updated_path" "$trimmed_path"
	cp "$trimmed_path" "$destination_path"
	note "Updated ${readme_destination}"
	readme_badge_state="$(resolve_readme_badge_state)"
}

repair_blocking_readme_file() {
	local destination_path="${repo_root}/${readme_destination}"
	local markers_removed_path=""
	local sanitized_path=""
	local trimmed_path=""

	[[ -f "$destination_path" ]] || return

	ensure_tmp_dir
	markers_removed_path="${tmp_dir}/README.markers-removed"
	sanitized_path="${tmp_dir}/README.sanitized"
	trimmed_path="${tmp_dir}/README.sanitized.trimmed"

	remove_readme_badge_markers "$destination_path" "$markers_removed_path"
	strip_readme_badge_region "$markers_removed_path" "$sanitized_path"
	trim_trailing_blank_lines "$sanitized_path" "$trimmed_path"

	if file_has_non_whitespace "$trimmed_path"; then
		cp "$trimmed_path" "$destination_path"
		note "Sanitized conflicting ${readme_destination} badge region"
	else
		rm -f "$destination_path"
		note "Removed conflicting ${readme_destination}"
	fi

	readme_badge_state="$(resolve_readme_badge_state)"
}

write_audit_manifest() {
	local operation="$1"

	last_operation="$operation"
	last_updated_utc="$(utc_now)"
	write_rendered_file "$audit_source" "$audit_destination" "$(build_current_managed_files_markdown)"
}

remove_legacy_audit_manifest_if_migrated() {
	local legacy_audit_path="${repo_root}/${legacy_audit_destination}"

	if [[ ! -f "$legacy_audit_path" || ! -f "${repo_root}/${audit_destination}" ]]; then
		return
	fi

	if [[ "${GITHUB_ACTIONS:-}" == "true" && "$current_audit_destination" == "$legacy_audit_destination" ]]; then
		return
	fi

	if [[ "$current_audit_destination" == "$legacy_audit_destination" || "$current_audit_destination" == "$audit_destination" ]]; then
		rm -f "$legacy_audit_path"
		note "Removed ${legacy_audit_destination}"
	fi
}

stage_legacy_audit_migration_for_github_actions() {
	if [[ "$current_audit_destination" != "$legacy_audit_destination" ]]; then
		return
	fi

	if [[ "${GITHUB_ACTIONS:-}" != "true" ]]; then
		return
	fi

	if ! command -v git >/dev/null 2>&1; then
		return
	fi

	if ! git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		return
	fi

	git -C "$repo_root" add -A -- "$audit_destination" "$legacy_audit_destination" >/dev/null 2>&1 || true
}

read_repo_local_git_config_value() {
	local key="$1"
	local value=""
	local status=0

	set +e
	value="$(git -C "$repo_root" config --local --get "$key" 2>/dev/null)"
	status=$?
	set -e

	if [[ "$status" -eq 0 ]]; then
		printf '%s\n' "$value"
	fi
}

prepare_legacy_auto_update_identity_restore_for_github_actions() {
	local git_dir=""
	local restore_root=""
	local hook_dir=""
	local post_commit_path=""
	local saved_user_name_path=""
	local saved_user_email_path=""
	local saved_hooks_path_path=""
	local before_user_name=""
	local before_user_email=""
	local before_hooks_path=""
	local quoted_repo_root=""
	local quoted_saved_user_name_path=""
	local quoted_saved_user_email_path=""
	local quoted_saved_hooks_path_path=""

	if [[ "${GITHUB_ACTIONS:-}" != "true" ]]; then
		return
	fi

	if [[ "$current_audit_destination" != "$legacy_audit_destination" ]]; then
		return
	fi

	if ! command -v git >/dev/null 2>&1; then
		return
	fi

	if ! git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		return
	fi

	git_dir="$(git -C "$repo_root" rev-parse --git-dir)"
	restore_root="${git_dir}/bright-builds-auto-update-identity-restore"
	hook_dir="${restore_root}/hooks"
	post_commit_path="${hook_dir}/post-commit"
	saved_user_name_path="${restore_root}/user.name"
	saved_user_email_path="${restore_root}/user.email"
	saved_hooks_path_path="${restore_root}/core.hooksPath"
	before_user_name="$(read_repo_local_git_config_value "user.name")"
	before_user_email="$(read_repo_local_git_config_value "user.email")"
	before_hooks_path="$(read_repo_local_git_config_value "core.hooksPath")"

	mkdir -p "$hook_dir"
	rm -f "$saved_user_name_path" "$saved_user_email_path" "$saved_hooks_path_path"

	if [[ -n "$before_user_name" ]]; then
		printf '%s' "$before_user_name" >"$saved_user_name_path"
	fi

	if [[ -n "$before_user_email" ]]; then
		printf '%s' "$before_user_email" >"$saved_user_email_path"
	fi

	if [[ -n "$before_hooks_path" ]]; then
		printf '%s' "$before_hooks_path" >"$saved_hooks_path_path"
	fi

	printf -v quoted_repo_root '%q' "$repo_root"
	printf -v quoted_saved_user_name_path '%q' "$saved_user_name_path"
	printf -v quoted_saved_user_email_path '%q' "$saved_user_email_path"
	printf -v quoted_saved_hooks_path_path '%q' "$saved_hooks_path_path"

	cat >"$post_commit_path" <<EOF
#!/usr/bin/env bash
set -euo pipefail

restore_local_value() {
	local key="\$1"
	local value_path="\$2"

	if [[ -f "\$value_path" ]]; then
		git -C ${quoted_repo_root} config --local "\$key" "\$(cat "\$value_path")"
		return
	fi

	set +e
	git -C ${quoted_repo_root} config --local --unset-all "\$key" >/dev/null 2>&1
	set -e
}

restore_local_value "user.name" ${quoted_saved_user_name_path}
restore_local_value "user.email" ${quoted_saved_user_email_path}

if [[ -f ${quoted_saved_hooks_path_path} ]]; then
	git -C ${quoted_repo_root} config --local core.hooksPath "\$(cat ${quoted_saved_hooks_path_path})"
else
	set +e
	git -C ${quoted_repo_root} config --local --unset-all core.hooksPath >/dev/null 2>&1
	set -e
fi

rm -f ${quoted_saved_user_name_path} ${quoted_saved_user_email_path} ${quoted_saved_hooks_path_path}
EOF
	chmod +x "$post_commit_path"

	# Old pre-rename helpers rewrite repo-local identity before committing.
	# Use a one-shot post-commit hook so that migration runs restore the prior local config.
	git -C "$repo_root" config --local core.hooksPath "$hook_dir"
}

resolve_current_install_metadata() {
	current_source=""
	current_ref=""
	current_entrypoint=""
	current_exact_commit=""
	current_auto_update=""
	current_auto_update_reason=""
	current_last_operation=""
	current_last_updated_utc=""
	current_audit_destination=""
	current_install_uses_legacy_layout=0

	if [[ -f "${repo_root}/${audit_destination}" ]]; then
		current_audit_destination="$audit_destination"
	elif [[ -f "${repo_root}/${legacy_audit_destination}" ]]; then
		current_audit_destination="$legacy_audit_destination"
		current_install_uses_legacy_layout=1
	else
		return 0
	fi

	current_source="$(extract_markdown_value "${repo_root}/${current_audit_destination}" "Source repository")"
	current_ref="$(extract_markdown_value "${repo_root}/${current_audit_destination}" "Version pin")"
	current_exact_commit="$(extract_markdown_value "${repo_root}/${current_audit_destination}" "Exact commit")"
	current_entrypoint="$(extract_markdown_value "${repo_root}/${current_audit_destination}" "Canonical entrypoint")"
	current_auto_update="$(extract_markdown_value "${repo_root}/${current_audit_destination}" "Auto-update")"
	current_auto_update_reason="$(extract_markdown_value "${repo_root}/${current_audit_destination}" "Auto-update reason")"
	current_last_operation="$(extract_markdown_value "${repo_root}/${current_audit_destination}" "Last operation")"
	current_last_updated_utc="$(extract_markdown_value "${repo_root}/${current_audit_destination}" "Last updated (UTC)")"

	if is_legacy_source_repository_url "$current_source"; then
		current_install_uses_legacy_layout=1
	fi
}
