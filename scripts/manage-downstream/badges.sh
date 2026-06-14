file_has_non_whitespace() {
	local file_path="$1"
	[[ -f "$file_path" ]] && grep -q '[^[:space:]]' "$file_path"
}

trim_trailing_blank_lines() {
	local input_path="$1"
	local output_path="$2"

	awk '
    {
      lines[NR] = $0
    }
    END {
      last = NR
      while (last > 0 && lines[last] ~ /^[[:space:]]*$/) {
        last--
      }

      for (i = 1; i <= last; i++) {
        print lines[i]
      }
    }
  ' "$input_path" >"$output_path"
}

trim_value() {
	printf '%s' "${1:-}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

urlencode_component() {
	local input="${1:-}"
	local output=""
	local index=""
	local character=""
	local hex=""
	local ascii_code=""

	LC_ALL=C

	for ((index = 0; index < ${#input}; index++)); do
		character="${input:index:1}"

		case "$character" in
		[a-zA-Z0-9._~-])
			output="${output}${character}"
			;;
		' ')
			output="${output}%20"
			;;
		*)
			printf -v ascii_code '%d' "'$character"
			printf -v hex '%%%02X' "$ascii_code"
			output="${output}${hex}"
			;;
		esac
	done

	printf '%s\n' "$output"
}

build_static_badge_markdown() {
	local label="$1"
	local version="$2"
	local color="$3"
	local logo="${4:-}"
	local logo_color="${5:-}"
	local link_target="$6"
	local encoded_label=""
	local encoded_version=""
	local image_url=""

	encoded_label="$(urlencode_component "$label")"
	encoded_version="$(urlencode_component "$version")"
	image_url="https://img.shields.io/badge/${encoded_label}-${encoded_version}-${color}"

	if [[ -n "$logo" ]]; then
		image_url="${image_url}?logo=$(urlencode_component "$logo")"
		if [[ -n "$logo_color" ]]; then
			image_url="${image_url}&logoColor=$(urlencode_component "$logo_color")"
		fi
	fi

	printf '[![%s %s](%s)](%s)\n' "$label" "$version" "$image_url" "$link_target"
}

build_current_manual_bright_builds_badge_markdown() {
	local variant="$1"

	case "$variant" in
	canonical)
		printf '[![Bright Builds Rules](%s/public/badges/bright-builds-rules.svg)](%s)\n' "$bright_builds_rules_raw_base_url" "$bright_builds_rules_url"
		;;
	flat)
		printf '[![Bright Builds: Rules](%s/public/badges/bright-builds-rules-flat.svg)](%s)\n' "$bright_builds_rules_raw_base_url" "$bright_builds_rules_url"
		;;
	dark)
		printf '[![Bright Builds Rules](%s/assets/badges/bright-builds-rules-dark.svg)](%s)\n' "$bright_builds_rules_raw_base_url" "$bright_builds_rules_url"
		;;
	light)
		printf '[![Bright Builds Rules](%s/assets/badges/bright-builds-rules-light.svg)](%s)\n' "$bright_builds_rules_raw_base_url" "$bright_builds_rules_url"
		;;
	compact)
		printf '[![Bright Builds Rules](%s/assets/badges/bright-builds-rules-compact.svg)](%s)\n' "$bright_builds_rules_raw_base_url" "$bright_builds_rules_url"
		;;
	*)
		return 1
		;;
	esac
}

normalize_known_legacy_bright_builds_badge_line() {
	local line="$1"
	local old_canonical_raw=""
	local old_canonical_relative=""
	local old_flat_raw=""
	local old_flat_relative=""
	local old_dark_raw=""
	local old_dark_relative=""
	local old_light_raw=""
	local old_light_relative=""
	local old_compact_raw=""
	local old_compact_relative=""

	old_canonical_raw="[![Bright Builds Requirements](${legacy_bright_builds_raw_base_url}/public/badges/bright-builds.svg)](${legacy_bright_builds_url})"
	old_canonical_relative="[![Bright Builds Requirements](public/badges/bright-builds.svg)](${legacy_bright_builds_url})"
	old_flat_raw="[![Bright Builds: Coding requirements](${legacy_bright_builds_raw_base_url}/public/badges/bright-builds-flat.svg)](${legacy_bright_builds_url})"
	old_flat_relative="[![Bright Builds: Coding requirements](public/badges/bright-builds-flat.svg)](${legacy_bright_builds_url})"
	old_dark_raw="[![Bright Builds Requirements](${legacy_bright_builds_raw_base_url}/assets/badges/bright-builds-requirements-dark.svg)](${legacy_bright_builds_url})"
	old_dark_relative="[![Bright Builds Requirements](assets/badges/bright-builds-requirements-dark.svg)](${legacy_bright_builds_url})"
	old_light_raw="[![Bright Builds Requirements](${legacy_bright_builds_raw_base_url}/assets/badges/bright-builds-requirements-light.svg)](${legacy_bright_builds_url})"
	old_light_relative="[![Bright Builds Requirements](assets/badges/bright-builds-requirements-light.svg)](${legacy_bright_builds_url})"
	old_compact_raw="[![Uses Bright Builds](${legacy_bright_builds_raw_base_url}/assets/badges/bright-builds-requirements-compact.svg)](${legacy_bright_builds_url})"
	old_compact_relative="[![Uses Bright Builds](assets/badges/bright-builds-requirements-compact.svg)](${legacy_bright_builds_url})"

	if [[ "$line" == "$old_canonical_raw" || "$line" == "$old_canonical_relative" ]]; then
		build_current_manual_bright_builds_badge_markdown "canonical"
		return 0
	fi

	if [[ "$line" == "$old_flat_raw" || "$line" == "$old_flat_relative" ]]; then
		build_current_manual_bright_builds_badge_markdown "flat"
		return 0
	fi

	if [[ "$line" == "$old_dark_raw" || "$line" == "$old_dark_relative" ]]; then
		build_current_manual_bright_builds_badge_markdown "dark"
		return 0
	fi

	if [[ "$line" == "$old_light_raw" || "$line" == "$old_light_relative" ]]; then
		build_current_manual_bright_builds_badge_markdown "light"
		return 0
	fi

	if [[ "$line" == "$old_compact_raw" || "$line" == "$old_compact_relative" ]]; then
		build_current_manual_bright_builds_badge_markdown "compact"
		return 0
	fi

	return 1
}

line_is_blank() {
	[[ "${1:-}" =~ ^[[:space:]]*$ ]]
}

readme_line_is_badge_like() {
	local line="$1"

	if [[ "$line" == *"shields.io"* || "$line" == *"badge.svg"* || "$line" == *"badge?"* ]]; then
		return 0
	fi

	if [[ "$line" == *"<img"* ]] && [[ "$line" == *"badge"* || "$line" == *"shields"* ]]; then
		return 0
	fi

	if [[ "$line" == *"raw.githubusercontent.com/bright-builds-llc/"*"/public/badges/bright-builds"*.svg* ]]; then
		return 0
	fi

	if [[ "$line" == *"raw.githubusercontent.com/bright-builds-llc/"*"/assets/badges/bright-builds"*.svg* ]]; then
		return 0
	fi

	if [[ "$line" == *"(public/badges/bright-builds"*.svg* || "$line" == *"(assets/badges/bright-builds"*.svg* ]]; then
		return 0
	fi

	return 1
}

append_readme_badge() {
	local badge_markdown="$1"

	[[ -n "$badge_markdown" ]] || return

	if [[ -n "$readme_badges_markdown" ]]; then
		readme_badges_markdown="${readme_badges_markdown}
"
	fi

	readme_badges_markdown="${readme_badges_markdown}${badge_markdown}"
	readme_has_managed_badges=1
}

append_bright_builds_readme_badge() {
	if [[ "$readme_has_managed_badges" -ne 1 ]]; then
		return 0
	fi

	append_readme_badge "[![Bright Builds: Rules](${bright_builds_badges_base_url}/bright-builds-rules-flat.svg)](${bright_builds_rules_url})"
}

append_owner_specific_readme_badge() {
	if ! is_openlinks_identity_owner "$downstream_repo_owner"; then
		return 0
	fi

	append_readme_badge "$(build_static_badge_markdown "OpenLinks" "profile" "0F172A" "" "" "$openlinks_identity_url")"
}

normalize_badge_version() {
	local raw_value="$1"
	local normalized=""

	normalized="$(trim_value "$raw_value")"
	normalized="${normalized#\"}"
	normalized="${normalized%\"}"
	normalized="${normalized#\'}"
	normalized="${normalized%\'}"
	normalized="$(trim_value "$normalized")"

	[[ -n "$normalized" ]] || return 1

	if [[ "$normalized" =~ [[:space:],|] ]]; then
		return 1
	fi

	case "$normalized" in
	^* | ~*)
		normalized="${normalized:1}"
		;;
	==*)
		normalized="${normalized#==}"
		;;
	=*)
		normalized="${normalized#=}"
		;;
	esac

	if [[ "$normalized" =~ ^[vV]([0-9]+([.][0-9]+){0,2})$ ]]; then
		normalized="${BASH_REMATCH[1]}"
	elif [[ "$normalized" =~ ^([0-9]+([.][0-9]+){0,2})([xX*]|[.][xX*])$ ]]; then
		normalized="${BASH_REMATCH[1]}"
	fi

	if [[ "$normalized" =~ ^(>=|<=|>|<)([0-9]+([.][0-9]+){0,2})$ ]]; then
		printf '%s\n' "${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
		return 0
	fi

	if [[ "$normalized" =~ ^[0-9A-Za-z._+-]+$ ]]; then
		printf '%s\n' "$normalized"
		return 0
	fi

	return 1
}

select_single_normalized_version() {
	local raw_value=""
	local normalized=""
	local maybe_existing=""
	local seen_values=()
	local already_seen=0

	while IFS= read -r raw_value; do
		if ! normalized="$(normalize_badge_version "$raw_value" 2>/dev/null)"; then
			continue
		fi

		already_seen=0
		for maybe_existing in "${seen_values[@]-}"; do
			if [[ "$maybe_existing" == "$normalized" ]]; then
				already_seen=1
				break
			fi
		done

		if [[ "$already_seen" -eq 0 ]]; then
			seen_values+=("$normalized")
		fi
	done

	if [[ "${#seen_values[@]}" -eq 1 ]]; then
		printf '%s\n' "${seen_values[0]}"
		return 0
	fi

	return 1
}
