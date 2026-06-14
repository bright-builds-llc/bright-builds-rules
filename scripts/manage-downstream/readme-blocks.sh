render_readme_badges_block_to_tmp_path() {
	local rendered_path=""

	ensure_tmp_dir
	rendered_path="${tmp_dir}/README.badges.rendered"
	{
		printf '%s\n\n' "$readme_badges_begin"
		printf '%s\n' "<!-- Managed upstream by bright-builds-rules. If this badge block needs a fix, open an upstream PR or issue instead of editing the downstream managed block. Keep repo-local README content outside this managed badge block. -->"
		if [[ -n "$readme_badges_markdown" ]]; then
			printf '\n%s\n\n' "$readme_badges_markdown"
		else
			printf '\n'
		fi
		printf '%s\n' "$readme_badges_end"
	} >"$rendered_path"

	printf '%s\n' "$rendered_path"
}

insert_readme_badges_block() {
	local input_path="$1"
	local output_path="$2"
	local replacement_path="$3"

	awk -v replacement_path="$replacement_path" '
    BEGIN {
      while ((getline line < replacement_path) > 0) {
        replacement[++replacement_count] = line
      }
      close(replacement_path)
    }

    {
      lines[++count] = $0
      if (first_h1 == 0 && $0 ~ /^# /) {
        first_h1 = count
      }
    }

    END {
      if (first_h1 > 0) {
        for (i = 1; i <= count; i++) {
          print lines[i]

          if (i == first_h1) {
            print ""
            for (j = 1; j <= replacement_count; j++) {
              print replacement[j]
            }

            if (i < count) {
              print ""
            }

            while (i + 1 <= count && lines[i + 1] ~ /^[[:space:]]*$/) {
              i++
            }
          }
        }
        exit
      }

      for (j = 1; j <= replacement_count; j++) {
        print replacement[j]
      }

      if (count > 0) {
        print ""
      }

      first_content = 1
      while (first_content <= count && lines[first_content] ~ /^[[:space:]]*$/) {
        first_content++
      }

      for (i = first_content; i <= count; i++) {
        print lines[i]
      }
    }
  ' "$input_path" >"$output_path"
}

strip_readme_badge_region() {
	local input_path="$1"
	local output_path="$2"
	local lines=()
	local line=""
	local first_h1_index=-1
	local start_index=0
	local index=0
	local in_marker_block=0

	while IFS= read -r line || [[ -n "$line" ]]; do
		lines+=("$line")
	done <"$input_path"

	for ((index = 0; index < ${#lines[@]}; index++)); do
		if [[ "${lines[index]}" == '# '* ]]; then
			first_h1_index="$index"
			break
		fi
	done

	if ((first_h1_index >= 0)); then
		start_index=$((first_h1_index + 1))
	fi

	{
		if ((first_h1_index >= 0)); then
			for ((index = 0; index <= first_h1_index; index++)); do
				printf '%s\n' "${lines[index]}"
			done
		fi

		index="$start_index"
		while ((index < ${#lines[@]})); do
			line="${lines[index]}"

			if [[ "$in_marker_block" -eq 1 ]]; then
				if line_is_any_readme_badges_end_marker "$line"; then
					in_marker_block=0
					((index++))
					continue
				fi

				if line_is_blank "$line" || readme_line_is_badge_like "$line" || line_is_any_readme_badges_begin_marker "$line"; then
					((index++))
					continue
				fi

				break
			fi

			if line_is_any_readme_badges_begin_marker "$line"; then
				in_marker_block=1
				((index++))
				continue
			fi

			if line_is_any_readme_badges_end_marker "$line" || line_is_blank "$line" || readme_line_is_badge_like "$line"; then
				((index++))
				continue
			fi

			break
		done

		if ((first_h1_index >= 0 && index < ${#lines[@]})); then
			printf '\n'
		fi

		for (( ; index < ${#lines[@]}; index++)); do
			printf '%s\n' "${lines[index]}"
		done
	} >"$output_path"
}

normalize_legacy_bright_builds_readme_badges() {
	local input_path="$1"
	local output_path="$2"
	local remove_insertion_zone_legacy="$3"
	local lines=()
	local line=""
	local maybe_replacement=""
	local first_h1_index=-1
	local start_index=0
	local index=0
	local in_insertion_zone=0
	local insertion_zone_complete=0

	while IFS= read -r line || [[ -n "$line" ]]; do
		lines+=("$line")
	done <"$input_path"

	for ((index = 0; index < ${#lines[@]}; index++)); do
		if [[ "${lines[index]}" == '# '* ]]; then
			first_h1_index="$index"
			break
		fi
	done

	if ((first_h1_index >= 0)); then
		start_index=$((first_h1_index + 1))
	fi

	{
		for ((index = 0; index < ${#lines[@]}; index++)); do
			line="${lines[index]}"

			if ((insertion_zone_complete == 0 && index >= start_index)) && [[ "$in_insertion_zone" -eq 0 ]]; then
				in_insertion_zone=1
			fi

			if maybe_replacement="$(normalize_known_legacy_bright_builds_badge_line "$line" 2>/dev/null)"; then
				if [[ "$in_insertion_zone" -eq 1 && "$remove_insertion_zone_legacy" -eq 1 ]]; then
					continue
				fi

				printf '%s\n' "$maybe_replacement"
				continue
			fi

			printf '%s\n' "$line"

			if [[ "$in_insertion_zone" -eq 1 ]] && ! line_is_blank "$line" && ! readme_line_is_badge_like "$line"; then
				in_insertion_zone=0
				insertion_zone_complete=1
			fi
		done
	} >"$output_path"
}

build_readme_title() {
	printf '# %s\n' "$(basename "$repo_root")"
}

readme_is_generated_skeleton_after_removal() {
	local file_path="$1"
	local expected_title=""
	local trimmed_content=""

	[[ -f "$file_path" ]] || return 1

	expected_title="$(build_readme_title)"
	trimmed_content="$(awk '
    {
      lines[++count] = $0
    }

    END {
      last = count
      while (last > 0 && lines[last] ~ /^[[:space:]]*$/) {
        last--
      }

      first = 1
      while (first <= last && lines[first] ~ /^[[:space:]]*$/) {
        first++
      }

      for (i = first; i <= last; i++) {
        print lines[i]
      }
    }
  ' "$file_path")"

	[[ "$trimmed_content" == "$expected_title" ]]
}

append_unique_blocking_path() {
	local candidate="$1"
	local existing=""

	for existing in "${blocking_paths[@]-}"; do
		if [[ "$existing" == "$candidate" ]]; then
			return
		fi
	done

	blocking_paths+=("$candidate")
}
