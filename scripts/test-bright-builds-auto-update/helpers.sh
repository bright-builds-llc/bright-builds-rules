cleanup() {
	rm -rf "$temp_root"
}

fail() {
	printf 'error: %s\n' "$*" >&2
	exit 1
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

write_markdown_dialect_fixture() {
	local repo_path="$1"

	write_file "${repo_path}/.mdformat.toml" $'wrap = "keep"\nnumber = false\nend_of_line = "lf"\nvalidate = true\nextensions = ["gfm", "frontmatter"]\n'
	write_file "${repo_path}/docs/PLAN.md" $'---\ntitle: GSD compatibility fixture\nphase: 7\n---\n\n# Plan\n\n| Contract | Value |\n| --- | --- |\n| Marker | canonical and legacy |\n\n<execution-context>\nCanonical wrapper.\n</execution-context>\n\n<execution_context>\nLegacy wrapper remains repository-owned content.\n</execution_context>\n'
}

assert_markdown_dialect_fixture_hashes() {
	local repo_path="$1"
	local expected_config_hash="$2"
	local expected_document_hash="$3"

	assert_eq "$(git -C "$repo_path" hash-object .mdformat.toml)" "$expected_config_hash" "auto-update should preserve downstream .mdformat.toml bytes"
	assert_eq "$(git -C "$repo_path" hash-object docs/PLAN.md)" "$expected_document_hash" "auto-update should preserve arbitrary downstream Markdown bytes"
}

assert_ref_exists() {
	local git_dir="$1"
	local ref_name="$2"

	git --git-dir="$git_dir" show-ref --verify --quiet "$ref_name" || fail "expected ref to exist: ${ref_name}"
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

path_without_command_dir() {
	local command_name="$1"
	local entry=""
	local result=""

	while IFS= read -r entry; do
		[[ -n "$entry" ]] || continue
		[[ -x "${entry}/${command_name}" ]] && continue
		result="${result:+${result}:}${entry}"
	done < <(printf '%s' "$PATH" | tr ':' '\n')

	printf '%s\n' "$result"
}
