remove_auto_update_files() {
	local relative_destination=""

	for relative_destination in "${auto_update_script_destination}" "${auto_update_workflow_destination}"; do
		if [[ -f "${repo_root}/${relative_destination}" ]]; then
			rm -f "${repo_root}/${relative_destination}"
			note "Removed ${relative_destination}"
		fi
	done

	rmdir "${repo_root}/.github/workflows" 2>/dev/null || true
	rmdir "${repo_root}/.github" 2>/dev/null || true
}

build_whole_file_managed_pairs_for_mode() {
	local current_auto_update_mode="$1"
	local entries=("${base_whole_file_managed_pairs[@]}")
	local standards_path=""

	for standards_path in "${managed_standards_paths[@]}"; do
		entries+=("${standards_path}|${standards_path}")
	done

	if [[ "$current_auto_update_mode" == "enabled" ]]; then
		entries+=(
			"${auto_update_script_source}|${auto_update_script_destination}"
			"${auto_update_workflow_source}|${auto_update_workflow_destination}"
		)
	fi

	printf '%s\n' "${entries[@]}"
}

candidate_path_matches_destination() {
	local destination_path="$1"
	local candidate_path="$2"

	[[ -n "$candidate_path" && -f "$candidate_path" ]] || return 1
	cmp -s "$destination_path" "$candidate_path"
}

candidate_path_matches_destination_or_mdformat_variant() {
	local destination_path="$1"
	local candidate_path="$2"
	local relative_destination="$3"
	local formatted_candidate_path=""

	if candidate_path_matches_destination "$destination_path" "$candidate_path"; then
		return 0
	fi

	should_mdformat_whole_file_managed_markdown "$relative_destination" || return 1
	command -v mdformat >/dev/null 2>&1 || return 1

	ensure_tmp_dir
	formatted_candidate_path="${tmp_dir}/$(basename "$candidate_path").mdformat"
	cp "$candidate_path" "$formatted_candidate_path"
	mdformat "$formatted_candidate_path" >/dev/null 2>&1 || die "mdformat failed while matching ${relative_destination}"

	candidate_path_matches_destination "$destination_path" "$formatted_candidate_path"
}

strip_managed_file_marker_line() {
	local input_path="$1"
	local output_path="$2"

	grep -Ev '^(<!-- (bright-builds-rules|coding-and-architecture-requirements)-managed-file: .* -->|# (bright-builds-rules|coding-and-architecture-requirements)-managed-file: .*)$' "$input_path" >"$output_path"
}

marked_candidate_path_matches_destination_as_legacy_exact_match() {
	local destination_path="$1"
	local candidate_path="$2"
	local relative_destination="$3"
	local formatted_candidate_path=""
	local stripped_candidate_path=""

	should_mdformat_whole_file_managed_markdown "$relative_destination" || return 1
	command -v mdformat >/dev/null 2>&1 || return 1

	ensure_tmp_dir
	formatted_candidate_path="${tmp_dir}/$(basename "$candidate_path").marked.mdformat"
	stripped_candidate_path="${tmp_dir}/$(basename "$candidate_path").marked.stripped"
	cp "$candidate_path" "$formatted_candidate_path"
	mdformat "$formatted_candidate_path" >/dev/null 2>&1 || die "mdformat failed while matching ${relative_destination}"
	strip_managed_file_marker_line "$formatted_candidate_path" "$stripped_candidate_path"

	candidate_path_matches_destination "$destination_path" "$stripped_candidate_path"
}

resolve_contributing_file_state() {
	local destination_path="${repo_root}/${contributing_destination}"
	local rendered_block_path=""
	local installed_block_path=""
	local extracted_block_path=""
	local whole_file_state=""

	if [[ ! -f "$destination_path" ]]; then
		printf 'missing\n'
		return
	fi

	resolve_contributing_block_state "$destination_path"

	case "$contributing_block_state" in
	partial)
		printf 'partial\n'
		return
		;;
	present)
		rendered_block_path="$(render_template_to_tmp_path "$contributing_block_source" "contributing-block")"
		ensure_tmp_dir
		extracted_block_path="${tmp_dir}/CONTRIBUTING.block.extracted"
		extract_marker_block "$destination_path" "$extracted_block_path" "$contributing_block_begin" "$contributing_block_end"
		if cmp -s "$destination_path" "$rendered_block_path"; then
			printf 'block-clean\n'
			return
		fi
		if cmp -s "$extracted_block_path" "$rendered_block_path"; then
			printf 'block-clean\n'
			return
		fi
		installed_block_path="$(render_template_to_tmp_path_for_install_state "$contributing_block_source" "contributing-block.installed" "$contributing_destination" "" "disabled" "__CURRENT__" "disabled")"
		if [[ -n "$installed_block_path" ]] && cmp -s "$destination_path" "$installed_block_path"; then
			printf 'block-clean\n'
			return
		fi
		if [[ -n "$installed_block_path" ]] && cmp -s "$extracted_block_path" "$installed_block_path"; then
			printf 'block-clean\n'
			return
		fi
		printf 'block-drifted\n'
		return
		;;
	esac

	whole_file_state="$(resolve_whole_file_managed_state "$current_contributing_whole_file_compat_source" "$contributing_destination")"
	if [[ "$whole_file_state" == "marked" || "$whole_file_state" == "legacy" ]]; then
		printf 'whole-file-clean\n'
		return
	fi

	printf 'unmanaged-or-whole-file-drifted\n'
}

repair_blocking_contributing_file() {
	local destination_path="${repo_root}/${contributing_destination}"
	local state=""
	local rendered_block_path=""
	local updated_path=""

	[[ -f "$destination_path" ]] || return

	state="$(resolve_contributing_file_state)"
	case "$state" in
	block-clean | block-drifted)
		rendered_block_path="$(render_template_to_tmp_path "$contributing_block_source" "contributing-block")"
		ensure_tmp_dir
		updated_path="${tmp_dir}/CONTRIBUTING.repaired"
		replace_contributing_block "$destination_path" "$updated_path" "$rendered_block_path"
		cp "$updated_path" "$destination_path"
		note "Repaired ${contributing_destination}"
		;;
	*)
		rm -f "$destination_path"
		note "Removed conflicting ${contributing_destination}"
		;;
	esac
}

resolve_whole_file_managed_state() {
	local source_path="$1"
	local relative_destination="$2"
	local managed_files_markdown="${3:-}"
	local destination_path="${repo_root}/${relative_destination}"
	local actual_relative_destination="$relative_destination"
	local marked_path=""
	local legacy_path=""
	local actual_owner_specific_guidance_owner=""
	local alternate_marked_path=""
	local alternate_legacy_path=""
	local legacy_identity_marked_path=""
	local legacy_identity_unmarked_path=""
	local current_compat_source_path=""
	local current_compat_managed_files_markdown=""
	local legacy_compat_managed_files_markdown="$managed_files_markdown"
	local current_compat_marked_path=""
	local current_compat_legacy_path=""
	local prerename_compat_marked_path=""
	local prerename_compat_unmarked_path=""
	local pre_standards_managed_files_markdown=""
	local pre_standards_marked_path=""
	local pre_standards_legacy_path=""
	local pre_frontend_ui_managed_files_markdown=""
	local pre_frontend_ui_marked_path=""
	local pre_frontend_ui_legacy_path=""

	if [[ "$relative_destination" == "$audit_destination" && ! -f "$destination_path" && -f "${repo_root}/${legacy_audit_destination}" ]]; then
		destination_path="${repo_root}/${legacy_audit_destination}"
		actual_relative_destination="$legacy_audit_destination"
	fi

	if [[ ! -f "$destination_path" ]]; then
		printf 'missing\n'
		return
	fi

	if [[ "$actual_relative_destination" == "$audit_destination" || "$actual_relative_destination" == "$legacy_audit_destination" ]]; then
		legacy_compat_managed_files_markdown="$(build_current_whole_file_contributing_compat_managed_files_markdown)"
	fi

	marked_path="$(render_template_to_tmp_path_for_install_state "$source_path" "$(basename "$relative_destination").marked" "$relative_destination" "$managed_files_markdown" "enabled")"
	if candidate_path_matches_destination_or_mdformat_variant "$destination_path" "$marked_path" "$actual_relative_destination"; then
		printf 'marked\n'
		return
	fi
	if marked_candidate_path_matches_destination_as_legacy_exact_match "$destination_path" "$marked_path" "$actual_relative_destination"; then
		printf 'legacy\n'
		return
	fi

	if [[ "$actual_relative_destination" == "$audit_destination" || "$actual_relative_destination" == "$legacy_audit_destination" ]]; then
		pre_frontend_ui_managed_files_markdown="$(build_current_pre_frontend_ui_managed_files_markdown)"
		pre_frontend_ui_marked_path="$(render_template_to_tmp_path_for_install_state "$source_path" "$(basename "$relative_destination").pre-frontend-ui.marked" "$relative_destination" "$pre_frontend_ui_managed_files_markdown" "enabled")"
		if candidate_path_matches_destination_or_mdformat_variant "$destination_path" "$pre_frontend_ui_marked_path" "$actual_relative_destination"; then
			printf 'legacy\n'
			return
		fi
		if marked_candidate_path_matches_destination_as_legacy_exact_match "$destination_path" "$pre_frontend_ui_marked_path" "$actual_relative_destination"; then
			printf 'legacy\n'
			return
		fi

		pre_frontend_ui_legacy_path="$(render_template_to_tmp_path_for_install_state "$source_path" "$(basename "$relative_destination").pre-frontend-ui.legacy" "$relative_destination" "$pre_frontend_ui_managed_files_markdown" "disabled")"
		if candidate_path_matches_destination_or_mdformat_variant "$destination_path" "$pre_frontend_ui_legacy_path" "$actual_relative_destination"; then
			printf 'legacy\n'
			return
		fi

		pre_standards_managed_files_markdown="$(build_current_pre_standards_managed_files_markdown)"
		pre_standards_marked_path="$(render_template_to_tmp_path_for_install_state "$source_path" "$(basename "$relative_destination").pre-standards.marked" "$relative_destination" "$pre_standards_managed_files_markdown" "enabled")"
		if candidate_path_matches_destination_or_mdformat_variant "$destination_path" "$pre_standards_marked_path" "$actual_relative_destination"; then
			printf 'legacy\n'
			return
		fi
		if marked_candidate_path_matches_destination_as_legacy_exact_match "$destination_path" "$pre_standards_marked_path" "$actual_relative_destination"; then
			printf 'legacy\n'
			return
		fi

		pre_standards_legacy_path="$(render_template_to_tmp_path_for_install_state "$source_path" "$(basename "$relative_destination").pre-standards.legacy" "$relative_destination" "$pre_standards_managed_files_markdown" "disabled")"
		if candidate_path_matches_destination_or_mdformat_variant "$destination_path" "$pre_standards_legacy_path" "$actual_relative_destination"; then
			printf 'legacy\n'
			return
		fi
	fi

	legacy_path="$(render_template_to_tmp_path_for_install_state "$source_path" "$(basename "$relative_destination").legacy" "$relative_destination" "$managed_files_markdown" "disabled")"
	if candidate_path_matches_destination_or_mdformat_variant "$destination_path" "$legacy_path" "$actual_relative_destination"; then
		printf 'legacy\n'
		return
	fi

	legacy_identity_marked_path="$(render_template_to_legacy_identity_tmp_path_for_install_state "$source_path" "$(basename "$actual_relative_destination").legacy-identity.marked" "$actual_relative_destination" "$managed_files_markdown" "enabled")"
	if candidate_path_matches_destination_or_mdformat_variant "$destination_path" "$legacy_identity_marked_path" "$actual_relative_destination"; then
		printf 'legacy\n'
		return
	fi
	if marked_candidate_path_matches_destination_as_legacy_exact_match "$destination_path" "$legacy_identity_marked_path" "$actual_relative_destination"; then
		printf 'legacy\n'
		return
	fi

	legacy_identity_unmarked_path="$(render_template_to_legacy_identity_tmp_path_for_install_state "$source_path" "$(basename "$actual_relative_destination").legacy-identity.unmarked" "$actual_relative_destination" "$managed_files_markdown" "disabled")"
	if candidate_path_matches_destination_or_mdformat_variant "$destination_path" "$legacy_identity_unmarked_path" "$actual_relative_destination"; then
		printf 'legacy\n'
		return
	fi

	current_compat_source_path="$(current_whole_file_compat_source_path_for_relative_destination "$actual_relative_destination")"
	if [[ -n "$current_compat_source_path" ]]; then
		current_compat_managed_files_markdown="$legacy_compat_managed_files_markdown"
		current_compat_marked_path="$(render_template_to_tmp_path_for_install_state "$current_compat_source_path" "$(basename "$actual_relative_destination").current-compat.marked" "$actual_relative_destination" "$current_compat_managed_files_markdown" "enabled")"
		if candidate_path_matches_destination_or_mdformat_variant "$destination_path" "$current_compat_marked_path" "$actual_relative_destination"; then
			printf 'legacy\n'
			return
		fi
		if marked_candidate_path_matches_destination_as_legacy_exact_match "$destination_path" "$current_compat_marked_path" "$actual_relative_destination"; then
			printf 'legacy\n'
			return
		fi

		current_compat_legacy_path="$(render_template_to_tmp_path_for_install_state "$current_compat_source_path" "$(basename "$actual_relative_destination").current-compat.legacy" "$actual_relative_destination" "$current_compat_managed_files_markdown" "disabled")"
		if candidate_path_matches_destination_or_mdformat_variant "$destination_path" "$current_compat_legacy_path" "$actual_relative_destination"; then
			printf 'legacy\n'
			return
		fi
	fi

	if [[ "$current_install_uses_legacy_layout" -eq 1 ]]; then
		prerename_compat_marked_path="$(render_template_to_prerename_compat_tmp_path_for_install_state "$(basename "$actual_relative_destination").prerename-compat.marked" "$actual_relative_destination" "$legacy_compat_managed_files_markdown" "enabled")"
		if candidate_path_matches_destination_or_mdformat_variant "$destination_path" "$prerename_compat_marked_path" "$actual_relative_destination"; then
			printf 'legacy\n'
			return
		fi
		if marked_candidate_path_matches_destination_as_legacy_exact_match "$destination_path" "$prerename_compat_marked_path" "$actual_relative_destination"; then
			printf 'legacy\n'
			return
		fi

		prerename_compat_unmarked_path="$(render_template_to_prerename_compat_tmp_path_for_install_state "$(basename "$actual_relative_destination").prerename-compat.unmarked" "$actual_relative_destination" "$legacy_compat_managed_files_markdown" "disabled")"
		if candidate_path_matches_destination_or_mdformat_variant "$destination_path" "$prerename_compat_unmarked_path" "$actual_relative_destination"; then
			printf 'legacy\n'
			return
		fi
	fi

	if [[ "$relative_destination" == "$sidecar_destination" ]]; then
		if [[ -n "$owner_specific_guidance_markdown" ]]; then
			alternate_marked_path="$(render_template_to_tmp_path_for_install_state "$source_path" "$(basename "$relative_destination").marked.no-owner-guidance" "$relative_destination" "$managed_files_markdown" "enabled" "")"
			if candidate_path_matches_destination_or_mdformat_variant "$destination_path" "$alternate_marked_path" "$actual_relative_destination"; then
				printf 'marked\n'
				return
			fi
			if marked_candidate_path_matches_destination_as_legacy_exact_match "$destination_path" "$alternate_marked_path" "$actual_relative_destination"; then
				printf 'legacy\n'
				return
			fi

			alternate_legacy_path="$(render_template_to_tmp_path_for_install_state "$source_path" "$(basename "$relative_destination").legacy.no-owner-guidance" "$relative_destination" "$managed_files_markdown" "disabled" "")"
			if candidate_path_matches_destination_or_mdformat_variant "$destination_path" "$alternate_legacy_path" "$actual_relative_destination"; then
				printf 'legacy\n'
				return
			fi

			alternate_marked_path="$(render_template_to_legacy_identity_tmp_path_for_install_state "$source_path" "$(basename "$actual_relative_destination").legacy-identity.marked.no-owner-guidance" "$actual_relative_destination" "$managed_files_markdown" "enabled" "")"
			if candidate_path_matches_destination_or_mdformat_variant "$destination_path" "$alternate_marked_path" "$actual_relative_destination"; then
				printf 'legacy\n'
				return
			fi
			if marked_candidate_path_matches_destination_as_legacy_exact_match "$destination_path" "$alternate_marked_path" "$actual_relative_destination"; then
				printf 'legacy\n'
				return
			fi

			alternate_legacy_path="$(render_template_to_legacy_identity_tmp_path_for_install_state "$source_path" "$(basename "$actual_relative_destination").legacy-identity.unmarked.no-owner-guidance" "$actual_relative_destination" "$managed_files_markdown" "disabled" "")"
			if candidate_path_matches_destination_or_mdformat_variant "$destination_path" "$alternate_legacy_path" "$actual_relative_destination"; then
				printf 'legacy\n'
				return
			fi

			if [[ "$current_install_uses_legacy_layout" -eq 1 ]]; then
				alternate_marked_path="$(render_template_to_prerename_compat_tmp_path_for_install_state "$(basename "$actual_relative_destination").prerename-compat.marked.no-owner-guidance" "$actual_relative_destination" "$legacy_compat_managed_files_markdown" "enabled" "")"
				if candidate_path_matches_destination_or_mdformat_variant "$destination_path" "$alternate_marked_path" "$actual_relative_destination"; then
					printf 'legacy\n'
					return
				fi
				if marked_candidate_path_matches_destination_as_legacy_exact_match "$destination_path" "$alternate_marked_path" "$actual_relative_destination"; then
					printf 'legacy\n'
					return
				fi

				alternate_legacy_path="$(render_template_to_prerename_compat_tmp_path_for_install_state "$(basename "$actual_relative_destination").prerename-compat.unmarked.no-owner-guidance" "$actual_relative_destination" "$legacy_compat_managed_files_markdown" "disabled" "")"
				if candidate_path_matches_destination_or_mdformat_variant "$destination_path" "$alternate_legacy_path" "$actual_relative_destination"; then
					printf 'legacy\n'
					return
				fi
			fi
		fi

		actual_owner_specific_guidance_owner="$(extract_sidecar_owner_specific_guidance_owner "$destination_path")"
		if [[ -n "$actual_owner_specific_guidance_owner" && "$actual_owner_specific_guidance_owner" != "$downstream_repo_owner" ]]; then
			alternate_marked_path="$(render_template_to_tmp_path_for_install_state "$source_path" "$(basename "$relative_destination").marked.owner-guidance-compat" "$relative_destination" "$managed_files_markdown" "enabled" "$actual_owner_specific_guidance_owner")"
			if candidate_path_matches_destination_or_mdformat_variant "$destination_path" "$alternate_marked_path" "$actual_relative_destination"; then
				printf 'marked\n'
				return
			fi
			if marked_candidate_path_matches_destination_as_legacy_exact_match "$destination_path" "$alternate_marked_path" "$actual_relative_destination"; then
				printf 'legacy\n'
				return
			fi

			alternate_legacy_path="$(render_template_to_tmp_path_for_install_state "$source_path" "$(basename "$relative_destination").legacy.owner-guidance-compat" "$relative_destination" "$managed_files_markdown" "disabled" "$actual_owner_specific_guidance_owner")"
			if candidate_path_matches_destination "$destination_path" "$alternate_legacy_path"; then
				printf 'legacy\n'
				return
			fi

			alternate_marked_path="$(render_template_to_legacy_identity_tmp_path_for_install_state "$source_path" "$(basename "$actual_relative_destination").legacy-identity.marked.owner-guidance-compat" "$actual_relative_destination" "$managed_files_markdown" "enabled" "$actual_owner_specific_guidance_owner")"
			if candidate_path_matches_destination_or_mdformat_variant "$destination_path" "$alternate_marked_path" "$actual_relative_destination"; then
				printf 'legacy\n'
				return
			fi
			if marked_candidate_path_matches_destination_as_legacy_exact_match "$destination_path" "$alternate_marked_path" "$actual_relative_destination"; then
				printf 'legacy\n'
				return
			fi

			alternate_legacy_path="$(render_template_to_legacy_identity_tmp_path_for_install_state "$source_path" "$(basename "$actual_relative_destination").legacy-identity.unmarked.owner-guidance-compat" "$actual_relative_destination" "$managed_files_markdown" "disabled" "$actual_owner_specific_guidance_owner")"
			if candidate_path_matches_destination "$destination_path" "$alternate_legacy_path"; then
				printf 'legacy\n'
				return
			fi

			if [[ "$current_install_uses_legacy_layout" -eq 1 ]]; then
				alternate_marked_path="$(render_template_to_prerename_compat_tmp_path_for_install_state "$(basename "$actual_relative_destination").prerename-compat.marked.owner-guidance-compat" "$actual_relative_destination" "$legacy_compat_managed_files_markdown" "enabled" "$actual_owner_specific_guidance_owner")"
				if candidate_path_matches_destination_or_mdformat_variant "$destination_path" "$alternate_marked_path" "$actual_relative_destination"; then
					printf 'legacy\n'
					return
				fi
				if marked_candidate_path_matches_destination_as_legacy_exact_match "$destination_path" "$alternate_marked_path" "$actual_relative_destination"; then
					printf 'legacy\n'
					return
				fi

				alternate_legacy_path="$(render_template_to_prerename_compat_tmp_path_for_install_state "$(basename "$actual_relative_destination").prerename-compat.unmarked.owner-guidance-compat" "$actual_relative_destination" "$legacy_compat_managed_files_markdown" "disabled" "$actual_owner_specific_guidance_owner")"
				if candidate_path_matches_destination "$destination_path" "$alternate_legacy_path"; then
					printf 'legacy\n'
					return
				fi
			fi
		fi
	fi

	printf 'drifted\n'
}

append_drifted_installed_whole_file_paths() {
	local pair=""
	local source_path=""
	local relative_destination=""
	local state=""
	local managed_files_markdown=""

	managed_files_markdown="$(build_installed_managed_files_markdown)"

	while IFS= read -r pair; do
		IFS='|' read -r source_path relative_destination <<<"$pair"
		state="$(resolve_whole_file_managed_state "$source_path" "$relative_destination" "$managed_files_markdown")"
		if [[ "$state" == "drifted" ]]; then
			append_unique_blocking_path "$relative_destination"
		fi
	done < <(build_whole_file_managed_pairs_for_mode "${current_auto_update:-$auto_update_mode}")
}

append_conflicting_existing_standards_paths() {
	local standards_path=""
	local state=""

	for standards_path in "${managed_standards_paths[@]}"; do
		state="$(resolve_whole_file_managed_state "$standards_path" "$standards_path")"
		if [[ "$state" == "drifted" ]]; then
			append_unique_blocking_path "$standards_path"
		fi
	done
}

remove_clean_installed_whole_file() {
	local source_path="$1"
	local relative_destination="$2"
	local managed_files_markdown="${3:-}"
	local destination_path="${repo_root}/${relative_destination}"
	local state=""

	state="$(resolve_whole_file_managed_state "$source_path" "$relative_destination" "$managed_files_markdown")"

	case "$state" in
	marked | legacy)
		rm -f "$destination_path"
		note "Removed ${relative_destination}"
		;;
	drifted)
		note "Skipped ${relative_destination} because it has downstream edits"
		;;
	esac
}
