cleanup() {
	rm -rf "$temp_root"
}

fail() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

managed_file_marker() {
	local relative_destination="$1"

	case "$relative_destination" in
	*.md)
		printf '<!-- bright-builds-rules-managed-file: %s -->\n' "$relative_destination"
		;;
	*.sh | *.yml | *.yaml)
		printf '# bright-builds-rules-managed-file: %s\n' "$relative_destination"
		;;
	*)
		printf '# bright-builds-rules-managed-file: %s\n' "$relative_destination"
		;;
	esac
}

legacy_managed_file_marker() {
	local relative_destination="$1"

	case "$relative_destination" in
	*.md)
		printf '<!-- coding-and-architecture-requirements-managed-file: %s -->\n' "$relative_destination"
		;;
	*.sh | *.yml | *.yaml)
		printf '# coding-and-architecture-requirements-managed-file: %s\n' "$relative_destination"
		;;
	*)
		printf '# coding-and-architecture-requirements-managed-file: %s\n' "$relative_destination"
		;;
	esac
}

legacy_bright_builds_badge() {
	local variant="$1"

	case "$variant" in
	canonical)
		printf '[![Bright Builds Requirements](%s/public/badges/bright-builds.svg)](%s)\n' "$legacy_bright_builds_raw_base_url" "$legacy_bright_builds_url"
		;;
	flat)
		printf '[![Bright Builds: Coding requirements](%s/public/badges/bright-builds-flat.svg)](%s)\n' "$legacy_bright_builds_raw_base_url" "$legacy_bright_builds_url"
		;;
	dark)
		printf '[![Bright Builds Requirements](%s/assets/badges/bright-builds-requirements-dark.svg)](%s)\n' "$legacy_bright_builds_raw_base_url" "$legacy_bright_builds_url"
		;;
	light)
		printf '[![Bright Builds Requirements](%s/assets/badges/bright-builds-requirements-light.svg)](%s)\n' "$legacy_bright_builds_raw_base_url" "$legacy_bright_builds_url"
		;;
	compact)
		printf '[![Uses Bright Builds](%s/assets/badges/bright-builds-requirements-compact.svg)](%s)\n' "$legacy_bright_builds_raw_base_url" "$legacy_bright_builds_url"
		;;
	*)
		fail "unsupported legacy badge variant: ${variant}"
		;;
	esac
}

current_bright_builds_badge() {
	local variant="$1"

	case "$variant" in
	canonical)
		printf '[![Bright Builds Rules](%s/public/badges/bright-builds-rules.svg)](%s)\n' "$current_bright_builds_raw_base_url" "$current_bright_builds_url"
		;;
	flat)
		printf '[![Bright Builds: Rules](%s/public/badges/bright-builds-rules-flat.svg)](%s)\n' "$current_bright_builds_raw_base_url" "$current_bright_builds_url"
		;;
	dark)
		printf '[![Bright Builds Rules](%s/assets/badges/bright-builds-rules-dark.svg)](%s)\n' "$current_bright_builds_raw_base_url" "$current_bright_builds_url"
		;;
	light)
		printf '[![Bright Builds Rules](%s/assets/badges/bright-builds-rules-light.svg)](%s)\n' "$current_bright_builds_raw_base_url" "$current_bright_builds_url"
		;;
	compact)
		printf '[![Bright Builds Rules](%s/assets/badges/bright-builds-rules-compact.svg)](%s)\n' "$current_bright_builds_raw_base_url" "$current_bright_builds_url"
		;;
	*)
		fail "unsupported current badge variant: ${variant}"
		;;
	esac
}

assert_eq() {
	local actual="$1"
	local expected="$2"
	local message="$3"

	if [[ "$actual" != "$expected" ]]; then
		fail "${message}: expected '${expected}', got '${actual}'"
	fi
}

assert_contains() {
	local haystack="$1"
	local needle="$2"
	local message="$3"

	if [[ "$haystack" != *"$needle"* ]]; then
		fail "${message}: missing '${needle}'"
	fi
}

assert_not_contains() {
	local haystack="$1"
	local needle="$2"
	local message="$3"

	if [[ "$haystack" == *"$needle"* ]]; then
		fail "${message}: unexpectedly found '${needle}'"
	fi
}

assert_file_exists() {
	local file_path="$1"

	[[ -f "$file_path" ]] || fail "expected file to exist: $file_path"
}

assert_file_missing() {
	local file_path="$1"

	[[ ! -f "$file_path" ]] || fail "expected file to be absent: $file_path"
}

assert_file_contains() {
	local file_path="$1"
	local needle="$2"
	local message="$3"

	grep -Fq "$needle" "$file_path" || fail "${message}: missing '${needle}' in ${file_path}"
}

assert_file_not_contains() {
	local file_path="$1"
	local needle="$2"
	local message="$3"

	if grep -Fq "$needle" "$file_path"; then
		fail "${message}: unexpectedly found '${needle}' in ${file_path}"
	fi
}

assert_file_contains_regex() {
	local file_path="$1"
	local pattern="$2"
	local message="$3"

	grep -Eq "$pattern" "$file_path" || fail "${message}: missing pattern '${pattern}' in ${file_path}"
}

assert_managed_standards_exist() {
	local repo_path="$1"
	local standards_path=""

	for standards_path in \
		"standards/index.md" \
		"standards/core/architecture.md" \
		"standards/core/code-shape.md" \
		"standards/core/local-guidance.md" \
		"standards/core/operability.md" \
		"standards/core/testing.md" \
		"standards/core/verification.md" \
		"standards/languages/rust.md" \
		"standards/languages/typescript-javascript.md"; do
		assert_file_exists "${repo_path}/${standards_path}"
	done
}

assert_managed_standards_missing() {
	local repo_path="$1"
	local standards_path=""

	for standards_path in \
		"standards/index.md" \
		"standards/core/architecture.md" \
		"standards/core/code-shape.md" \
		"standards/core/local-guidance.md" \
		"standards/core/operability.md" \
		"standards/core/testing.md" \
		"standards/core/verification.md" \
		"standards/languages/rust.md" \
		"standards/languages/typescript-javascript.md"; do
		assert_file_missing "${repo_path}/${standards_path}"
	done
}

assert_command_succeeds() {
	local message="$1"
	shift

	"$@" >/dev/null 2>&1 || fail "${message}: $*"
}

assert_markdown_is_mdformat_clean() {
	local message="$1"
	shift

	command -v mdformat >/dev/null 2>&1 || fail "mdformat must be available on PATH for markdown cleanliness assertions"
	mdformat --check "$@" >/dev/null 2>&1 || fail "${message}: mdformat --check failed for $*"
}

assert_line_equals() {
	local file_path="$1"
	local line_number="$2"
	local expected_line="$3"
	local message="$4"
	local actual_line=""

	actual_line="$(sed -n "${line_number}p" "$file_path")"
	if [[ "$actual_line" != "$expected_line" ]]; then
		fail "${message}: expected '${expected_line}' on line ${line_number} of ${file_path}, got '${actual_line}'"
	fi
}

assert_exact_line_count() {
	local file_path="$1"
	local needle="$2"
	local expected_count="$3"
	local actual_count=""

	actual_count="$(awk -v needle="$needle" '$0 == needle { count++ } END { print count + 0 }' "$file_path")"
	assert_eq "$actual_count" "$expected_count" "unexpected marker count in ${file_path}"
}

assert_line_order() {
	local file_path="$1"
	local first="$2"
	local second="$3"
	local first_line=""
	local second_line=""

	first_line="$(awk -v pattern="$first" 'index($0, pattern) > 0 { print NR; exit }' "$file_path")"
	second_line="$(awk -v pattern="$second" 'index($0, pattern) > 0 { print NR; exit }' "$file_path")"

	[[ -n "$first_line" ]] || fail "missing '${first}' in ${file_path}"
	[[ -n "$second_line" ]] || fail "missing '${second}' in ${file_path}"

	if ((first_line >= second_line)); then
		fail "expected '${first}' to appear before '${second}' in ${file_path}"
	fi
}

create_repo() {
	local name="$1"
	local repo_path="${temp_root}/${name}"

	mkdir -p "$repo_path"
	printf '%s\n' "$repo_path"
}

write_file() {
	local file_path="$1"
	local content="$2"

	mkdir -p "$(dirname "$file_path")"
	printf '%s' "$content" >"$file_path"
}

append_file() {
	local file_path="$1"
	local content="$2"

	printf '%s' "$content" >>"$file_path"
}

insert_line_before_marker() {
	local file_path="$1"
	local marker="$2"
	local inserted_line="$3"
	local updated_path="${file_path}.updated"

	awk -v marker="$marker" -v inserted_line="$inserted_line" '
    $0 == marker && inserted == 0 {
      print inserted_line
      print ""
      inserted = 1
    }

    {
      print
    }
  ' "$file_path" >"$updated_path"
	mv "$updated_path" "$file_path"
}

replace_exact_line() {
	local file_path="$1"
	local old_line="$2"
	local new_line="$3"
	local updated_path="${file_path}.updated"

	awk -v old_line="$old_line" -v new_line="$new_line" '
    $0 == old_line && replaced == 0 {
      print new_line
      replaced = 1
      next
    }

    {
      print
    }
  ' "$file_path" >"$updated_path"
	mv "$updated_path" "$file_path"
}

replace_markdown_value() {
	local file_path="$1"
	local label="$2"
	local replacement="$3"
	local updated_path="${file_path}.updated"

	awk -v label="$label" -v replacement="$replacement" '
    index($0, "- " label ": `") == 1 && replaced == 0 {
      print "- " label ": `" replacement "`"
      replaced = 1
      next
    }

    {
      print
    }
	' "$file_path" >"$updated_path"
	mv "$updated_path" "$file_path"
}

remove_standards_entries_from_audit() {
	local file_path="$1"
	local updated_path="${file_path}.updated"

	awk '$0 !~ /^- `standards\// { print }' "$file_path" >"$updated_path"
	mv "$updated_path" "$file_path"
}
