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
	*.js | *.jsx | *.ts | *.tsx)
		printf '// bright-builds-rules-managed-file: %s\n' "$relative_destination"
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
	*.js | *.jsx | *.ts | *.tsx)
		printf '// coding-and-architecture-requirements-managed-file: %s\n' "$relative_destination"
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

	grep -Fq -- "$needle" "$file_path" || fail "${message}: missing '${needle}' in ${file_path}"
}

assert_file_not_contains() {
	local file_path="$1"
	local needle="$2"
	local message="$3"

	if grep -Fq -- "$needle" "$file_path"; then
		fail "${message}: unexpectedly found '${needle}' in ${file_path}"
	fi
}

assert_auto_update_workflow_contains_repair_prompt() {
	local repo_path="$1"
	local workflow_path="${repo_path}/.github/workflows/bright-builds-auto-update.yml"

	assert_file_contains "$workflow_path" 'if: ${{ failure() }}' "auto-update workflow should print the repair prompt only on failure"
	assert_file_contains "$workflow_path" "actions/setup-python@v6" "auto-update workflow should set up Python for mdformat"
	assert_file_contains "$workflow_path" "python-version: '3.13'" "auto-update workflow should pin the Python version used for mdformat"
	assert_file_contains "$workflow_path" "mdformat==1.0.0" "auto-update workflow should install the pinned mdformat version"
	assert_file_contains "$workflow_path" "mdformat-frontmatter==2.1.2" "auto-update workflow should install the pinned frontmatter extension"
	assert_file_contains "$workflow_path" "mdformat-gfm==1.0.0" "auto-update workflow should install the pinned GFM extension"
	assert_file_contains "$workflow_path" 'BRIGHT_BUILDS_PUSH_TOKEN_CONFIGURED: ${{ secrets.BRIGHT_BUILDS_PUSH_TOKEN != '"'"''"'"' }}' "auto-update workflow should expose whether the dedicated token is configured"
	assert_file_contains "$workflow_path" "https://github.com/bright-builds-llc/bright-builds-rules" "auto-update workflow should point the repair prompt to the upstream repo"
	assert_file_contains "$workflow_path" 'Run URL: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}' "auto-update workflow should include the downstream run URL expression"
	assert_file_contains "$workflow_path" "Managed workflow: .github/workflows/bright-builds-auto-update.yml" "auto-update workflow should name the managed workflow path"
	assert_file_contains "$workflow_path" "Managed helper: scripts/bright-builds-auto-update.sh" "auto-update workflow should name the managed helper path"
	assert_file_contains "$workflow_path" "prepare a pull request against https://github.com/bright-builds-llc/bright-builds-rules" "auto-update workflow should direct upstream managed fixes to an upstream PR"
	assert_file_contains "$workflow_path" "chmod 600 /Users/peterryszkiewicz/Repos/BRIGHT_BUILDS_PUSH_TOKEN.txt" "auto-update workflow should print the exact token-file permission command"
	assert_file_contains "$workflow_path" "test -s /Users/peterryszkiewicz/Repos/BRIGHT_BUILDS_PUSH_TOKEN.txt" "auto-update workflow should print the exact non-empty token-file check"
	assert_file_contains "$workflow_path" 'gh secret set BRIGHT_BUILDS_PUSH_TOKEN -R ${{ github.repository }} < /Users/peterryszkiewicz/Repos/BRIGHT_BUILDS_PUSH_TOKEN.txt' "auto-update workflow should print the exact token repair command"
	assert_file_contains "$workflow_path" 'gh workflow run bright-builds-auto-update.yml -R ${{ github.repository }}' "auto-update workflow should print the exact workflow dispatch command"
	assert_file_contains "$workflow_path" 'gh run list -R ${{ github.repository }} --workflow bright-builds-auto-update.yml --limit 1' "auto-update workflow should print the exact run lookup command"
	assert_file_contains "$workflow_path" 'gh run watch RUN_ID -R ${{ github.repository }} --exit-status' "auto-update workflow should print the exact run watch command"
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
		"standards/core/frontend-ui.md" \
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
		"standards/core/frontend-ui.md" \
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
	mdformat \
		--check \
		--extensions gfm \
		--extensions frontmatter \
		--no-codeformatters \
		--wrap keep \
		--end-of-line lf \
		"$@" >/dev/null 2>&1 || fail "${message}: mdformat --check failed for $*"
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

create_fake_python_mdformat_bootstrap_bin() {
	local bin_dir="$1"
	local log_path="$2"

	mkdir -p "$bin_dir"
	cat >"${bin_dir}/python3" <<'PYTHON3_SH'
#!/usr/bin/env bash
set -euo pipefail

printf 'python3 %s\n' "$*" >>"${FAKE_PYTHON_BOOTSTRAP_LOG}"

if [[ "${1:-}" == "-m" && "${2:-}" == "venv" && -n "${3:-}" ]]; then
	venv_path="$3"
	mkdir -p "${venv_path}/bin"
	cat >"${venv_path}/bin/python" <<'VENV_PYTHON_SH'
#!/usr/bin/env bash
set -euo pipefail

printf 'venv-python %s\n' "$*" >>"${FAKE_PYTHON_BOOTSTRAP_LOG}"
if [[ "${1:-}" == "-m" && "${2:-}" == "pip" && "${3:-}" == "install" ]]; then
	exit 0
fi

printf 'unsupported fake venv python invocation: %s\n' "$*" >&2
exit 1
VENV_PYTHON_SH
	cat >"${venv_path}/bin/mdformat" <<'MDFORMAT_SH'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--version" ]]; then
	printf 'mdformat 1.0.0 (mdformat-gfm 1.0.0, mdformat_frontmatter 2.1.2)\n'
	exit 0
fi

for file_path in "$@"; do
	case "$file_path" in
	--*)
		continue
		;;
	esac

	[[ -f "$file_path" ]] || continue
	tmp_path="${file_path}.fake-mdformat"
	awk '
		{
			sub(/\r$/, "")
			sub(/[ \t]+$/, "")
			if ($0 == "") {
				if (previous_blank == 0) {
					print ""
					previous_blank = 1
				}
				next
			}
			print
			previous_blank = 0
		}
	' "$file_path" >"$tmp_path"
	mv "$tmp_path" "$file_path"
done
MDFORMAT_SH
	chmod +x "${venv_path}/bin/python" "${venv_path}/bin/mdformat"
	exit 0
fi

printf 'unsupported fake python invocation: %s\n' "$*" >&2
exit 1
PYTHON3_SH
	chmod +x "${bin_dir}/python3"
	FAKE_PYTHON_BOOTSTRAP_LOG="$log_path"
	export FAKE_PYTHON_BOOTSTRAP_LOG
}

create_fake_mdformat_bin() {
	local bin_dir="$1"
	local mode="$2"
	local log_path="$3"

	mkdir -p "$bin_dir"
	printf '%s\n' "$mode" >"${bin_dir}/mdformat.mode"
	printf '%s\n' "$log_path" >"${bin_dir}/mdformat.log-path"
	cat >"${bin_dir}/mdformat" <<'MDFORMAT_SH'
#!/usr/bin/env bash
set -euo pipefail

bin_dir="$(cd "$(dirname "$0")" && pwd)"
mode="$(<"${bin_dir}/mdformat.mode")"
log_path="$(<"${bin_dir}/mdformat.log-path")"
printf '%s\n' "$*" >>"$log_path"

if [[ "${1:-}" == "--version" ]]; then
	if [[ "$mode" == "wrong-version" ]]; then
		printf 'mdformat 0.7.22\n'
	else
		printf 'mdformat 1.0.0 (mdformat-gfm 1.0.0, mdformat_frontmatter 2.1.2)\n'
	fi
	exit 0
fi

if [[ "$mode" == "missing-extension" ]]; then
	printf 'UsageError: Plugin not installed: frontmatter\n' >&2
	exit 2
fi

exit 0
MDFORMAT_SH
	chmod +x "${bin_dir}/mdformat"
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

remove_audit_entry() {
	local file_path="$1"
	local relative_path="$2"
	local updated_path="${file_path}.updated"

	awk -v entry="- \`${relative_path}\`" '$0 != entry { print }' "$file_path" >"$updated_path"
	mv "$updated_path" "$file_path"
}
