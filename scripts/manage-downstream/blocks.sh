detect_marker_block_state() {
	local file_path="$1"
	local begin_marker="$2"
	local end_marker="$3"

	if [[ ! -f "$file_path" ]]; then
		printf 'absent\n'
		return
	fi

	awk -v begin_marker="$begin_marker" -v end_marker="$end_marker" '
    $0 == begin_marker {
      begin_count++
      if (begin_line == 0) {
        begin_line = NR
      }
    }

    $0 == end_marker {
      end_count++
      if (end_line == 0) {
        end_line = NR
      }
    }

    END {
      if (begin_count == 0 && end_count == 0) {
        print "absent"
        exit
      }

      if (begin_count == 1 && end_count == 1 && begin_line < end_line) {
        print "present"
        exit
      }

      print "partial"
    }
  ' "$file_path"
}

compatible_marker_state="absent"
compatible_marker_family="absent"

resolve_compatible_marker_block_state() {
	local file_path="$1"
	local current_begin_marker="$2"
	local current_end_marker="$3"
	local legacy_begin_marker="$4"
	local legacy_end_marker="$5"
	local current_state=""
	local legacy_state=""

	compatible_marker_state="absent"
	compatible_marker_family="absent"

	current_state="$(detect_marker_block_state "$file_path" "$current_begin_marker" "$current_end_marker")"
	legacy_state="$(detect_marker_block_state "$file_path" "$legacy_begin_marker" "$legacy_end_marker")"

	if [[ "$current_state" == "present" && "$legacy_state" == "absent" ]]; then
		compatible_marker_state="present"
		compatible_marker_family="current"
		return
	fi

	if [[ "$current_state" == "absent" && "$legacy_state" == "present" ]]; then
		compatible_marker_state="present"
		compatible_marker_family="legacy"
		return
	fi

	if [[ "$current_state" == "absent" && "$legacy_state" == "absent" ]]; then
		compatible_marker_state="absent"
		compatible_marker_family="absent"
		return
	fi

	compatible_marker_state="partial"
	compatible_marker_family="partial"
}

resolve_agents_block_state() {
	local file_path="$1"

	resolve_compatible_marker_block_state "$file_path" "$agents_block_begin" "$agents_block_end" "$legacy_agents_block_begin" "$legacy_agents_block_end"
	agents_block_state="$compatible_marker_state"
	agents_block_family="$compatible_marker_family"
}

resolve_contributing_block_state() {
	local file_path="$1"

	contributing_block_state="$(detect_marker_block_state "$file_path" "$contributing_block_begin" "$contributing_block_end")"
}

resolve_readme_badges_block_state() {
	local file_path="$1"

	resolve_compatible_marker_block_state "$file_path" "$readme_badges_begin" "$readme_badges_end" "$legacy_readme_badges_begin" "$legacy_readme_badges_end"
	readme_badges_family="$compatible_marker_family"
}

line_is_any_readme_badges_begin_marker() {
	[[ "${1:-}" == "$readme_badges_begin" || "${1:-}" == "$legacy_readme_badges_begin" ]]
}

line_is_any_readme_badges_end_marker() {
	[[ "${1:-}" == "$readme_badges_end" || "${1:-}" == "$legacy_readme_badges_end" ]]
}

readme_insertion_zone_has_unmanaged_badges() {
	local file_path="$1"
	local lines=()
	local line=""
	local maybe_replacement=""
	local first_h1_index=-1
	local index=0
	local start_index=0
	local in_managed=0

	[[ -f "$file_path" ]] || return 1

	while IFS= read -r line || [[ -n "$line" ]]; do
		lines+=("$line")
	done <"$file_path"

	for ((index = 0; index < ${#lines[@]}; index++)); do
		if [[ "${lines[index]}" == '# '* ]]; then
			first_h1_index="$index"
			break
		fi
	done

	if ((first_h1_index >= 0)); then
		start_index=$((first_h1_index + 1))
	fi

	for ((index = start_index; index < ${#lines[@]}; index++)); do
		line="${lines[index]}"

		if line_is_any_readme_badges_begin_marker "$line"; then
			in_managed=1
			continue
		fi

		if line_is_any_readme_badges_end_marker "$line"; then
			in_managed=0
			continue
		fi

		if [[ "$in_managed" -eq 1 ]] || line_is_blank "$line"; then
			continue
		fi

		if maybe_replacement="$(normalize_known_legacy_bright_builds_badge_line "$line" 2>/dev/null)"; then
			continue
		fi

		if readme_line_is_badge_like "$line"; then
			return 0
		fi

		break
	done

	return 1
}

resolve_readme_badge_state() {
	local destination_path="${repo_root}/${readme_destination}"
	local block_state=""

	readme_badge_blocking_reason=""

	if [[ ! -f "$destination_path" ]]; then
		if [[ "$readme_has_managed_badges" -eq 1 ]]; then
			printf 'absent\n'
		else
			printf 'not applicable\n'
		fi
		return
	fi

	resolve_readme_badges_block_state "$destination_path"
	block_state="$compatible_marker_state"

	if [[ "$block_state" == "partial" ]]; then
		readme_badge_blocking_reason="incomplete managed README badge block"
		printf 'partial\n'
		return
	fi

	if { [[ "$readme_has_managed_badges" -eq 1 ]] || [[ "$block_state" == "present" ]]; } && readme_insertion_zone_has_unmanaged_badges "$destination_path"; then
		readme_badge_blocking_reason="existing badge-like content in the managed README insertion zone"
		printf 'ambiguous\n'
		return
	fi

	if [[ "$block_state" == "present" ]]; then
		printf 'present\n'
		return
	fi

	if [[ "$readme_has_managed_badges" -eq 1 ]]; then
		printf 'absent\n'
		return
	fi

	printf 'not applicable\n'
}

replace_marker_block() {
	local input_path="$1"
	local output_path="$2"
	local replacement_path="$3"
	local begin_marker="$4"
	local end_marker="$5"

	awk -v begin_marker="$begin_marker" -v end_marker="$end_marker" -v replacement_path="$replacement_path" '
    BEGIN {
      while ((getline line < replacement_path) > 0) {
        replacement[++replacement_count] = line
      }
      close(replacement_path)
    }

    $0 == begin_marker && in_block == 0 {
      for (i = 1; i <= replacement_count; i++) {
        print replacement[i]
      }
      in_block = 1
      replaced = 1
      next
    }

    in_block == 1 {
      if ($0 == end_marker) {
        in_block = 0
      }
      next
    }

    {
      print
    }

    END {
      if (replaced != 1) {
        exit 3
      }
    }
  ' "$input_path" >"$output_path"
}

replace_managed_block() {
	resolve_agents_block_state "$1"

	if [[ "$agents_block_family" == "legacy" ]]; then
		replace_marker_block "$1" "$2" "$3" "$legacy_agents_block_begin" "$legacy_agents_block_end"
		return
	fi

	replace_marker_block "$1" "$2" "$3" "$agents_block_begin" "$agents_block_end"
}

replace_contributing_block() {
	replace_marker_block "$1" "$2" "$3" "$contributing_block_begin" "$contributing_block_end"
}

replace_readme_badges_block() {
	resolve_readme_badges_block_state "$1"

	if [[ "$readme_badges_family" == "legacy" ]]; then
		replace_marker_block "$1" "$2" "$3" "$legacy_readme_badges_begin" "$legacy_readme_badges_end"
		return
	fi

	replace_marker_block "$1" "$2" "$3" "$readme_badges_begin" "$readme_badges_end"
}

extract_marker_block() {
	local input_path="$1"
	local output_path="$2"
	local begin_marker="$3"
	local end_marker="$4"

	awk -v begin_marker="$begin_marker" -v end_marker="$end_marker" '
    $0 == begin_marker && in_block == 0 {
      in_block = 1
      extracted = 1
    }

    in_block == 1 {
      print
      if ($0 == end_marker) {
        in_block = 0
      }
      next
    }

    END {
      if (extracted != 1 || in_block == 1) {
        exit 3
      }
    }
  ' "$input_path" >"$output_path"
}

remove_marker_block() {
	local input_path="$1"
	local output_path="$2"
	local begin_marker="$3"
	local end_marker="$4"

	awk -v begin_marker="$begin_marker" -v end_marker="$end_marker" '
    $0 == begin_marker && in_block == 0 {
      in_block = 1
      removed = 1
      next
    }

    in_block == 1 {
      if ($0 == end_marker) {
        in_block = 0
      }
      next
    }

    {
      print
    }

    END {
      if (removed != 1) {
        exit 3
      }
    }
  ' "$input_path" >"$output_path"
}

remove_managed_block() {
	resolve_agents_block_state "$1"

	if [[ "$agents_block_family" == "legacy" ]]; then
		remove_marker_block "$1" "$2" "$legacy_agents_block_begin" "$legacy_agents_block_end"
		return
	fi

	remove_marker_block "$1" "$2" "$agents_block_begin" "$agents_block_end"
}

remove_contributing_block() {
	remove_marker_block "$1" "$2" "$contributing_block_begin" "$contributing_block_end"
}

remove_readme_badges_block() {
	resolve_readme_badges_block_state "$1"

	if [[ "$readme_badges_family" == "legacy" ]]; then
		remove_marker_block "$1" "$2" "$legacy_readme_badges_begin" "$legacy_readme_badges_end"
		return
	fi

	remove_marker_block "$1" "$2" "$readme_badges_begin" "$readme_badges_end"
}

remove_readme_badge_markers() {
	local input_path="$1"
	local output_path="$2"

	awk -v begin_marker="$readme_badges_begin" -v end_marker="$readme_badges_end" -v legacy_begin_marker="$legacy_readme_badges_begin" -v legacy_end_marker="$legacy_readme_badges_end" '
    $0 == begin_marker || $0 == end_marker || $0 == legacy_begin_marker || $0 == legacy_end_marker {
      next
    }

    {
      print
    }
  ' "$input_path" >"$output_path"
}
