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

legacy_bright_builds_canonical_badge() {
	printf '[![Bright Builds Requirements](%s/public/badges/bright-builds.svg)](%s)\n' "$legacy_bright_builds_raw_base_url" "$legacy_bright_builds_url"
}

current_bright_builds_canonical_badge() {
	printf '[![Bright Builds Rules](%s/public/badges/bright-builds-rules.svg)](%s)\n' "$current_bright_builds_raw_base_url" "$current_bright_builds_url"
}

current_bright_builds_flat_badge() {
	printf '[![Bright Builds: Rules](%s/public/badges/bright-builds-rules-flat.svg)](%s)\n' "$current_bright_builds_raw_base_url" "$current_bright_builds_url"
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

write_legacy_checker_notice_literals() {
	local checker_path="$1"
	local updated_path="${checker_path}.updated"

	awk '
    $0 == "      \"NOTICE lessons active set exceeds the startup budget; use bounded whole-block loading and audit the ledger when required\"," {
      print "      `NOTICE lessons active set exceeds the startup budget; use bounded whole-block loading and audit the ledger when required`,"
      next
    }

    $0 == "      \"NOTICE lessons active set is at least 75% of the startup budget; check whether the first-crossing audit trigger applies\"," {
      print "      `NOTICE lessons active set is at least 75% of the startup budget; check whether the first-crossing audit trigger applies`,"
      next
    }

    {
      print
    }
  ' "$checker_path" >"$updated_path"
	mv "$updated_path" "$checker_path"
}

create_source_bundle() {
	local name="$1"
	local bundle_root="${temp_root}/${name}-bundle"

	mkdir -p "${bundle_root}/scripts" "${bundle_root}/templates" "${bundle_root}/standards"
	cp "$script_path" "${bundle_root}/scripts/manage-downstream.sh"
	cp -R "${repo_root}/scripts/manage-downstream" "${bundle_root}/scripts/manage-downstream"
	cp -R "${repo_root}/templates/." "${bundle_root}/templates/"
	cp -R "${repo_root}/standards/." "${bundle_root}/standards/"
	git -C "$bundle_root" init -b main >/dev/null 2>&1
	git -C "$bundle_root" config user.name "Bundle User"
	git -C "$bundle_root" config user.email "bundle@example.com"
	git -C "$bundle_root" add -A
	git -C "$bundle_root" commit -m "Initial bundle" >/dev/null
	printf '%s\n' "$bundle_root"
}

create_legacy_source_bundle() {
	local name="$1"
	local bundle_root="${temp_root}/${name}-legacy-bundle"
	local path=""

	mkdir -p "${bundle_root}/scripts" "${bundle_root}/templates"
	for path in \
		"scripts/manage-downstream.sh" \
		"templates/AGENTS.md" \
		"templates/AGENTS.bright-builds.md" \
		"templates/CONTRIBUTING.md" \
		"templates/pull_request_template.md" \
		"templates/coding-and-architecture-requirements.audit.md" \
		"templates/standards-overrides.md" \
		"templates/bright-builds-auto-update.sh" \
		"templates/bright-builds-auto-update.yml"; do
		mkdir -p "${bundle_root}/$(dirname "$path")"
		git -C "${repo_root}" show "${legacy_repo_ref}:${path}" >"${bundle_root}/${path}"
	done
	chmod +x "${bundle_root}/scripts/manage-downstream.sh"
	printf '%s\n' "$bundle_root"
}

create_pre_local_standards_source_bundle() {
	local name="$1"
	local bundle_root="${temp_root}/${name}-pre-local-standards-bundle"

	mkdir -p "$bundle_root"
	git -C "$repo_root" archive "$pre_local_standards_ref" \
		scripts/manage-downstream.sh \
		templates \
		standards | tar -x -C "$bundle_root"

	chmod +x "${bundle_root}/scripts/manage-downstream.sh"
	git -C "$bundle_root" init -b main >/dev/null 2>&1
	git -C "$bundle_root" config user.name "Bundle User"
	git -C "$bundle_root" config user.email "bundle@example.com"
	git -C "$bundle_root" add -A
	git -C "$bundle_root" commit -m "Pre-local-standards bundle" >/dev/null
	printf '%s\n' "$bundle_root"
}

create_pre_directory_exception_source_bundle() {
	local name="$1"
	local bundle_root="${temp_root}/${name}-pre-directory-exception-bundle"

	mkdir -p "$bundle_root"
	git -C "$repo_root" archive "$pre_directory_exception_ref" \
		scripts/manage-downstream.sh \
		scripts/manage-downstream \
		templates \
		standards | tar -x -C "$bundle_root"

	chmod +x "${bundle_root}/scripts/manage-downstream.sh"
	git -C "$bundle_root" init -b main >/dev/null 2>&1
	git -C "$bundle_root" config user.name "Bundle User"
	git -C "$bundle_root" config user.email "bundle@example.com"
	git -C "$bundle_root" add -A
	git -C "$bundle_root" commit -m "Pre-directory-exception bundle" >/dev/null
	printf '%s\n' "$bundle_root"
}

init_git_repo() {
	local repo_path="$1"

	git -C "$repo_path" init -b main >/dev/null 2>&1
	git -C "$repo_path" config user.name "Test User"
	git -C "$repo_path" config user.email "test@example.com"
}

create_bare_remote() {
	local name="$1"
	local remote_path="${temp_root}/${name}.git"

	git init --bare "$remote_path" >/dev/null 2>&1
	printf '%s\n' "$remote_path"
}

commit_all() {
	local repo_path="$1"
	local message="$2"

	git -C "$repo_path" add -A
	git -C "$repo_path" commit -m "$message" >/dev/null
}

install_auto_update_repo() {
	local bundle_root="$1"
	local repo_path="$2"

	bash "${bundle_root}/scripts/manage-downstream.sh" install --auto-update enabled --ref main --repo-root "$repo_path" >/dev/null
}

run_auto_update() {
	local repo_path="$1"
	local path_prefix="$2"
	local token_state="${3:-true}"

	set +e
	if [[ "$token_state" == "legacy-unset" ]]; then
		run_output="$(env -u BRIGHT_BUILDS_PUSH_TOKEN_CONFIGURED \
			GITHUB_ACTIONS=true \
			GITHUB_REPOSITORY=bright-builds-llc/test-repo \
			PATH="${path_prefix}:$PATH" \
			bash "${repo_path}/scripts/bright-builds-auto-update.sh" 2>&1)"
	else
		run_output="$(env \
			BRIGHT_BUILDS_PUSH_TOKEN_CONFIGURED="$token_state" \
			GITHUB_ACTIONS=true \
			GITHUB_REPOSITORY=bright-builds-llc/test-repo \
			PATH="${path_prefix}:$PATH" \
			bash "${repo_path}/scripts/bright-builds-auto-update.sh" 2>&1)"
	fi
	run_status=$?
	set -e
}

create_fake_curl_bin() {
	local bin_dir="$1"
	local current_source_root="$2"
	local legacy_source_root="${3:-$current_source_root}"
	local legacy_script_source_root="${4:-$current_source_root}"
	local stale_ref="${5:-}"
	local pre_local_standards_source_root="${6:-}"
	local historical_ref="${7:-}"
	local historical_source_root="${8:-}"

	mkdir -p "$bin_dir"
	cp "${repo_root}/scripts/test-support/fake-remote-curl.sh" "${bin_dir}/curl"
	chmod +x "${bin_dir}/curl"
	write_file "${bin_dir}/git" $'#!/usr/bin/env bash\nset -euo pipefail\nif [[ "${1:-}" == "ls-remote" && "${2:-}" == "https://github.com/bright-builds-llc/bright-builds-rules.git" ]]; then\n  ref="${3:-}"\n  [[ -n "$ref" ]] || exit 1\n  commit="$("${REAL_GIT_PATH}" -C "${FAKE_GIT_SOURCE_ROOT}" rev-parse "${ref}^{commit}")"\n  printf "%s\\t%s\\n" "$commit" "$ref"\n  exit 0\nfi\nif [[ "${1:-}" == "push" && -n "${FAKE_GIT_PUSH_LOG:-}" ]]; then\n  printf "%s\\n" "$*" >> "${FAKE_GIT_PUSH_LOG}"\nfi\nexec "${REAL_GIT_PATH}" "$@"\n'
	chmod +x "${bin_dir}/git"
	FAKE_CURL_CURRENT_SOURCE_ROOT="$current_source_root"
	FAKE_CURL_LEGACY_SOURCE_ROOT="$legacy_source_root"
	FAKE_CURL_LEGACY_SCRIPT_SOURCE_ROOT="$legacy_script_source_root"
	FAKE_CURL_STALE_REF="$stale_ref"
	FAKE_CURL_PRE_LOCAL_STANDARDS_REF="$pre_local_standards_ref"
	FAKE_CURL_PRE_LOCAL_STANDARDS_SOURCE_ROOT="$pre_local_standards_source_root"
	FAKE_CURL_HISTORICAL_REF="$historical_ref"
	FAKE_CURL_HISTORICAL_SOURCE_ROOT="$historical_source_root"
	FAKE_CURL_FAIL_PATH=""
	FAKE_CURL_FAIL_START_ATTEMPT=""
	FAKE_CURL_FAIL_ATTEMPTS=""
	FAKE_CURL_EMPTY_PATH=""
	FAKE_CURL_EMPTY_START_ATTEMPT=""
	FAKE_CURL_ATTEMPT_STATE_DIR="${bin_dir}/curl-attempts"
	FAKE_CURL_ATTEMPT_LOG="${bin_dir}/curl-attempts.log"
	FAKE_GIT_SOURCE_ROOT="$current_source_root"
	FAKE_GIT_PUSH_LOG=""
	REAL_GIT_PATH="$real_git_path"
	export FAKE_CURL_CURRENT_SOURCE_ROOT
	export FAKE_CURL_LEGACY_SOURCE_ROOT
	export FAKE_CURL_LEGACY_SCRIPT_SOURCE_ROOT
	export FAKE_CURL_STALE_REF
	export FAKE_CURL_PRE_LOCAL_STANDARDS_REF
	export FAKE_CURL_PRE_LOCAL_STANDARDS_SOURCE_ROOT
	export FAKE_CURL_HISTORICAL_REF
	export FAKE_CURL_HISTORICAL_SOURCE_ROOT
	export FAKE_CURL_FAIL_PATH
	export FAKE_CURL_FAIL_START_ATTEMPT
	export FAKE_CURL_FAIL_ATTEMPTS
	export FAKE_CURL_EMPTY_PATH
	export FAKE_CURL_EMPTY_START_ATTEMPT
	export FAKE_CURL_ATTEMPT_STATE_DIR
	export FAKE_CURL_ATTEMPT_LOG
	export FAKE_GIT_SOURCE_ROOT
	export FAKE_GIT_PUSH_LOG
	export REAL_GIT_PATH
}

create_fake_git_bin() {
	local bin_dir="$1"
	local log_path="$2"
	local failure_mode="${3:-direct-rejection}"

	mkdir -p "$bin_dir"
	write_file "${bin_dir}/git" $'#!/usr/bin/env bash\nset -euo pipefail\nif [[ "${1:-}" == "ls-remote" && "${2:-}" == "https://github.com/bright-builds-llc/bright-builds-rules.git" ]]; then\n  ref="${3:-}"\n  [[ -n "$ref" ]] || exit 1\n  commit="$("${REAL_GIT_PATH}" -C "${FAKE_GIT_SOURCE_ROOT}" rev-parse "${ref}^{commit}")"\n  printf "%s\\t%s\\n" "$commit" "$ref"\n  exit 0\nfi\nif [[ "${1:-}" == "push" && "${2:-}" == "origin" && "${3:-}" == "HEAD:main" ]]; then\n  printf "rejected direct push\\n" >> "${FAKE_GIT_LOG}"\n  exit 1\nfi\nexec "${REAL_GIT_PATH}" "$@"\n'
	if [[ "$failure_mode" == "workflow-permission" ]]; then
		write_file "${bin_dir}/git" $'#!/usr/bin/env bash\nset -euo pipefail\nif [[ "${1:-}" == "ls-remote" && "${2:-}" == "https://github.com/bright-builds-llc/bright-builds-rules.git" ]]; then\n  ref="${3:-}"\n  [[ -n "$ref" ]] || exit 1\n  commit="$("${REAL_GIT_PATH}" -C "${FAKE_GIT_SOURCE_ROOT}" rev-parse "${ref}^{commit}")"\n  printf "%s\\t%s\\n" "$commit" "$ref"\n  exit 0\nfi\nif [[ "${1:-}" == "push" && "${2:-}" == "origin" && "${3:-}" == "HEAD:main" ]]; then\n  printf "workflow-permission direct push\\n" >> "${FAKE_GIT_LOG}"\n  printf "remote: refusing to allow a GitHub App to create or update workflow .github/workflows/bright-builds-auto-update.yml without workflows permission\\n" >&2\n  exit 1\nfi\nif [[ "${1:-}" == "push" ]]; then\n  printf "unexpected fallback push\\n" >> "${FAKE_GIT_LOG}"\nfi\nexec "${REAL_GIT_PATH}" "$@"\n'
	fi
	chmod +x "${bin_dir}/git"
	REAL_GIT_PATH="$real_git_path"
	FAKE_GIT_LOG="$log_path"
	export REAL_GIT_PATH
	export FAKE_GIT_LOG
}

create_fake_gh_bin() {
	local bin_dir="$1"
	local log_path="$2"

	mkdir -p "$bin_dir"
	write_file "${bin_dir}/gh" $'#!/usr/bin/env bash\nset -euo pipefail\nprintf "%s\\n" "$*" >> "${FAKE_GH_LOG}"\ncase "${1:-}" in\n  pr)\n    case "${2:-}" in\n      list)\n        printf "[]"\n        ;;\n      create)\n        ;;\n      *)\n        exit 1\n        ;;\n    esac\n    ;;\n  repo)\n    if [[ "${2:-}" == "view" ]]; then\n      printf "main\\n"\n    else\n      exit 1\n    fi\n    ;;\n  *)\n    exit 1\n    ;;\nesac\n'
	chmod +x "${bin_dir}/gh"
	FAKE_GH_LOG="$log_path"
	export FAKE_GH_LOG
}
