strip_whole_file_managed_markers() {
	local repo_path="$1"
	local relative_destination=""
	local file_path=""
	local stripped_path=""

	for relative_destination in \
		"AGENTS.bright-builds.md" \
		"CONTRIBUTING.md" \
		".github/pull_request_template.md" \
		"bright-builds-rules.audit.md" \
		"scripts/bright-builds-auto-update.sh" \
		".github/workflows/bright-builds-auto-update.yml"; do
		file_path="${repo_path}/${relative_destination}"
		if [[ ! -f "$file_path" ]]; then
			continue
		fi

		stripped_path="${file_path}.stripped"
		awk '!/bright-builds-rules-managed-file:/' "$file_path" >"$stripped_path"
		mv "$stripped_path" "$file_path"
	done
}

render_current_whole_file_contributing_compat() {
	local output_path="$1"
	local version_pin="${2:-main}"
	local exact_commit="${3:-$repo_exact_commit}"
	local audit_path="${4:-bright-builds-rules.audit.md}"
	local template_path="${repo_root}/templates/compat/pre-contributing-block/CONTRIBUTING.md"

	sed \
		-e "s#REPLACE_WITH_MANAGED_FILE_MARKER#$(managed_file_marker "CONTRIBUTING.md" | sed 's/[&/]/\\&/g')#" \
		-e "s#REPLACE_WITH_REPO_URL#${current_bright_builds_url}#g" \
		-e "s#REPLACE_WITH_TAG_OR_COMMIT#${version_pin}#g" \
		-e "s#REPLACE_WITH_EXACT_COMMIT#${exact_commit}#g" \
		-e "s#REPLACE_WITH_TAGGED_STANDARDS_INDEX_URL#${current_bright_builds_url}/blob/${version_pin}/standards/index.md#g" \
		-e "s#REPLACE_WITH_AUDIT_MANIFEST_PATH#${audit_path}#g" \
		"$template_path" >"$output_path"
}

render_current_whole_file_audit_compat() {
	local output_path="$1"
	local version_pin="${2:-main}"
	local exact_commit="${3:-$repo_exact_commit}"
	local audit_path="${4:-bright-builds-rules.audit.md}"
	local auto_update_mode="${5:-disabled}"
	local auto_update_reason="${6:-default disabled}"
	local last_operation="${7:-install}"
	local last_updated_utc="${8:-2026-04-11T00:00:00Z}"
	local managed_files_markdown="${9:-$'- `AGENTS.md (managed block)`\n- `AGENTS.bright-builds.md`\n- `CONTRIBUTING.md`\n- `.github/pull_request_template.md`\n- `bright-builds-rules.audit.md`'}"
	local template_path="${repo_root}/templates/compat/pre-contributing-block/bright-builds-rules.audit.md"
	local managed_files_path="${output_path}.managed-files"

	sed \
		-e "s#REPLACE_WITH_MANAGED_FILE_MARKER#$(managed_file_marker "bright-builds-rules.audit.md" | sed 's/[&/]/\\&/g')#" \
		-e "s#REPLACE_WITH_REPO_URL#${current_bright_builds_url}#g" \
		-e "s#REPLACE_WITH_TAG_OR_COMMIT#${version_pin}#g" \
		-e "s#REPLACE_WITH_EXACT_COMMIT#${exact_commit}#g" \
		-e "s#REPLACE_WITH_TAGGED_STANDARDS_INDEX_URL#${current_bright_builds_url}/blob/${version_pin}/standards/index.md#g" \
		-e "s#REPLACE_WITH_MANAGED_SIDECAR_PATH#AGENTS.bright-builds.md#g" \
		-e "s#REPLACE_WITH_AUDIT_MANIFEST_PATH#${audit_path}#g" \
		-e "s#REPLACE_WITH_AUTO_UPDATE_MODE#${auto_update_mode}#g" \
		-e "s#REPLACE_WITH_AUTO_UPDATE_REASON#${auto_update_reason}#g" \
		-e "s#REPLACE_WITH_LAST_OPERATION#${last_operation}#g" \
		-e "s#REPLACE_WITH_LAST_UPDATED_UTC#${last_updated_utc}#g" \
		"$template_path" >"${output_path}.base"

	printf '%s\n' "$managed_files_markdown" >"$managed_files_path"
	awk -v replacement_path="$managed_files_path" '
    BEGIN {
      while ((getline line < replacement_path) > 0) {
        replacement[++replacement_count] = line
      }
      close(replacement_path)
    }
    $0 == "REPLACE_WITH_MANAGED_FILES_LIST" {
      for (i = 1; i <= replacement_count; i++) {
        print replacement[i]
      }
      next
    }
    { print }
  ' "${output_path}.base" >"$output_path"
	rm -f "${output_path}.base" "$managed_files_path"
}

disable_real_gh_by_default() {
	mkdir -p "$default_fake_bin"
	write_file "${default_fake_bin}/gh" $'#!/usr/bin/env bash\nexit 1\n'
	chmod +x "${default_fake_bin}/gh"
	unset GITHUB_ACTOR || true
	export PATH="${default_fake_bin}:$PATH"
}

init_git_repo_with_origin() {
	local repo_path="$1"
	local remote_url="$2"

	git -C "$repo_path" init >/dev/null 2>&1
	git -C "$repo_path" remote add origin "$remote_url"
}

run_manage() {
	local repo_path="$1"
	shift

	set +e
	run_output="$(bash "$script_path" "$@" --repo-root "$repo_path" 2>&1)"
	run_status=$?
	set -e
}

run_manage_with_script() {
	local installer_path="$1"
	local repo_path="$2"
	shift 2

	set +e
	run_output="$(bash "$installer_path" "$@" --repo-root "$repo_path" 2>&1)"
	run_status=$?
	set -e
}

run_manage_with_path_prefix() {
	local installer_path="$1"
	local repo_path="$2"
	local path_prefix="$3"
	shift 3

	set +e
	run_output="$(env PATH="${path_prefix}:$PATH" bash "$installer_path" "$@" --repo-root "$repo_path" 2>&1)"
	run_status=$?
	set -e
}

run_manage_via_stdin() {
	local installer_path="$1"
	local repo_path="$2"
	shift 2

	set +e
	run_output="$(cat "$installer_path" | bash -s -- "$@" --repo-root "$repo_path" 2>&1)"
	run_status=$?
	set -e
}

run_manage_via_stdin_with_path_prefix() {
	local installer_path="$1"
	local repo_path="$2"
	local path_prefix="$3"
	shift 3

	set +e
	run_output="$(cat "$installer_path" | env PATH="${path_prefix}:$PATH" bash -s -- "$@" --repo-root "$repo_path" 2>&1)"
	run_status=$?
	set -e
}

run_manage_with_actor() {
	local repo_path="$1"
	local actor="$2"
	shift 2

	set +e
	run_output="$(env GITHUB_ACTOR="$actor" bash "$script_path" "$@" --repo-root "$repo_path" 2>&1)"
	run_status=$?
	set -e
}

create_standalone_installer_bundle() {
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
	printf '%s\n' "${bundle_root}/scripts/manage-downstream.sh"
}

create_legacy_installer_bundle() {
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
	printf '%s\n' "${bundle_root}/scripts/manage-downstream.sh"
}

create_pre_local_standards_installer_bundle() {
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
	printf '%s\n' "${bundle_root}/scripts/manage-downstream.sh"
}

create_script_only_installer_copy() {
	local name="$1"
	local source_installer_path="$2"
	local installer_path="${temp_root}/${name}-script-only/manage-downstream.sh"

	mkdir -p "$(dirname "$installer_path")"
	cp "$source_installer_path" "$installer_path"
	chmod +x "$installer_path"
	printf '%s\n' "$installer_path"
}

create_fake_remote_fetch_bin() {
	local bin_dir="$1"
	local current_source_root="$2"
	local legacy_source_root="$3"
	local stale_ref="${4:-}"

	mkdir -p "$bin_dir"
	cp "${repo_root}/scripts/test-support/fake-remote-curl.sh" "${bin_dir}/curl"
	chmod +x "${bin_dir}/curl"
	write_file "${bin_dir}/git" $'#!/usr/bin/env bash\nset -euo pipefail\nif [[ "${1:-}" == "ls-remote" && "${2:-}" == "https://github.com/bright-builds-llc/bright-builds-rules.git" ]]; then\n  ref="${3:-}"\n  [[ -n "$ref" ]] || exit 1\n  commit="$("${REAL_GIT_PATH}" -C "${FAKE_GIT_SOURCE_ROOT}" rev-parse "${ref}^{commit}")"\n  printf "%s\\t%s\\n" "$commit" "$ref"\n  exit 0\nfi\nexec "${REAL_GIT_PATH}" "$@"\n'
	chmod +x "${bin_dir}/git"
	FAKE_CURL_CURRENT_SOURCE_ROOT="$current_source_root"
	FAKE_CURL_LEGACY_SOURCE_ROOT="$legacy_source_root"
	FAKE_CURL_LEGACY_SCRIPT_SOURCE_ROOT="$current_source_root"
	FAKE_CURL_STALE_REF="$stale_ref"
	FAKE_CURL_PRE_LOCAL_STANDARDS_REF=""
	FAKE_CURL_PRE_LOCAL_STANDARDS_SOURCE_ROOT=""
	FAKE_CURL_FAIL_PATH=""
	FAKE_CURL_FAIL_START_ATTEMPT=""
	FAKE_CURL_FAIL_ATTEMPTS=""
	FAKE_CURL_EMPTY_PATH=""
	FAKE_CURL_EMPTY_START_ATTEMPT=""
	FAKE_CURL_ATTEMPT_STATE_DIR="${bin_dir}/curl-attempts"
	FAKE_CURL_ATTEMPT_LOG="${bin_dir}/curl-attempts.log"
	FAKE_GIT_SOURCE_ROOT="$current_source_root"
	REAL_GIT_PATH="$real_git_path"
	export FAKE_CURL_CURRENT_SOURCE_ROOT
	export FAKE_CURL_LEGACY_SOURCE_ROOT
	export FAKE_CURL_LEGACY_SCRIPT_SOURCE_ROOT
	export FAKE_CURL_STALE_REF
	export FAKE_CURL_PRE_LOCAL_STANDARDS_REF
	export FAKE_CURL_PRE_LOCAL_STANDARDS_SOURCE_ROOT
	export FAKE_CURL_FAIL_PATH
	export FAKE_CURL_FAIL_START_ATTEMPT
	export FAKE_CURL_FAIL_ATTEMPTS
	export FAKE_CURL_EMPTY_PATH
	export FAKE_CURL_EMPTY_START_ATTEMPT
	export FAKE_CURL_ATTEMPT_STATE_DIR
	export FAKE_CURL_ATTEMPT_LOG
	export FAKE_GIT_SOURCE_ROOT
	export REAL_GIT_PATH
}
