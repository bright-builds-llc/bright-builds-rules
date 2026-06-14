compact_json_file() {
	local file_path="$1"

	[[ -f "$file_path" ]] || return
	tr '\n' ' ' <"$file_path"
}

extract_json_object_string_values() {
	local compact_json="$1"
	local object_key="$2"
	local item_key="$3"
	local section=""
	local value=""

	while IFS= read -r section; do
		[[ -n "$section" ]] || continue
		value="$(printf '%s\n' "$section" | sed -n "s/.*\"${item_key}\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p")"
		if [[ -n "$value" ]]; then
			printf '%s\n' "$value"
		fi
	done < <(printf '%s' "$compact_json" | grep -oE "\"${object_key}\"[[:space:]]*:[[:space:]]*\\{[^}]*\\}" || true)
}

extract_package_json_dependency_values() {
	local compact_json="$1"
	local package_name="$2"
	local section=""
	local value=""

	for section in dependencies devDependencies; do
		while IFS= read -r value; do
			[[ -n "$value" ]] || continue
			printf '%s\n' "$value"
		done < <(
			while IFS= read -r maybe_section; do
				[[ -n "$maybe_section" ]] || continue
				printf '%s\n' "$maybe_section" | sed -n "s/.*\"${package_name}\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p"
			done < <(printf '%s' "$compact_json" | grep -oE "\"${section}\"[[:space:]]*:[[:space:]]*\\{[^}]*\\}" || true)
		)
	done
}

detect_existing_path() {
	local candidate=""

	for candidate in "$@"; do
		if [[ -f "${repo_root}/${candidate}" ]]; then
			printf '%s\n' "$candidate"
			return 0
		fi
	done

	return 1
}

detect_license_file() {
	detect_existing_path \
		"LICENSE" \
		"LICENSE.md" \
		"LICENSE.txt" \
		"COPYING" \
		"COPYING.md" \
		"COPYING.txt"
}

extract_github_slug_from_remote_url() {
	local remote_url="$1"
	local maybe_slug=""

	maybe_slug="$(printf '%s' "$remote_url" | sed -n \
		-e 's#^https://github.com/\([^/][^ ]*\)$#\1#p' \
		-e 's#^git@github.com:\([^/][^ ]*\)$#\1#p' \
		-e 's#^ssh://git@github.com/\([^/][^ ]*\)$#\1#p' \
		-e 's#^git://github.com/\([^/][^ ]*\)$#\1#p')"
	maybe_slug="${maybe_slug%.git}"
	maybe_slug="${maybe_slug%/}"

	if [[ "$maybe_slug" =~ ^[^/]+/[^/]+$ ]]; then
		printf '%s\n' "$maybe_slug"
		return 0
	fi

	return 1
}

resolve_downstream_repo_slug() {
	local remote_url=""

	downstream_repo_slug=""
	downstream_repo_url=""
	downstream_repo_owner=""

	if ! command -v git >/dev/null 2>&1; then
		return
	fi

	if ! remote_url="$(git -C "$repo_root" remote get-url origin 2>/dev/null)"; then
		return
	fi

	if ! downstream_repo_slug="$(extract_github_slug_from_remote_url "$remote_url" 2>/dev/null)"; then
		downstream_repo_slug=""
		return
	fi

	downstream_repo_url="https://github.com/${downstream_repo_slug}"
	downstream_repo_owner="$(extract_repo_owner_from_slug "$downstream_repo_slug")"
}

resolve_current_github_user() {
	local maybe_actor="${GITHUB_ACTOR:-}"
	local maybe_login=""

	current_github_user=""

	if [[ -n "$maybe_actor" ]] && [[ "$(normalize_github_identity "$maybe_actor")" != "github-actions[bot]" ]]; then
		current_github_user="$maybe_actor"
		return
	fi

	if ! command -v gh >/dev/null 2>&1; then
		return
	fi

	maybe_login="$(gh api user --jq .login 2>/dev/null || true)"

	if [[ -n "$maybe_login" ]] && [[ "$(normalize_github_identity "$maybe_login")" != "github-actions[bot]" ]]; then
		current_github_user="$maybe_login"
	fi
}

detect_node_version_info() {
	local package_json_path="${repo_root}/package.json"
	local compact_json=""
	local maybe_raw_engine=""
	local maybe_normalized=""
	local maybe_nvmrc_path="${repo_root}/.nvmrc"
	local maybe_nvmrc_line=""
	local maybe_ci_version=""

	if [[ -f "$package_json_path" ]]; then
		compact_json="$(compact_json_file "$package_json_path")"
		maybe_raw_engine="$(extract_json_object_string_values "$compact_json" "engines" "node" | head -n 1)"

		if [[ -n "$maybe_raw_engine" ]]; then
			if maybe_normalized="$(normalize_badge_version "$maybe_raw_engine" 2>/dev/null)"; then
				printf '%s|package.json\n' "$maybe_normalized"
			fi
			return
		fi
	fi

	if [[ -f "$maybe_nvmrc_path" ]]; then
		maybe_nvmrc_line="$(awk 'NF { print; exit }' "$maybe_nvmrc_path")"
		if [[ -n "$maybe_nvmrc_line" ]]; then
			if maybe_normalized="$(normalize_badge_version "$maybe_nvmrc_line" 2>/dev/null)"; then
				printf '%s|.nvmrc\n' "$maybe_normalized"
			fi
			return
		fi
	fi

	if [[ -n "$downstream_ci_workflow_path" ]] && grep -q 'actions/setup-node' "${repo_root}/${downstream_ci_workflow_path}"; then
		maybe_ci_version="$(
			grep -E '^[[:space:]]*node-version:[[:space:]]*' "${repo_root}/${downstream_ci_workflow_path}" |
				sed -n "s/^[[:space:]]*node-version:[[:space:]]*['\"]\{0,1\}\([^'\"#[:space:]]*\)['\"]\{0,1\}.*/\\1/p" |
				select_single_normalized_version || true
		)"
		if [[ -n "$maybe_ci_version" ]]; then
			printf '%s|%s\n' "$maybe_ci_version" "$downstream_ci_workflow_path"
		fi
	fi
}

detect_package_json_dependency_version() {
	local package_name="$1"
	local package_json_path="${repo_root}/package.json"
	local compact_json=""

	[[ -f "$package_json_path" ]] || return 0

	compact_json="$(compact_json_file "$package_json_path")"
	extract_package_json_dependency_values "$compact_json" "$package_name" | select_single_normalized_version || true
}

detect_framework_badge_info() {
	local maybe_next=""
	local maybe_solid=""
	local maybe_react=""
	local maybe_vue=""
	local maybe_svelte=""
	local candidates=()

	maybe_next="$(detect_package_json_dependency_version "next" || true)"
	maybe_solid="$(detect_package_json_dependency_version "solid-js" || true)"
	maybe_react="$(detect_package_json_dependency_version "react" || true)"
	maybe_vue="$(detect_package_json_dependency_version "vue" || true)"
	maybe_svelte="$(detect_package_json_dependency_version "svelte" || true)"

	if [[ -n "$maybe_next" ]]; then
		candidates+=("Next.js|${maybe_next}|000000|nextdotjs|white|https://nextjs.org/")
	fi

	if [[ -n "$maybe_solid" ]]; then
		candidates+=("SolidJS|${maybe_solid}|2C4F7C|solid|white|https://www.solidjs.com/")
	fi

	if [[ -n "$maybe_vue" ]]; then
		candidates+=("Vue|${maybe_vue}|4FC08D|vuedotjs|white|https://vuejs.org/")
	fi

	if [[ -n "$maybe_svelte" ]]; then
		candidates+=("Svelte|${maybe_svelte}|FF3E00|svelte|white|https://svelte.dev/")
	fi

	if [[ -n "$maybe_react" && -z "$maybe_next" ]]; then
		candidates+=("React|${maybe_react}|149ECA|react|white|https://react.dev/")
	fi

	if [[ "${#candidates[@]}" -eq 1 ]]; then
		printf '%s\n' "${candidates[0]}"
	fi
}

extract_toml_value_from_section() {
	local file_path="$1"
	local section_name="$2"
	local key_name="$3"

	[[ -f "$file_path" ]] || return

	awk -v section_name="$section_name" -v key_name="$key_name" '
    $0 ~ "^[[:space:]]*\\[" section_name "\\][[:space:]]*$" {
      in_section = 1
      next
    }

    in_section == 1 && $0 ~ "^[[:space:]]*\\[" {
      in_section = 0
    }

    in_section == 1 && $0 ~ "^[[:space:]]*" key_name "[[:space:]]*=" {
      value = $0
      sub(/^[[:space:]]*[^=]+=[[:space:]]*/, "", value)
      sub(/[[:space:]]*#.*/, "", value)
      gsub(/^"/, "", value)
      gsub(/"$/, "", value)
      gsub(/^'\''/, "", value)
      gsub(/'\''$/, "", value)
      print value
      exit
    }
  ' "$file_path"
}

detect_rust_version() {
	local maybe_rust_toolchain="${repo_root}/rust-toolchain.toml"
	local maybe_cargo_toml="${repo_root}/Cargo.toml"
	local maybe_channel=""
	local maybe_normalized=""

	if [[ -f "$maybe_rust_toolchain" ]]; then
		maybe_channel="$(extract_toml_value_from_section "$maybe_rust_toolchain" "toolchain" "channel")"
		if [[ -n "$maybe_channel" ]]; then
			if maybe_normalized="$(normalize_badge_version "$maybe_channel" 2>/dev/null)"; then
				printf '%s\n' "$maybe_normalized"
			fi
			return
		fi
	fi

	if [[ -f "$maybe_cargo_toml" ]]; then
		maybe_channel="$(extract_toml_value_from_section "$maybe_cargo_toml" "package" "rust-version")"
		if [[ -n "$maybe_channel" ]]; then
			if maybe_normalized="$(normalize_badge_version "$maybe_channel" 2>/dev/null)"; then
				printf '%s\n' "$maybe_normalized"
			fi
		fi
	fi
}

detect_python_version() {
	local maybe_pyproject="${repo_root}/pyproject.toml"
	local maybe_python_version_file="${repo_root}/.python-version"
	local maybe_requires_python=""
	local maybe_normalized=""

	if [[ -f "$maybe_pyproject" ]]; then
		maybe_requires_python="$(awk '
      /^[[:space:]]*requires-python[[:space:]]*=/ {
        value = $0
        sub(/^[[:space:]]*requires-python[[:space:]]*=[[:space:]]*/, "", value)
        sub(/[[:space:]]*#.*/, "", value)
        gsub(/^"/, "", value)
        gsub(/"$/, "", value)
        gsub(/^'\''/, "", value)
        gsub(/'\''$/, "", value)
        print value
        exit
      }
    ' "$maybe_pyproject")"

		if [[ -n "$maybe_requires_python" ]]; then
			if maybe_normalized="$(normalize_badge_version "$maybe_requires_python" 2>/dev/null)"; then
				printf '%s\n' "$maybe_normalized"
			fi
			return
		fi
	fi

	if [[ -f "$maybe_python_version_file" ]]; then
		maybe_requires_python="$(awk 'NF { print; exit }' "$maybe_python_version_file")"
		if [[ -n "$maybe_requires_python" ]]; then
			if maybe_normalized="$(normalize_badge_version "$maybe_requires_python" 2>/dev/null)"; then
				printf '%s\n' "$maybe_normalized"
			fi
		fi
	fi
}

detect_go_version() {
	local maybe_go_mod="${repo_root}/go.mod"
	local maybe_go_version=""
	local maybe_normalized=""

	[[ -f "$maybe_go_mod" ]] || return 0

	maybe_go_version="$(awk '/^go[[:space:]]+[0-9]+([.][0-9]+){0,2}$/ { print $2; exit }' "$maybe_go_mod")"
	if [[ -n "$maybe_go_version" ]]; then
		if maybe_normalized="$(normalize_badge_version "$maybe_go_version" 2>/dev/null)"; then
			printf '%s\n' "$maybe_normalized"
		fi
	fi
}

resolve_downstream_badges() {
	local maybe_node_info=""
	local maybe_node_version=""
	local maybe_node_link=""
	local maybe_typescript_version=""
	local maybe_vite_version=""
	local maybe_framework_info=""
	local framework_label=""
	local framework_version=""
	local framework_color=""
	local framework_logo=""
	local framework_logo_color=""
	local framework_link=""
	local maybe_rust_version=""
	local maybe_python_version=""
	local maybe_go_version=""

	readme_badges_markdown=""
	readme_has_managed_badges=0
	downstream_ci_workflow_path="$(detect_existing_path ".github/workflows/ci.yml" ".github/workflows/ci.yaml" || true)"
	downstream_deploy_workflow_path="$(detect_existing_path ".github/workflows/deploy-pages.yml" ".github/workflows/deploy-pages.yaml" || true)"
	downstream_license_file="$(detect_license_file || true)"
	resolve_downstream_repo_slug

	if [[ -n "$downstream_repo_slug" ]]; then
		append_readme_badge "[![GitHub Stars](https://img.shields.io/github/stars/${downstream_repo_slug})](${downstream_repo_url})"

		if [[ -n "$downstream_ci_workflow_path" ]]; then
			local ci_workflow_badge_file=""
			ci_workflow_badge_file="$(basename "$downstream_ci_workflow_path")"
			append_readme_badge "[![CI](https://img.shields.io/github/actions/workflow/status/${downstream_repo_slug}/${ci_workflow_badge_file}?style=flat-square&logo=github&label=CI)](${downstream_repo_url}/actions/workflows/${ci_workflow_badge_file})"
		fi

		if [[ -n "$downstream_deploy_workflow_path" ]]; then
			local deploy_workflow_badge_file=""
			deploy_workflow_badge_file="$(basename "$downstream_deploy_workflow_path")"
			append_readme_badge "[![Deploy Pages](https://img.shields.io/github/actions/workflow/status/${downstream_repo_slug}/${deploy_workflow_badge_file}?style=flat-square&logo=github&label=Deploy%20Pages)](${downstream_repo_url}/actions/workflows/${deploy_workflow_badge_file})"
		fi

		if [[ -n "$downstream_license_file" ]]; then
			append_readme_badge "[![License](https://img.shields.io/github/license/${downstream_repo_slug}?style=flat-square)](./${downstream_license_file})"
		fi
	fi

	maybe_node_info="$(detect_node_version_info || true)"
	if [[ -n "$maybe_node_info" ]]; then
		maybe_node_version="${maybe_node_info%%|*}"
		maybe_node_link="${maybe_node_info#*|}"
		append_readme_badge "$(build_static_badge_markdown "Node.js" "$maybe_node_version" "339933" "node.js" "white" "./${maybe_node_link}")"
	fi

	maybe_typescript_version="$(detect_package_json_dependency_version "typescript" || true)"
	if [[ -n "$maybe_typescript_version" ]]; then
		append_readme_badge "$(build_static_badge_markdown "TypeScript" "$maybe_typescript_version" "3178C6" "typescript" "white" "https://www.typescriptlang.org/")"
	fi

	maybe_framework_info="$(detect_framework_badge_info || true)"
	if [[ -n "$maybe_framework_info" ]]; then
		IFS='|' read -r framework_label framework_version framework_color framework_logo framework_logo_color framework_link <<<"$maybe_framework_info"
		append_readme_badge "$(build_static_badge_markdown "$framework_label" "$framework_version" "$framework_color" "$framework_logo" "$framework_logo_color" "$framework_link")"
	fi

	maybe_vite_version="$(detect_package_json_dependency_version "vite" || true)"
	if [[ -n "$maybe_vite_version" ]]; then
		append_readme_badge "$(build_static_badge_markdown "Vite" "$maybe_vite_version" "646CFF" "vite" "white" "https://vite.dev/")"
	fi

	maybe_rust_version="$(detect_rust_version || true)"
	if [[ -n "$maybe_rust_version" ]]; then
		append_readme_badge "$(build_static_badge_markdown "Rust" "$maybe_rust_version" "000000" "rust" "white" "https://www.rust-lang.org/")"
	fi

	maybe_python_version="$(detect_python_version || true)"
	if [[ -n "$maybe_python_version" ]]; then
		append_readme_badge "$(build_static_badge_markdown "Python" "$maybe_python_version" "3776AB" "python" "white" "https://www.python.org/")"
	fi

	maybe_go_version="$(detect_go_version || true)"
	if [[ -n "$maybe_go_version" ]]; then
		append_readme_badge "$(build_static_badge_markdown "Go" "$maybe_go_version" "00ADD8" "go" "white" "https://go.dev/")"
	fi

	append_bright_builds_readme_badge
	append_owner_specific_readme_badge
}

resolve_owner_specific_guidance() {
	owner_specific_guidance_markdown="$(build_owner_specific_guidance_markdown)"
}

resolve_auto_update_default() {
	auto_update_mode="disabled"
	auto_update_reason="default disabled"

	if is_trusted_auto_update_identity "$downstream_repo_owner"; then
		auto_update_mode="enabled"
		auto_update_reason="trusted repo owner ${downstream_repo_owner}"
		return
	fi

	resolve_current_github_user

	if is_trusted_auto_update_identity "$current_github_user"; then
		auto_update_mode="enabled"
		auto_update_reason="trusted GitHub user ${current_github_user}"
	fi
}

resolve_auto_update_state() {
	auto_update_mode=""
	auto_update_reason=""

	if [[ "$auto_update_was_explicit" -eq 0 ]] && [[ "$current_auto_update" == "enabled" || "$current_auto_update" == "disabled" ]]; then
		auto_update_mode="$current_auto_update"
		auto_update_reason="$current_auto_update_reason"

		if [[ -z "$auto_update_reason" ]]; then
			auto_update_reason="explicit"
		fi

		return
	fi

	case "$auto_update_request" in
	enabled | disabled)
		auto_update_mode="$auto_update_request"
		auto_update_reason="explicit"
		;;
	auto)
		resolve_auto_update_default
		;;
	*)
		die "unsupported auto-update mode: ${auto_update_request}"
		;;
	esac
}

auto_update_files_are_relevant() {
	[[ "$auto_update_mode" == "enabled" || "$current_auto_update" == "enabled" ]]
}
