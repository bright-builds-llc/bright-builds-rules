download_url_to_file() {
	local source_url="$1"
	local output_path="$2"
	local partial_path="${output_path}.partial"

	require_command curl
	rm -f "$partial_path"

	if ! curl -fsSL \
		--retry 3 \
		--retry-delay 1 \
		--retry-max-time 15 \
		"$source_url" \
		-o "$partial_path"; then
		rm -f "$partial_path"
		return 1
	fi

	if [[ ! -s "$partial_path" ]]; then
		printf 'error: downloaded managed source is empty: %s\n' "$source_url" >&2
		rm -f "$partial_path"
		return 1
	fi

	if ! mv "$partial_path" "$output_path"; then
		rm -f "$partial_path"
		return 1
	fi
}

download_file() {
	local source_path="$1"
	local output_path="$2"
	local maybe_local_source_path=""
	local source_url=""

	maybe_local_source_path="${local_source_root}/${source_path}"

	if [[ -n "$local_source_root" && -f "$maybe_local_source_path" ]]; then
		if [[ ! -s "$maybe_local_source_path" ]]; then
			printf 'error: managed source is empty: %s\n' "$maybe_local_source_path" >&2
			return 1
		fi

		cp "$maybe_local_source_path" "$output_path"
		return
	fi

	source_url="${raw_base}/${source_path}"
	if download_url_to_file "$source_url" "$output_path"; then
		return 0
	fi

	printf 'error: unable to download managed source %s from %s\n' "$source_path" "$raw_base" >&2
	return 1
}

download_file_if_available_from_raw_base() {
	local candidate_raw_base="$1"
	local source_path="$2"
	local output_path="$3"

	[[ -n "$candidate_raw_base" ]] || return 1

	if download_url_to_file "${candidate_raw_base}/${source_path}" "$output_path" >/dev/null 2>&1; then
		return 0
	fi

	rm -f "$output_path"
	return 1
}

download_file_if_available_from_local_git_ref() {
	local source_path="$1"
	local output_path="$2"
	local candidate_ref="$3"
	local partial_path="${output_path}.partial"

	[[ -n "$local_source_root" ]] || return 1
	[[ -n "$candidate_ref" ]] || return 1
	[[ "$candidate_ref" != "$exact_commit_unavailable" ]] || return 1
	command -v git >/dev/null 2>&1 || return 1
	git -C "$local_source_root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
	git -C "$local_source_root" cat-file -e "${candidate_ref}:${source_path}" >/dev/null 2>&1 || return 1
	rm -f "$partial_path"
	if ! git -C "$local_source_root" show "${candidate_ref}:${source_path}" >"$partial_path"; then
		rm -f "$partial_path"
		return 1
	fi

	if [[ ! -s "$partial_path" ]]; then
		rm -f "$partial_path"
		return 1
	fi

	if ! mv "$partial_path" "$output_path"; then
		rm -f "$partial_path"
		return 1
	fi
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
		[[ -s "$maybe_local_source_path" ]] || return 1
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
