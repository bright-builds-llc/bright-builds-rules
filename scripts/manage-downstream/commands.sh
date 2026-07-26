determine_repo_state() {
	local agents_path="${repo_root}/${agents_destination}"
	local path=""
	local auto_update_path=""
	local contributing_state=""
	local installed_signal=0
	local effective_audit_destination=""

	repo_state=""
	recommended_action=""
	blocking_paths=()
	resolve_agents_block_state "$agents_path"
	readme_badge_state="$(resolve_readme_badge_state)"
	effective_audit_destination="$(resolve_effective_audit_destination)"
	if ! contributing_state="$(resolve_contributing_file_state)"; then
		die "unable to determine managed state for ${contributing_destination}"
	fi

	if [[ "$agents_block_state" == "present" && -f "${repo_root}/${sidecar_destination}" ]]; then
		installed_signal=1
	fi

	if [[ "$agents_block_state" == "partial" ]]; then
		append_unique_blocking_path "$agents_destination"
	fi

	if [[ "$agents_block_state" == "present" && ! -f "${repo_root}/${sidecar_destination}" ]]; then
		append_unique_blocking_path "$agents_destination"
		append_unique_blocking_path "$sidecar_destination"
	fi

	if [[ "$agents_block_state" != "present" && -f "${repo_root}/${sidecar_destination}" ]]; then
		append_unique_blocking_path "$sidecar_destination"
	fi

	if [[ "$installed_signal" -eq 1 ]]; then
		append_drifted_installed_whole_file_paths
	else
		append_conflicting_existing_standards_paths
	fi

	if [[ "$installed_signal" -eq 1 ]]; then
		case "$contributing_state" in
		partial | block-drifted | unmanaged-or-whole-file-drifted)
			append_unique_blocking_path "$contributing_destination"
			;;
		esac
	else
		case "$contributing_state" in
		block-clean | block-drifted | partial | whole-file-clean)
			append_unique_blocking_path "$contributing_destination"
			;;
		esac
	fi

	if [[ "$installed_signal" -ne 1 ]]; then
		for path in ".github/pull_request_template.md" "${effective_audit_destination}"; do
			if [[ -f "${repo_root}/${path}" ]]; then
				append_unique_blocking_path "$path"
			fi
		done

		if auto_update_files_are_relevant; then
			for auto_update_path in "${auto_update_script_destination}" "${auto_update_workflow_destination}"; do
				if [[ -f "${repo_root}/${auto_update_path}" ]]; then
					append_unique_blocking_path "$auto_update_path"
				fi
			done
		fi
	fi

	if [[ "$installed_signal" -eq 1 && "$auto_update_mode" == "enabled" && "$current_auto_update" != "enabled" ]]; then
		for auto_update_path in "${auto_update_script_destination}" "${auto_update_workflow_destination}"; do
			if [[ -f "${repo_root}/${auto_update_path}" ]]; then
				append_unique_blocking_path "$auto_update_path"
			fi
		done
	fi

	if [[ "$readme_badge_state" == "partial" || "$readme_badge_state" == "ambiguous" ]]; then
		append_unique_blocking_path "$readme_destination"
	fi

	if [[ "${#blocking_paths[@]}" -gt 0 ]]; then
		repo_state="blocked"
		recommended_action="install --force"
		return
	fi

	if [[ "$installed_signal" -eq 1 ]]; then
		repo_state="installed"
		recommended_action="update"
		return
	fi

	repo_state="installable"
	recommended_action="install"
}

backup_blocking_paths() {
	local backup_timestamp=""
	local relative_destination=""
	local source_path=""
	local backup_path=""

	[[ "${#blocking_paths[@]}" -gt 0 ]] || return

	backup_timestamp="$(date -u +"%Y%m%dT%H%M%SZ")"
	last_backup_relative_root="${backup_root}/${backup_timestamp}"

	for relative_destination in "${blocking_paths[@]-}"; do
		source_path="${repo_root}/${relative_destination}"
		backup_path="${repo_root}/${last_backup_relative_root}/${relative_destination}"
		mkdir -p "$(dirname "$backup_path")"
		if [[ -f "$source_path" ]]; then
			cp "$source_path" "$backup_path"
			note "Backed up ${relative_destination} -> ${last_backup_relative_root}/${relative_destination}"
		fi
	done
}

clear_blocking_paths() {
	local relative_destination=""
	local destination_path=""

	for relative_destination in "${blocking_paths[@]-}"; do
		destination_path="${repo_root}/${relative_destination}"

		if [[ "$relative_destination" == "$readme_destination" ]]; then
			repair_blocking_readme_file
			continue
		fi

		if [[ "$relative_destination" == "$contributing_destination" ]]; then
			repair_blocking_contributing_file
			continue
		fi

		rm -f "$destination_path"
		note "Removed conflicting ${relative_destination}"
	done

	rmdir "${repo_root}/.github/workflows" 2>/dev/null || true
	rmdir "${repo_root}/.github" 2>/dev/null || true
}

install_or_update() {
	local operation="$1"
	local pair=""
	local source_path=""
	local relative_destination=""

	record_legacy_auto_update_helper_staging_need "$operation"
	write_or_update_agents_file
	write_or_update_contributing_file

	for pair in "${base_managed_pairs[@]}"; do
		IFS='|' read -r source_path relative_destination <<<"$pair"
		write_rendered_file "$source_path" "$relative_destination"
	done

	write_managed_standards_files
	ensure_overrides_file
	write_or_update_readme_file
	sync_auto_update_files
	print_legacy_auto_update_token_repair_advisory
	write_audit_manifest "$operation"
	remove_legacy_audit_manifest_if_migrated
	stage_legacy_audit_migration_for_github_actions
	prepare_legacy_auto_update_identity_restore_for_github_actions
	stage_legacy_auto_update_standards_for_github_actions
}

status() {
	local relative_destination=""
	local destination_path=""

	note "Target repository: ${repo_root}"
	note "Repo state: ${repo_state}"
	note "Recommended action: ${recommended_action}"
	note "AGENTS marker: ${agents_block_state}"
	note "README badge block: ${readme_badge_state}"
	note "Auto-update: ${auto_update_mode}"
	note "Auto-update reason: ${auto_update_reason}"

	if [[ -n "$readme_badge_blocking_reason" ]]; then
		note "README badge reason: ${readme_badge_blocking_reason}"
	fi

	if [[ "$repo_state" == "blocked" ]]; then
		note "Blocking paths: ${blocking_paths[*]}"
	fi

	while IFS= read -r relative_destination; do
		destination_path="${repo_root}/${relative_destination}"

		if [[ -f "$destination_path" ]]; then
			note "[present] ${relative_destination}"
		else
			note "[missing] ${relative_destination}"
		fi
	done < <(build_current_managed_status_paths)

	if [[ -n "$current_audit_destination" && -f "${repo_root}/${current_audit_destination}" ]]; then
		note "Audit trail: ${current_audit_destination}"
	elif [[ -f "${repo_root}/${audit_destination}" ]]; then
		note "Audit trail: ${audit_destination}"
	fi

	if [[ "$repo_state" == "installed" ]]; then
		if [[ -n "$current_source" ]]; then
			note "Pinned source: ${current_source}"
		fi

		if [[ -n "$current_ref" ]]; then
			note "Pinned ref: ${current_ref}"
		fi

		if [[ -n "$current_exact_commit" ]]; then
			note "Pinned commit: ${current_exact_commit}"
		fi
	fi
}

uninstall() {
	local destination_path="${repo_root}/${agents_destination}"
	local readme_path="${repo_root}/${readme_destination}"
	local updated_path=""
	local trimmed_path=""
	local state=""
	local readme_state=""
	local pair=""
	local source_path=""
	local relative_destination=""
	local managed_files_markdown=""

	resolve_agents_block_state "$destination_path"
	state="$agents_block_state"

	if [[ "$state" == "present" ]]; then
		ensure_tmp_dir
		updated_path="${tmp_dir}/AGENTS.unmanaged"
		trimmed_path="${tmp_dir}/AGENTS.trimmed"
		remove_managed_block "$destination_path" "$updated_path"
		trim_trailing_blank_lines "$updated_path" "$trimmed_path"

		if file_has_non_whitespace "$trimmed_path"; then
			cp "$trimmed_path" "$destination_path"
			note "Updated ${agents_destination}"
		else
			rm -f "$destination_path"
			note "Removed ${agents_destination}"
		fi
	elif [[ "$state" == "partial" ]]; then
		note "Skipped ${agents_destination} because the managed marker block is incomplete"
	fi

	remove_or_update_contributing_file_for_uninstall

	resolve_readme_badges_block_state "$readme_path"
	readme_state="$compatible_marker_state"

	if [[ "$readme_state" == "present" ]]; then
		ensure_tmp_dir
		updated_path="${tmp_dir}/README.unmanaged"
		trimmed_path="${tmp_dir}/README.unmanaged.trimmed"
		remove_readme_badges_block "$readme_path" "$updated_path"
		trim_trailing_blank_lines "$updated_path" "$trimmed_path"

		if readme_is_generated_skeleton_after_removal "$trimmed_path" || ! file_has_non_whitespace "$trimmed_path"; then
			rm -f "$readme_path"
			note "Removed ${readme_destination}"
		else
			cp "$trimmed_path" "$readme_path"
			note "Updated ${readme_destination}"
		fi
	elif [[ "$readme_state" == "partial" ]]; then
		note "Skipped ${readme_destination} because the managed badge block is incomplete"
	fi

	managed_files_markdown="$(build_installed_managed_files_markdown)"

	if [[ "$current_auto_update" == "enabled" ]]; then
		while IFS= read -r pair; do
			IFS='|' read -r source_path relative_destination <<<"$pair"
			case "$relative_destination" in
			"${auto_update_script_destination}" | "${auto_update_workflow_destination}")
				remove_clean_installed_whole_file "$source_path" "$relative_destination" "$managed_files_markdown"
				;;
			esac
		done < <(build_whole_file_managed_pairs_for_mode "$current_auto_update")
	fi

	while IFS= read -r pair; do
		IFS='|' read -r source_path relative_destination <<<"$pair"
		case "$relative_destination" in
		"${auto_update_script_destination}" | "${auto_update_workflow_destination}")
			continue
			;;
		esac
		remove_clean_installed_whole_file "$source_path" "$relative_destination" "$managed_files_markdown"
	done < <(build_whole_file_managed_pairs_for_mode "disabled")

	rmdir "${repo_root}/standards/core" 2>/dev/null || true
	rmdir "${repo_root}/standards/languages" 2>/dev/null || true
	rmdir "${repo_root}/standards" 2>/dev/null || true
	rmdir "${repo_root}/.github/workflows" 2>/dev/null || true
	rmdir "${repo_root}/.github" 2>/dev/null || true
}

manage_downstream_main() {
	local command_name="${1:-}"
	local maybe_repo_slug=""

	resolve_local_source_root

	if [[ -z "$command_name" || "$command_name" == "-h" || "$command_name" == "--help" || "$command_name" == "help" ]]; then
		usage
		return 0
	fi

	shift

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--ref)
			[[ $# -ge 2 ]] || die "missing value for --ref"
			ref="$2"
			ref_was_explicit=1
			shift 2
			;;
		--repo)
			[[ $# -ge 2 ]] || die "missing value for --repo"
			repo_slug="$2"
			repo_was_explicit=1
			shift 2
			;;
		--repo-root)
			[[ $# -ge 2 ]] || die "missing value for --repo-root"
			repo_root="$2"
			shift 2
			;;
		--auto-update)
			[[ $# -ge 2 ]] || die "missing value for --auto-update"
			auto_update_request="$2"
			auto_update_was_explicit=1
			shift 2
			;;
		--force)
			force=1
			shift
			;;
		-h | --help)
			usage
			return 0
			;;
		*)
			die "unknown option: $1"
			;;
		esac
	done

	[[ -d "$repo_root" ]] || die "repo root does not exist: $repo_root"
	repo_root="$(cd "$repo_root" && pwd)"

	resolve_current_install_metadata

	if [[ "$repo_was_explicit" -eq 0 && -n "$current_source" ]] && ! is_legacy_source_repository_url "$current_source"; then
		maybe_repo_slug="$(extract_repo_slug_from_url "$current_source")"

		if [[ -n "$maybe_repo_slug" ]]; then
			repo_slug="$maybe_repo_slug"
		fi
	fi

	if [[ "$ref_was_explicit" -eq 0 && -n "$current_ref" ]]; then
		ref="$current_ref"
	fi

	if [[ -z "$repo_slug" ]]; then
		repo_slug="$default_repo_slug"
	fi

	if [[ -z "$ref" ]]; then
		ref="$default_ref"
	fi

	repo_url="https://github.com/${repo_slug}"
	raw_base="https://raw.githubusercontent.com/${repo_slug}/${ref}"
	standards_index_url="${repo_url}/blob/${ref}/standards/index.md"
	resolve_exact_commit
	resolve_downstream_badges
	resolve_owner_specific_guidance
	resolve_auto_update_state
	prepare_managed_markdown_mdformat
	determine_repo_state

	case "$command_name" in
	install)
		if [[ "$repo_state" == "blocked" && "$force" -ne 1 ]]; then
			die "repo has blocked upstream-managed paths: ${blocking_paths[*]}. Prefer fixing the managed source in bright-builds-rules via upstream PR or issue. Re-run install --force only when you explicitly want to back up and replace the downstream copies."
		fi

		if [[ "$repo_state" == "blocked" && "$force" -eq 1 ]]; then
			backup_blocking_paths
			clear_blocking_paths
		fi

		install_or_update "install"
		note "Pinned standards to ${repo_url} @ ${ref}"
		if [[ -n "$last_backup_relative_root" ]]; then
			note "Legacy backup: ${last_backup_relative_root}"
		fi
		note "Audit trail: ${audit_destination}"
		;;
	update)
		if [[ "$repo_state" == "installable" ]]; then
			die "repo does not contain the managed AGENTS marker. Use install for a fresh adoption."
		fi

		if [[ "$repo_state" == "blocked" ]]; then
			die "repo has blocked upstream-managed paths: ${blocking_paths[*]}. Prefer fixing the managed source in bright-builds-rules via upstream PR or issue. Re-run install --force only when you explicitly want to back up and replace the downstream copies."
		fi

		install_or_update "update"
		note "Updated standards pin to ${repo_url} @ ${ref}"
		note "Audit trail: ${audit_destination}"
		;;
	status)
		status
		;;
	uninstall)
		uninstall
		if [[ -f "${repo_root}/${overrides_destination}" ]]; then
			note "Preserved ${overrides_destination}"
		fi
		;;
	*)
		die "unknown command: ${command_name}"
		;;
	esac
}
