write_or_update_agents_file() {
	local destination_path="${repo_root}/${agents_destination}"
	local rendered_block_path=""
	local updated_path=""
	local stripped_path=""

	if ! rendered_block_path="$(render_template_to_tmp_path "$agents_block_source" "agents-block")"; then
		die "unable to prepare managed block for ${agents_destination}"
	fi

	resolve_agents_block_state "$destination_path"

	if [[ ! -f "$destination_path" ]]; then
		cp "$rendered_block_path" "$destination_path"
		note "Wrote ${agents_destination}"
		return
	fi

	case "$agents_block_state" in
	absent)
		ensure_tmp_dir
		updated_path="${tmp_dir}/AGENTS.updated"
		stripped_path="${tmp_dir}/AGENTS.stripped"
		trim_trailing_blank_lines "$destination_path" "$stripped_path"

		if file_has_non_whitespace "$stripped_path"; then
			{
				cat "$stripped_path"
				printf '\n'
				cat "$rendered_block_path"
			} >"$updated_path"
		else
			cp "$rendered_block_path" "$updated_path"
		fi

		cp "$updated_path" "$destination_path"
		note "Updated ${agents_destination}"
		;;
	present)
		ensure_tmp_dir
		updated_path="${tmp_dir}/AGENTS.updated"
		replace_managed_block "$destination_path" "$updated_path" "$rendered_block_path"
		cp "$updated_path" "$destination_path"
		note "Updated ${agents_destination}"
		;;
	partial)
		die "${agents_destination} contains an incomplete managed marker block. Re-run install --force to back up and replace it."
		;;
	esac
}

write_or_update_contributing_file() {
	local destination_path="${repo_root}/${contributing_destination}"
	local rendered_block_path=""
	local updated_path=""
	local stripped_path=""
	local state=""

	if ! rendered_block_path="$(render_template_to_tmp_path "$contributing_block_source" "contributing-block")"; then
		die "unable to prepare managed block for ${contributing_destination}"
	fi

	if ! state="$(resolve_contributing_file_state)"; then
		die "unable to determine managed state for ${contributing_destination}"
	fi

	case "$state" in
	missing | whole-file-clean)
		cp "$rendered_block_path" "$destination_path"
		note "Wrote ${contributing_destination}"
		;;
	unmanaged-or-whole-file-drifted)
		ensure_tmp_dir
		updated_path="${tmp_dir}/CONTRIBUTING.updated"
		stripped_path="${tmp_dir}/CONTRIBUTING.stripped"
		trim_trailing_blank_lines "$destination_path" "$stripped_path"

		if file_has_non_whitespace "$stripped_path"; then
			{
				cat "$stripped_path"
				printf '\n'
				cat "$rendered_block_path"
			} >"$updated_path"
		else
			cp "$rendered_block_path" "$updated_path"
		fi

		cp "$updated_path" "$destination_path"
		note "Updated ${contributing_destination}"
		;;
	block-clean | block-drifted)
		ensure_tmp_dir
		updated_path="${tmp_dir}/CONTRIBUTING.updated"
		replace_contributing_block "$destination_path" "$updated_path" "$rendered_block_path"
		cp "$updated_path" "$destination_path"
		note "Updated ${contributing_destination}"
		;;
	partial)
		die "${contributing_destination} contains an incomplete managed marker block. Re-run install --force to back up and replace it."
		;;
	esac
}

ensure_overrides_file() {
	local destination_path="${repo_root}/${overrides_destination}"

	if [[ -f "$destination_path" ]]; then
		return
	fi

	write_rendered_file "$overrides_source" "$overrides_destination"
}

write_managed_standards_files() {
	local standards_path=""

	for standards_path in "${managed_standards_paths[@]}"; do
		write_rendered_file "$standards_path" "$standards_path"
	done
}

build_current_managed_status_paths() {
	local effective_audit_destination=""
	local entries=()
	local standards_path=""

	effective_audit_destination="$(resolve_effective_audit_destination)"
	entries=(
		"${agents_destination}"
		"${sidecar_destination}"
		"CONTRIBUTING.md"
		".github/pull_request_template.md"
		"${checks_script_destination}"
		"${effective_audit_destination}"
		"${overrides_destination}"
	)

	for standards_path in "${managed_standards_paths[@]}"; do
		entries+=("$standards_path")
	done

	if auto_update_files_are_relevant; then
		entries+=("${auto_update_script_destination}" "${auto_update_workflow_destination}")
	fi
	if checks_ci_files_are_relevant; then
		entries+=("${checks_workflow_destination}")
	fi

	printf '%s\n' "${entries[@]}"
}

build_managed_files_markdown_for_state() {
	local current_readme_badge_state="$1"
	local current_auto_update_mode="$2"
	local current_audit_relative_destination="${3:-$audit_destination}"
	local include_standards="${4:-enabled}"
	local current_checks_ci_mode="${5:-$checks_ci_mode}"
	local include_checks="${6:-enabled}"
	local standards_path=""
	local entries=(
		"${agents_destination} (managed block)"
		"${sidecar_destination}"
		"${contributing_destination} (managed block)"
		".github/pull_request_template.md"
		"${current_audit_relative_destination}"
	)

	if [[ "$include_standards" == "enabled" ]]; then
		for standards_path in "${managed_standards_paths[@]}"; do
			entries+=("$standards_path")
		done
	fi

	if [[ "$current_readme_badge_state" == "present" ]]; then
		entries+=("${readme_destination} (managed badges block)")
	fi

	if [[ "$current_auto_update_mode" == "enabled" ]]; then
		entries+=("${auto_update_script_destination}" "${auto_update_workflow_destination}")
	fi
	if [[ "$include_checks" == "enabled" ]]; then
		entries+=("${checks_script_destination}")
		if [[ "$current_checks_ci_mode" == "enabled" ]]; then
			entries+=("${checks_workflow_destination}")
		fi
	fi

	build_managed_files_markdown "${entries[@]}"
}

build_current_managed_files_markdown() {
	build_managed_files_markdown_for_state "$readme_badge_state" "$auto_update_mode" "$audit_destination" "enabled" "$checks_ci_mode" "enabled"
}

build_installed_managed_files_markdown() {
	local include_checks="disabled"

	if [[ "$current_checks_ci" == "enabled" || "$current_checks_ci" == "disabled" ]]; then
		include_checks="enabled"
	fi

	build_managed_files_markdown_for_state \
		"$readme_badge_state" \
		"${current_auto_update:-$auto_update_mode}" \
		"$(resolve_effective_audit_destination)" \
		"enabled" \
		"${current_checks_ci:-disabled}" \
		"$include_checks"
}

build_current_pre_standards_managed_files_markdown() {
	local include_checks="disabled"

	if [[ "$current_checks_ci" == "enabled" || "$current_checks_ci" == "disabled" ]]; then
		include_checks="enabled"
	fi

	build_managed_files_markdown_for_state \
		"$readme_badge_state" \
		"${current_auto_update:-$auto_update_mode}" \
		"$(resolve_effective_audit_destination)" \
		"disabled" \
		"${current_checks_ci:-disabled}" \
		"$include_checks"
}

build_current_pre_frontend_ui_managed_files_markdown() {
	local current_audit_relative_destination=""
	local current_auto_update_mode=""
	local include_checks="disabled"
	local standards_path=""
	local entries=(
		"${agents_destination} (managed block)"
		"${sidecar_destination}"
		"${contributing_destination} (managed block)"
		".github/pull_request_template.md"
	)

	current_audit_relative_destination="$(resolve_effective_audit_destination)"
	current_auto_update_mode="${current_auto_update:-$auto_update_mode}"
	entries+=("${current_audit_relative_destination}")

	for standards_path in "${managed_standards_paths[@]}"; do
		[[ "$standards_path" == "standards/core/frontend-ui.md" ]] && continue
		entries+=("$standards_path")
	done

	if [[ "$readme_badge_state" == "present" ]]; then
		entries+=("${readme_destination} (managed badges block)")
	fi

	if [[ "$current_auto_update_mode" == "enabled" ]]; then
		entries+=("${auto_update_script_destination}" "${auto_update_workflow_destination}")
	fi
	if [[ "$current_checks_ci" == "enabled" || "$current_checks_ci" == "disabled" ]]; then
		include_checks="enabled"
	fi
	if [[ "$include_checks" == "enabled" ]]; then
		entries+=("${checks_script_destination}")
		if [[ "$current_checks_ci" == "enabled" ]]; then
			entries+=("${checks_workflow_destination}")
		fi
	fi

	build_managed_files_markdown "${entries[@]}"
}

build_current_whole_file_contributing_compat_managed_files_markdown() {
	build_current_pre_standards_managed_files_markdown | sed "s#\`${contributing_destination} (managed block)\`#\`${contributing_destination}\`#"
}
