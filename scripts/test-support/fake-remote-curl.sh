#!/usr/bin/env bash
set -euo pipefail

output_path=""
source_url=""
retry_count=0

while [[ "$#" -gt 0 ]]; do
	case "$1" in
	-o | --output)
		output_path="$2"
		shift 2
		;;
	--retry)
		retry_count="$2"
		shift 2
		;;
	--retry-delay | --retry-max-time)
		shift 2
		;;
	-f | -s | -S | -L | -fsSL | --fail | --silent | --show-error | --location)
		shift
		;;
	*)
		source_url="$1"
		shift
		;;
	esac
done

[[ -n "$output_path" ]] || exit 1

repo_slug="$(printf '%s' "$source_url" | sed -n 's#^https://raw\.githubusercontent\.com/\([^/]*/[^/]*\)/[^/]*/.*#\1#p')"
requested_ref="$(printf '%s' "$source_url" | sed -n 's#^https://raw\.githubusercontent\.com/[^/]*/[^/]*/\([^/]*\)/.*#\1#p')"
relative_path="$(printf '%s' "$source_url" | sed -n 's#^https://raw\.githubusercontent\.com/[^/]*/[^/]*/[^/]*/##p')"
[[ -n "$repo_slug" && -n "$requested_ref" && -n "$relative_path" ]] || exit 1

source_root=""
case "$repo_slug" in
bright-builds-llc/bright-builds-rules)
	source_root="${FAKE_CURL_CURRENT_SOURCE_ROOT}"
	;;
bright-builds-llc/coding-and-architecture-requirements)
	if [[ "$relative_path" == "scripts/manage-downstream.sh" ]]; then
		source_root="${FAKE_CURL_LEGACY_SCRIPT_SOURCE_ROOT:-${FAKE_CURL_LEGACY_SOURCE_ROOT}}"
	else
		source_root="${FAKE_CURL_LEGACY_SOURCE_ROOT}"
	fi
	;;
esac

if [[ -n "${FAKE_CURL_PRE_LOCAL_STANDARDS_REF:-}" &&
	"$requested_ref" == "${FAKE_CURL_PRE_LOCAL_STANDARDS_REF}" &&
	-n "${FAKE_CURL_PRE_LOCAL_STANDARDS_SOURCE_ROOT:-}" ]]; then
	source_root="${FAKE_CURL_PRE_LOCAL_STANDARDS_SOURCE_ROOT}"
fi

if [[ -z "$source_root" ]]; then
	printf 'curl: (22) The requested URL returned error: 404\n' >&2
	exit 22
fi

invocation_attempt=0
while [[ "$invocation_attempt" -le "$retry_count" ]]; do
	attempt=1
	if [[ -n "${FAKE_CURL_ATTEMPT_STATE_DIR:-}" ]]; then
		mkdir -p "$FAKE_CURL_ATTEMPT_STATE_DIR"
		attempt_key="$(printf '%s' "$relative_path" | tr '/.' '__')"
		attempt_path="${FAKE_CURL_ATTEMPT_STATE_DIR}/${attempt_key}"
		if [[ -f "$attempt_path" ]]; then
			attempt="$(sed -n '1p' "$attempt_path")"
			attempt="$((attempt + 1))"
		fi
		printf '%s\n' "$attempt" >"$attempt_path"
	fi

	if [[ -n "${FAKE_CURL_ATTEMPT_LOG:-}" ]]; then
		printf '%s\t%s\n' "$relative_path" "$attempt" >>"$FAKE_CURL_ATTEMPT_LOG"
	fi

	if [[ "$relative_path" != "${FAKE_CURL_FAIL_PATH:-}" ]]; then
		break
	fi

	fail_start_attempt="${FAKE_CURL_FAIL_START_ATTEMPT:-1}"
	if [[ "$attempt" -lt "$fail_start_attempt" ]]; then
		break
	fi

	fail_attempts="${FAKE_CURL_FAIL_ATTEMPTS:-always}"
	if [[ "$fail_attempts" != "always" &&
		"$attempt" -ge "$((fail_start_attempt + fail_attempts))" ]]; then
		break
	fi

	invocation_attempt="$((invocation_attempt + 1))"
	if [[ "$invocation_attempt" -gt "$retry_count" ]]; then
		printf 'curl: (22) The requested URL returned error: 503\n' >&2
		exit 22
	fi
done

empty_start_attempt="${FAKE_CURL_EMPTY_START_ATTEMPT:-1}"
if [[ "$relative_path" == "${FAKE_CURL_EMPTY_PATH:-}" &&
	"$attempt" -ge "$empty_start_attempt" ]]; then
	: >"$output_path"
	exit 0
fi

if [[ -n "${FAKE_CURL_STALE_REF:-}" &&
	"$repo_slug" == "bright-builds-llc/coding-and-architecture-requirements" &&
	"$requested_ref" == "${FAKE_CURL_STALE_REF}" ]]; then
	printf 'curl: (22) The requested URL returned error: 404\n' >&2
	exit 22
fi

if "${REAL_GIT_PATH}" -C "$source_root" rev-parse --verify "${requested_ref}^{commit}" >/dev/null 2>&1; then
	if "${REAL_GIT_PATH}" -C "$source_root" cat-file -e "${requested_ref}:${relative_path}" >/dev/null 2>&1; then
		"${REAL_GIT_PATH}" -C "$source_root" show "${requested_ref}:${relative_path}" >"$output_path"
		exit 0
	fi
fi

if [[ -f "${source_root}/${relative_path}" ]]; then
	cp "${source_root}/${relative_path}" "$output_path"
	exit 0
fi

printf 'curl: (22) The requested URL returned error: 404\n' >&2
exit 22
