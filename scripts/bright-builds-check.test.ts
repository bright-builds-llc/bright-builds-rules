import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import fs from "node:fs";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import { countPhysicalLines } from "../templates/bright-builds-check.js";

const checkerPath = path.resolve("templates/bright-builds-check.ts");

const writeFile = (rootDir: string, relativePath: string, contents: string | Buffer): void => {
  const absolutePath = path.join(rootDir, relativePath);
  fs.mkdirSync(path.dirname(absolutePath), { recursive: true });
  fs.writeFileSync(absolutePath, contents);
};

const createFixture = (): string => {
  const rootDir = mkdtempSync(path.join(tmpdir(), "bright-builds-check-"));
  execFileSync("git", ["init", "-q", rootDir]);
  return rootDir;
};

const stageFixture = (rootDir: string): void => {
  execFileSync("git", ["-C", rootDir, "add", "."]);
};

const runChecker = (
  rootDir: string,
  maybeCommand?: string,
): { status: number | null; stderr: string; stdout: string } => {
  const args = [checkerPath];
  if (maybeCommand) {
    args.push(maybeCommand);
  }
  const result = spawnSync("bun", args, {
    cwd: rootDir,
    encoding: "utf8",
  });
  return {
    status: result.status,
    stderr: result.stderr,
    stdout: result.stdout,
  };
};

test("countPhysicalLines handles empty, LF, CRLF, and unterminated content", () => {
  // Arrange
  const contents = [
    Buffer.from(""),
    Buffer.from("one\n"),
    Buffer.from("one\r\ntwo\r\n"),
    Buffer.from("one\ntwo"),
  ];

  // Act
  const lineCounts = contents.map(countPhysicalLines);

  // Assert
  assert.deepEqual(lineCounts, [0, 1, 2, 2]);
});

test("file-lengths permits 628 lines and fails at 629", () => {
  // Arrange
  const rootDir = createFixture();
  writeFile(rootDir, "src/allowed.ts", "line\n".repeat(628));
  writeFile(rootDir, "src/oversized.rs", "line\n".repeat(629));
  stageFixture(rootDir);

  // Act
  const result = runChecker(rootDir, "file-lengths");

  // Assert
  assert.equal(result.status, 1);
  assert.match(result.stdout, /FAIL file-lengths src\/oversized\.rs: 629/u);
  assert.doesNotMatch(result.stdout, /allowed\.ts/u);
});

test("file-lengths ignores non-source files and conventional excluded directories", () => {
  // Arrange
  const rootDir = createFixture();
  const oversized = "line\n".repeat(629);
  writeFile(rootDir, "README.md", oversized);
  for (const excludedDir of [
    ".next",
    ".nuxt",
    ".output",
    "build",
    "coverage",
    "dist",
    "node_modules",
    "target",
    "third_party",
    "vendor",
  ]) {
    writeFile(rootDir, `${excludedDir}/library.ts`, oversized);
  }
  writeFile(rootDir, "src/app.ts", "export {};\n");
  stageFixture(rootDir);

  // Act
  const result = runChecker(rootDir, "file-lengths");

  // Assert
  assert.equal(result.status, 0);
  assert.match(result.stdout, /scanned=1/u);
});

test("file-lengths includes UI, query, and schema source extensions", () => {
  // Arrange
  const rootDir = createFixture();
  const oversized = "line\n".repeat(629);
  writeFile(rootDir, "src/component.vue", oversized);
  writeFile(rootDir, "src/query.graphql", oversized);
  writeFile(rootDir, "src/schema.prisma", oversized);
  stageFixture(rootDir);

  // Act
  const result = runChecker(rootDir, "file-lengths");

  // Assert
  assert.equal(result.status, 1);
  assert.match(result.stdout, /src\/component\.vue/u);
  assert.match(result.stdout, /src\/query\.graphql/u);
  assert.match(result.stdout, /src\/schema\.prisma/u);
  assert.match(result.stdout, /scanned=3/u);
});

test("a reasoned exact-path exception suppresses a file-length finding", () => {
  // Arrange
  const rootDir = createFixture();
  writeFile(rootDir, "src/generated.ts", "line\n".repeat(629));
  writeFile(
    rootDir,
    ".bright-builds-rules-checks.tsv",
    "file-lengths\tsrc/generated.ts\tGenerated protocol registry\n",
  );
  stageFixture(rootDir);

  // Act
  const result = runChecker(rootDir);

  // Assert
  assert.equal(result.status, 0);
  assert.match(result.stdout, /EXCEPTION file-lengths src\/generated\.ts/u);
});

const invalidAllowlistCases = [
  ["malformed", "file-lengths\tsrc/app.ts\n", /exactly three/u],
  ["unknown ID", "other\tsrc/app.ts\tUnknown check\n", /unknown check ID/u],
  ["missing reason", "file-lengths\tsrc/app.ts\t \n", /non-empty reason/u],
  [
    "duplicate",
    "file-lengths\tsrc/app.ts\tFirst\nfile-lengths\tsrc/app.ts\tSecond\n",
    /duplicates/u,
  ],
  ["unsafe", "file-lengths\t../app.ts\tUnsafe\n", /normalized repo-relative/u],
  ["stale", "file-lengths\tsrc/missing.ts\tGone\n", /stale path/u],
] as const;

for (const [name, allowlist, expectedError] of invalidAllowlistCases) {
  test(`allowlist validation rejects the ${name} case`, () => {
    // Arrange
    const rootDir = createFixture();
    writeFile(rootDir, "src/app.ts", "export {};\n");
    writeFile(rootDir, ".bright-builds-rules-checks.tsv", allowlist);
    stageFixture(rootDir);

    // Act
    const result = runChecker(rootDir);

    // Assert
    assert.equal(result.status, 2);
    assert.match(result.stderr, expectedError);
  });
}

test("lessons accepts bullet and numbered field styles across both active sources", () => {
  // Arrange
  const rootDir = createFixture();
  writeFile(
    rootDir,
    "tasks/lessons.md",
    `# Lessons

## lesson-bullet-style | 2026-07-26 21:00 CDT

- Date: 2026-07-26
- What went wrong: A problem happened.
- Preventive rule: Prevent it.
- Trigger signal: A signal appears.
`,
  );
  writeFile(
    rootDir,
    ".codex/tasks/lessons.md",
    `# Lessons

## lesson-numbered-style | 2026-07-26

1. Date: 2026-07-26
2. What went wrong: Another problem happened.
3. Preventive rule: Prevent that too.
4. Trigger signal to catch it earlier: Another signal appears.
`,
  );
  stageFixture(rootDir);

  // Act
  const result = runChecker(rootDir, "lessons");

  // Assert
  assert.equal(result.status, 0);
  assert.match(result.stdout, /sources=2 lessons=2/u);
  const tasksBytes = fs.statSync(path.join(rootDir, "tasks/lessons.md")).size;
  const codexBytes = fs.statSync(path.join(rootDir, ".codex/tasks/lessons.md")).size;
  const expectedTokens = Math.ceil(tasksBytes / 3) + Math.ceil(codexBytes / 3);
  assert.match(
    result.stdout,
    new RegExp(`bytes=${tasksBytes + codexBytes} estimated_tokens=${expectedTokens}`, "u"),
  );
});

test("lessons fails malformed blocks and duplicate IDs", () => {
  // Arrange
  const rootDir = createFixture();
  const duplicateBlock = `## lesson-duplicate | 2026-07-26

- Date: 2026-07-26
- Date:
- What went wrong: A problem happened.
- Preventive rule: Prevent it.
`;
  writeFile(rootDir, "tasks/lessons.md", `# Lessons\n\n${duplicateBlock}`);
  writeFile(rootDir, ".codex/tasks/lessons.md", `# Lessons\n\n${duplicateBlock}`);
  stageFixture(rootDir);

  // Act
  const result = runChecker(rootDir, "lessons");

  // Assert
  assert.equal(result.status, 1);
  assert.match(result.stdout, /must contain exactly one Date field; found 2/u);
  assert.match(result.stdout, /has an empty Date field/u);
  assert.match(result.stdout, /must contain exactly one Trigger signal/u);
  assert.match(result.stdout, /duplicate lesson-duplicate/u);
});

test("lesson 75 percent budget notices do not fail a structurally valid ledger", () => {
  // Arrange
  const rootDir = createFixture();
  const largeValue = "x".repeat(18_100);
  writeFile(
    rootDir,
    ".codex/tasks/lessons.md",
    `# Lessons

## lesson-near-budget | 2026-07-26

- Date: 2026-07-26
- What went wrong: ${largeValue}
- Preventive rule: Prevent it.
- Trigger signal: A signal appears.
`,
  );
  stageFixture(rootDir);

  // Act
  const result = runChecker(rootDir, "lessons");

  // Assert
  assert.equal(result.status, 0);
  assert.match(result.stdout, /NOTICE lessons active set is at least 75%/u);
  assert.doesNotMatch(result.stdout, /exceeds the startup budget/u);
});

test("lesson budget notices do not fail a structurally valid ledger", () => {
  // Arrange
  const rootDir = createFixture();
  const largeValue = "x".repeat(24_100);
  writeFile(
    rootDir,
    ".codex/tasks/lessons.md",
    `# Lessons

## lesson-large-ledger | 2026-07-26

- Date: 2026-07-26
- What went wrong: ${largeValue}
- Preventive rule: Prevent it.
- Trigger signal: A signal appears.
`,
  );
  stageFixture(rootDir);

  // Act
  const result = runChecker(rootDir, "lessons");

  // Assert
  assert.equal(result.status, 0);
  assert.match(result.stdout, /NOTICE lessons active set exceeds the startup budget/u);
});

test("lessons can be excepted without hiding its byte and token budget", () => {
  // Arrange
  const rootDir = createFixture();
  writeFile(rootDir, "tasks/lessons.md", "## not-a-stable-lesson\n");
  writeFile(
    rootDir,
    ".bright-builds-rules-checks.tsv",
    "lessons\ttasks/lessons.md\tLegacy ledger migration pending\n",
  );
  stageFixture(rootDir);

  // Act
  const result = runChecker(rootDir, "lessons");

  // Assert
  assert.equal(result.status, 0);
  assert.match(result.stdout, /EXCEPTION lessons tasks\/lessons\.md/u);
  assert.match(result.stdout, /bytes=23 estimated_tokens=8/u);
});

test("CLI help succeeds outside Git and invalid usage exits two", () => {
  // Arrange
  const rootDir = mkdtempSync(path.join(tmpdir(), "bright-builds-check-help-"));

  // Act
  const helpResult = runChecker(rootDir, "--help");
  const invalidResult = runChecker(rootDir, "unknown");
  const noGitResult = runChecker(rootDir);

  // Assert
  assert.equal(helpResult.status, 0);
  assert.match(helpResult.stdout, /Usage:/u);
  assert.match(helpResult.stdout, /Excluded path segments:.*node_modules/u);
  assert.match(helpResult.stdout, /check-id<TAB>repo-relative-exact-path<TAB>required reason/u);
  assert.equal(invalidResult.status, 2);
  assert.match(invalidResult.stderr, /unknown command/u);
  assert.equal(noGitResult.status, 2);
  assert.match(noGitResult.stderr, /Git repository root could not be resolved/u);
});
