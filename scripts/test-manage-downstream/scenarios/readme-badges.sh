test_readme_badges_insert_after_h1_and_refresh() {
	local repo_path=""

	repo_path="$(create_repo readme-h1)"
	write_file "${repo_path}/README.md" $'# Demo App\n\nThis line should stay after the badges.\n'
	write_file "${repo_path}/package.json" $'{\n  "engines": {\n    "node": "22"\n  },\n  "devDependencies": {\n    "typescript": "5.8.4",\n    "vite": "7.2.1",\n    "solid-js": "1.8.19"\n  }\n}\n'

	run_manage "$repo_path" install
	assert_eq "$run_status" "0" "install should add README badges after the first H1"
	assert_exact_line_count "${repo_path}/README.md" "$readme_badges_begin" "1"
	assert_exact_line_count "${repo_path}/README.md" "$readme_badges_end" "1"
	assert_file_contains "${repo_path}/README.md" "Managed upstream by bright-builds-rules." "managed README badge block should direct fixes upstream"
	assert_line_order "${repo_path}/README.md" "# Demo App" "$readme_badges_begin"
	assert_line_order "${repo_path}/README.md" "$readme_badges_end" "This line should stay after the badges."
	assert_file_contains "${repo_path}/README.md" "Node.js 22" "README should include the verified Node.js badge"
	assert_file_contains "${repo_path}/README.md" "TypeScript 5.8.4" "README should include the detected TypeScript version"
	assert_file_contains "${repo_path}/README.md" "SolidJS 1.8.19" "README should include the detected framework badge"
	assert_file_contains "${repo_path}/README.md" "Vite 7.2.1" "README should include the detected Vite badge"
	assert_file_contains "${repo_path}/README.md" "Bright Builds: Rules" "README should include the flat Bright Builds badge once the block applies"
	assert_file_contains "${repo_path}/README.md" "public/badges/bright-builds-rules-flat.svg" "README should point at the flat Bright Builds badge"
	assert_line_order "${repo_path}/README.md" "Vite 7.2.1" "Bright Builds: Rules"

	write_file "${repo_path}/package.json" $'{\n  "engines": {\n    "node": "22"\n  },\n  "devDependencies": {\n    "typescript": "5.9.2",\n    "vite": "7.3.1",\n    "solid-js": "1.9.0"\n  }\n}\n'

	run_manage "$repo_path" update
	assert_eq "$run_status" "0" "update should refresh detected README badge versions"
	assert_exact_line_count "${repo_path}/README.md" "$readme_badges_begin" "1"
	assert_file_contains "${repo_path}/README.md" "TypeScript 5.9.2" "update should refresh the TypeScript badge version"
	assert_file_contains "${repo_path}/README.md" "SolidJS 1.9.0" "update should refresh the framework badge version"
	assert_file_contains "${repo_path}/README.md" "Vite 7.3.1" "update should refresh the Vite badge version"
	assert_file_contains "${repo_path}/README.md" "Bright Builds: Rules" "update should preserve the flat Bright Builds badge"
	assert_line_order "${repo_path}/README.md" "Vite 7.3.1" "Bright Builds: Rules"
	assert_file_contains "${repo_path}/README.md" "This line should stay after the badges." "update should preserve existing README content"
}

test_update_replaces_old_managed_canonical_badge_with_flat_default() {
	local repo_path=""
	local old_badge=""
	local current_badge=""

	repo_path="$(create_repo readme-managed-default-migration)"
	write_file "${repo_path}/README.md" $'# Demo App\n\nBody text remains.\n'
	write_file "${repo_path}/package.json" $'{\n  "devDependencies": {\n    "typescript": "5.9.2"\n  }\n}\n'

	run_manage "$repo_path" install
	assert_eq "$run_status" "0" "install should succeed before migrating the managed badge default"

	old_badge="$(current_bright_builds_badge canonical)"
	current_badge="$(current_bright_builds_badge flat)"
	replace_exact_line "${repo_path}/README.md" "$current_badge" "$old_badge"

	run_manage "$repo_path" status
	assert_eq "$run_status" "0" "status should still treat a repo with the old managed canonical badge as installed"
	assert_contains "$run_output" "Repo state: installed" "the old managed canonical badge should be refreshed by update rather than treated as blocked drift"

	run_manage "$repo_path" update
	assert_eq "$run_status" "0" "update should migrate the old managed canonical badge to the flat default"
	assert_file_not_contains "${repo_path}/README.md" "$old_badge" "update should remove the old managed canonical badge"
	assert_exact_line_count "${repo_path}/README.md" "$current_badge" "1"
	assert_file_contains "${repo_path}/README.md" "Body text remains." "update should preserve surrounding README content while migrating the managed badge default"
}

test_readme_badges_create_skeleton_and_uninstall_removes_it() {
	local repo_path=""

	repo_path="$(create_repo readme-skeleton)"
	write_file "${repo_path}/package.json" $'{\n  "devDependencies": {\n    "typescript": "5.9.2"\n  }\n}\n'

	run_manage "$repo_path" install
	assert_eq "$run_status" "0" "install should create a README skeleton when verified badges exist"
	assert_file_exists "${repo_path}/README.md"
	assert_file_contains "${repo_path}/README.md" "# readme-skeleton" "generated README should use the repo directory name as the title"
	assert_exact_line_count "${repo_path}/README.md" "$readme_badges_begin" "1"

	run_manage "$repo_path" uninstall
	assert_eq "$run_status" "0" "uninstall should succeed after generating a README skeleton"
	assert_file_missing "${repo_path}/README.md"
}

test_readme_badges_block_existing_top_badges_and_force_repair() {
	local repo_path=""
	local backup_file=""

	repo_path="$(create_repo readme-blocked)"
	write_file "${repo_path}/README.md" $'# Demo App\n\n[![Custom](https://img.shields.io/badge/custom-existing-blue)](https://example.com)\n\nBody text stays here.\n'
	write_file "${repo_path}/package.json" $'{\n  "devDependencies": {\n    "typescript": "5.9.2"\n  }\n}\n'

	run_manage "$repo_path" status
	assert_eq "$run_status" "0" "status should succeed when README badges are ambiguous"
	assert_contains "$run_output" "Repo state: blocked" "existing unmanaged top badges should block installation"
	assert_contains "$run_output" "README badge block: ambiguous" "status should surface the README badge conflict"
	assert_contains "$run_output" "Blocking paths: README.md" "README conflicts should be listed as blocking"

	run_manage "$repo_path" install
	assert_eq "$run_status" "1" "install should fail until the README badge conflict is explicitly forced"

	run_manage "$repo_path" install --force
	assert_eq "$run_status" "0" "force install should repair conflicting README badges"
	backup_file="$(find "${repo_path}/.bright-builds-rules-backups" -type f -name 'README.md' | head -n 1)"
	[[ -n "$backup_file" ]] || fail "expected force install to back up README.md"

	assert_exact_line_count "${repo_path}/README.md" "$readme_badges_begin" "1"
	assert_file_not_contains "${repo_path}/README.md" "custom-existing-blue" "force repair should remove unmanaged top badges from the insertion zone"
	assert_file_contains "${repo_path}/README.md" "TypeScript 5.9.2" "force repair should insert the managed README badge block"
	assert_file_contains "${repo_path}/README.md" "Body text stays here." "force repair should preserve the README body"
}

test_partial_readme_badge_block_requires_force_repair() {
	local repo_path=""

	repo_path="$(create_repo readme-partial)"
	write_file "${repo_path}/README.md" "$(printf '# Demo App\n\n%s\n[![Custom](https://img.shields.io/badge/custom-partial-blue)](https://example.com)\n\nBody text remains.\n' "$readme_badges_begin")"
	write_file "${repo_path}/package.json" $'{\n  "devDependencies": {\n    "typescript": "5.9.2"\n  }\n}\n'

	run_manage "$repo_path" status
	assert_eq "$run_status" "0" "status should succeed for a partial managed README badge block"
	assert_contains "$run_output" "Repo state: blocked" "partial README badge markers should block the repo"
	assert_contains "$run_output" "README badge block: partial" "status should mark partial README badge blocks explicitly"
	assert_contains "$run_output" "Blocking paths: README.md" "partial README badge blocks should block via README.md"

	run_manage "$repo_path" install --force
	assert_eq "$run_status" "0" "force install should repair a partial managed README badge block"
	assert_exact_line_count "${repo_path}/README.md" "$readme_badges_begin" "1"
	assert_exact_line_count "${repo_path}/README.md" "$readme_badges_end" "1"
	assert_file_contains "${repo_path}/README.md" "TypeScript 5.9.2" "force repair should replace the broken block with managed badges"
	assert_file_contains "${repo_path}/README.md" "Body text remains." "force repair should preserve non-badge README content"
}

test_readme_badges_are_removed_when_no_managed_badges_remain() {
	local repo_path=""

	repo_path="$(create_repo readme-remove)"
	write_file "${repo_path}/README.md" $'# Demo App\n\nBody text remains.\n'
	write_file "${repo_path}/package.json" $'{\n  "devDependencies": {\n    "typescript": "5.9.2"\n  }\n}\n'

	run_manage "$repo_path" install
	assert_eq "$run_status" "0" "install should add README badges before the detector input is removed"
	assert_exact_line_count "${repo_path}/README.md" "$readme_badges_begin" "1"

	rm -f "${repo_path}/package.json"

	run_manage "$repo_path" update
	assert_eq "$run_status" "0" "update should remove the managed README badge block when no managed badges remain"
	assert_file_not_contains "${repo_path}/README.md" "$readme_badges_begin" "update should remove the README badge begin marker when badges are no longer applicable"
	assert_file_contains "${repo_path}/README.md" "Body text remains." "update should keep the README body after removing managed badges"
	assert_file_not_contains "${repo_path}/bright-builds-rules.audit.md" "README.md (managed badges block)" "audit should stop tracking the README badge block once it is removed"
}

test_status_and_update_repair_legacy_bright_builds_badge_above_managed_block() {
	local repo_path=""
	local legacy_badge=""
	local current_badge=""

	repo_path="$(create_repo readme-legacy-top-zone)"
	write_file "${repo_path}/README.md" $'# Demo App\n\nBody text remains.\n'
	write_file "${repo_path}/package.json" $'{\n  "devDependencies": {\n    "typescript": "5.9.2"\n  }\n}\n'

	run_manage "$repo_path" install
	assert_eq "$run_status" "0" "install should succeed before legacy badge repair"

	legacy_badge="$(legacy_bright_builds_badge canonical)"
	current_badge="$(current_bright_builds_badge flat)"
	insert_line_before_marker "${repo_path}/README.md" "$readme_badges_begin" "$legacy_badge"

	run_manage "$repo_path" status
	assert_eq "$run_status" "0" "status should succeed when only a known legacy Bright Builds badge is above the managed block"
	assert_contains "$run_output" "Repo state: installed" "known legacy Bright Builds badges should not block installed repos"
	assert_not_contains "$run_output" "Repo state: blocked" "known legacy Bright Builds badges should be treated as repairable"

	run_manage "$repo_path" update
	assert_eq "$run_status" "0" "update should repair a known legacy Bright Builds badge above the managed block"
	assert_file_not_contains "${repo_path}/README.md" "$legacy_badge" "update should remove the legacy Bright Builds badge from the managed insertion zone"
	assert_exact_line_count "${repo_path}/README.md" "$current_badge" "1"
	assert_file_contains "${repo_path}/README.md" "Body text remains." "update should preserve README body content after removing the duplicate legacy badge"
}

test_update_normalizes_legacy_bright_builds_badges_outside_insertion_zone() {
	local repo_path=""
	local legacy_canonical=""
	local legacy_flat=""
	local legacy_dark=""
	local legacy_light=""
	local legacy_compact=""
	local current_canonical=""
	local current_flat=""
	local current_dark=""
	local current_light=""
	local current_compact=""

	repo_path="$(create_repo readme-legacy-body)"
	write_file "${repo_path}/README.md" $'# Demo App\n\nBody text remains.\n'
	write_file "${repo_path}/package.json" $'{\n  "devDependencies": {\n    "typescript": "5.9.2"\n  }\n}\n'

	run_manage "$repo_path" install
	assert_eq "$run_status" "0" "install should succeed before normalizing legacy Bright Builds badges in the README body"

	legacy_canonical="$(legacy_bright_builds_badge canonical)"
	legacy_flat="$(legacy_bright_builds_badge flat)"
	legacy_dark="$(legacy_bright_builds_badge dark)"
	legacy_light="$(legacy_bright_builds_badge light)"
	legacy_compact="$(legacy_bright_builds_badge compact)"
	current_canonical="$(current_bright_builds_badge canonical)"
	current_flat="$(current_bright_builds_badge flat)"
	current_dark="$(current_bright_builds_badge dark)"
	current_light="$(current_bright_builds_badge light)"
	current_compact="$(current_bright_builds_badge compact)"

	cat >>"${repo_path}/README.md" <<EOF

## Legacy Badges

${legacy_canonical}
${legacy_flat}
${legacy_dark}
${legacy_light}
${legacy_compact}
EOF

	run_manage "$repo_path" update
	assert_eq "$run_status" "0" "update should normalize known legacy Bright Builds badge snippets outside the managed insertion zone"
	assert_file_not_contains "${repo_path}/README.md" "$legacy_canonical" "update should replace the legacy canonical badge"
	assert_file_not_contains "${repo_path}/README.md" "$legacy_flat" "update should replace the legacy flat badge"
	assert_file_not_contains "${repo_path}/README.md" "$legacy_dark" "update should replace the legacy dark badge"
	assert_file_not_contains "${repo_path}/README.md" "$legacy_light" "update should replace the legacy light badge"
	assert_file_not_contains "${repo_path}/README.md" "$legacy_compact" "update should replace the legacy compact badge"
	assert_exact_line_count "${repo_path}/README.md" "$current_canonical" "1"
	assert_exact_line_count "${repo_path}/README.md" "$current_flat" "2"
	assert_exact_line_count "${repo_path}/README.md" "$current_dark" "1"
	assert_exact_line_count "${repo_path}/README.md" "$current_light" "1"
	assert_exact_line_count "${repo_path}/README.md" "$current_compact" "1"
}

test_update_does_not_rewrite_unknown_bright_builds_like_badges() {
	local repo_path=""
	local custom_badge=""

	repo_path="$(create_repo readme-legacy-custom-body)"
	write_file "${repo_path}/README.md" $'# Demo App\n\nBody text remains.\n'
	write_file "${repo_path}/package.json" $'{\n  "devDependencies": {\n    "typescript": "5.9.2"\n  }\n}\n'

	run_manage "$repo_path" install
	assert_eq "$run_status" "0" "install should succeed before preserving custom Bright Builds-like badge content"

	custom_badge='[![Custom Bright Builds](https://raw.githubusercontent.com/bright-builds-llc/coding-and-architecture-requirements/main/public/badges/bright-builds.svg)](https://example.com/custom)'
	cat >>"${repo_path}/README.md" <<EOF

## Custom Badge

${custom_badge}
EOF

	run_manage "$repo_path" update
	assert_eq "$run_status" "0" "update should succeed when unknown Bright Builds-like badge content is outside the insertion zone"
	assert_file_contains "${repo_path}/README.md" "$custom_badge" "update should leave unknown Bright Builds-like badge markdown unchanged"
}

test_update_removes_owner_specific_openlinks_badge_when_owner_changes() {
	local repo_path=""

	repo_path="$(create_repo peter-owner-openlinks-removed)"
	init_git_repo_with_origin "$repo_path" "git@github.com:Peter-Ryszkiewicz/peter-owner-openlinks-removed.git"
	write_file "${repo_path}/README.md" $'# Owner Change\n\nBody text remains.\n'

	run_manage "$repo_path" install
	assert_eq "$run_status" "0" "install should add the owner-specific OpenLinks badge before the owner changes"
	assert_file_contains "${repo_path}/README.md" "OpenLinks profile" "Peter-owned repos should initially receive the OpenLinks badge"

	git -C "$repo_path" remote set-url origin "git@github.com:someone-else/peter-owner-openlinks-removed.git"

	run_manage "$repo_path" update
	assert_eq "$run_status" "0" "update should succeed after the repo owner changes"
	assert_file_not_contains "${repo_path}/README.md" "OpenLinks profile" "update should remove the owner-specific OpenLinks badge when the owner no longer matches"
	assert_file_not_contains "${repo_path}/AGENTS.bright-builds.md" "openlinks-identity-presence" "update should remove owner-specific sidecar guidance when the owner no longer matches"
	assert_file_contains "${repo_path}/README.md" "GitHub Stars" "update should preserve other still-applicable managed README badges"
	assert_file_contains "${repo_path}/README.md" "Body text remains." "update should preserve the rest of the README body"
}

test_rich_readme_badge_detection() {
	local repo_path=""

	repo_path="$(create_repo readme-rich)"
	init_git_repo_with_origin "$repo_path" "git@github.com:bright-builds-llc/readme-rich.git"
	write_file "${repo_path}/README.md" $'# Rich App\n\nBody text.\n'
	write_file "${repo_path}/LICENSE" $'MIT License\n'
	write_file "${repo_path}/.github/workflows/ci.yml" $'name: CI\non: [push]\njobs:\n  build:\n    runs-on: ubuntu-latest\n    steps:\n      - uses: actions/checkout@v4\n      - uses: actions/setup-node@v4\n        with:\n          node-version: 22\n'
	write_file "${repo_path}/.github/workflows/deploy-pages.yml" $'name: Deploy Pages\non: [push]\n'
	write_file "${repo_path}/package.json" $'{\n  "engines": {\n    "node": "22"\n  },\n  "devDependencies": {\n    "typescript": "5.9.2",\n    "vite": "7.3.1",\n    "solid-js": "1.9.0"\n  }\n}\n'
	write_file "${repo_path}/rust-toolchain.toml" $'[toolchain]\nchannel = "1.84.1"\n'
	write_file "${repo_path}/pyproject.toml" $'[project]\nrequires-python = ">=3.11"\n'
	write_file "${repo_path}/go.mod" $'module example.com/rich\n\ngo 1.23.0\n'

	run_manage "$repo_path" install
	assert_eq "$run_status" "0" "install should render the verified rich README badge set"
	assert_file_contains "${repo_path}/README.md" "GitHub Stars" "README should include the GitHub stars badge when origin points to GitHub"
	assert_file_contains "${repo_path}/README.md" "style=flat-square" "README shields badges should use a consistent flat-square style for vertical alignment"
	assert_file_contains "${repo_path}/README.md" "github/actions/workflow/status" "CI and deploy badges should use shields workflow status for consistent alignment with other shields"
	assert_file_contains "${repo_path}/README.md" "CI" "README should include the CI workflow badge"
	assert_file_contains "${repo_path}/README.md" "Deploy Pages" "README should include the deploy workflow badge"
	assert_file_contains "${repo_path}/README.md" "License" "README should include the license badge"
	assert_file_contains "${repo_path}/README.md" "Node.js 22" "README should include the Node.js badge"
	assert_file_contains "${repo_path}/README.md" "TypeScript 5.9.2" "README should include the TypeScript badge"
	assert_file_contains "${repo_path}/README.md" "SolidJS 1.9.0" "README should include the framework badge"
	assert_file_contains "${repo_path}/README.md" "Vite 7.3.1" "README should include the Vite badge"
	assert_file_contains "${repo_path}/README.md" "Rust 1.84.1" "README should include the Rust badge"
	assert_file_contains "${repo_path}/README.md" "Python >=3.11" "README should include the Python badge"
	assert_file_contains "${repo_path}/README.md" "Go 1.23.0" "README should include the Go badge"
	assert_file_contains "${repo_path}/README.md" "Bright Builds: Rules" "README should include the flat Bright Builds badge"
	assert_line_order "${repo_path}/README.md" "Go 1.23.0" "Bright Builds: Rules"
	assert_file_contains "${repo_path}/bright-builds-rules.audit.md" "README.md (managed badges block)" "audit should track the managed README badge block when present"
}
