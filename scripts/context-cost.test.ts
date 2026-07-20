import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import {
  ADOPTION_GUIDE_PATH,
  checkContextCost,
  estimateTokens,
  HISTORY_PATH,
  measureContextCost,
  parseHistory,
  README_BLOCK_BEGIN,
  README_BLOCK_END,
  README_PATH,
  SKILL_PATH,
  updateContextCost,
} from "./context-cost.js";
import { installGitHooks } from "./git-hooks.js";

const sourceRoot = process.cwd();

const runGit = (rootDir: string, args: string[]): string =>
  execFileSync("git", ["-C", rootDir, ...args], { encoding: "utf8" }).trim();

const writeFile = (rootDir: string, relativePath: string, contents: string): void => {
  const absolutePath = path.join(rootDir, relativePath);
  fs.mkdirSync(path.dirname(absolutePath), { recursive: true });
  fs.writeFileSync(absolutePath, contents, "utf8");
};

const createFixture = (): string => {
  const rootDir = mkdtempSync(path.join(tmpdir(), "bright-builds-context-cost-"));
  writeFile(rootDir, SKILL_PATH, "skill alpha\n");
  writeFile(rootDir, ADOPTION_GUIDE_PATH, "adoption guide\n");
  writeFile(
    rootDir,
    README_PATH,
    "# Fixture\n\nIntroductory text.\n\n## For AI Agents\n\nAgent instructions.\n",
  );
  runGit(rootDir, ["init", "-q"]);
  runGit(rootDir, ["config", "user.name", "Context Cost Test"]);
  runGit(rootDir, ["config", "user.email", "context-cost@example.com"]);
  runGit(rootDir, ["add", "."]);
  runGit(rootDir, ["commit", "-qm", "initial fixture"]);
  return rootDir;
};

const generateAndCommitSnapshot = (rootDir: string): string => {
  updateContextCost({ now: new Date("2026-07-19T20:00:00.000Z"), rootDir });
  runGit(rootDir, ["add", "."]);
  runGit(rootDir, ["commit", "-qm", "record context cost"]);
  return runGit(rootDir, ["rev-parse", "HEAD"]);
};

const prepareHookFixture = (): string => {
  const rootDir = createFixture();
  writeFile(
    rootDir,
    "package.json",
    `${JSON.stringify(
      {
        name: "context-cost-hook-fixture",
        private: true,
        scripts: {
          "context-cost:precommit": "bun scripts/manage-context-cost.ts precommit",
        },
        type: "module",
      },
      null,
      2,
    )}\n`,
  );
  for (const relativePath of [
    "scripts/context-cost-history.ts",
    "scripts/context-cost.ts",
    "scripts/manage-context-cost.ts",
    ".githooks/pre-commit",
  ]) {
    const destination = path.join(rootDir, relativePath);
    fs.mkdirSync(path.dirname(destination), { recursive: true });
    fs.copyFileSync(path.join(sourceRoot, relativePath), destination);
  }
  fs.chmodSync(path.join(rootDir, ".githooks/pre-commit"), 0o755);
  runGit(rootDir, ["add", "."]);
  runGit(rootDir, ["commit", "-qm", "add hook fixture"]);
  execFileSync(path.join(rootDir, ".githooks/pre-commit"), { cwd: rootDir });
  runGit(rootDir, ["commit", "-qm", "record hook baseline"]);
  return rootDir;
};

test("estimateTokens conservatively rounds UTF-8 byte counts per file", () => {
  // Arrange
  const emptyByteCount = Buffer.byteLength("", "utf8");
  const asciiByteCount = Buffer.byteLength("abcd", "utf8");
  const multibyteCount = Buffer.byteLength("🛠️", "utf8");

  // Act
  const estimates = [
    estimateTokens(emptyByteCount),
    estimateTokens(asciiByteCount),
    estimateTokens(multibyteCount),
  ];

  // Assert
  assert.deepEqual(estimates, [0, 2, Math.ceil(multibyteCount / 3)]);
});

test("measureContextCost sums per-file estimates for the adoption path", () => {
  // Arrange
  const rootDir = createFixture();
  writeFile(rootDir, SKILL_PATH, "🛠️");
  writeFile(rootDir, ADOPTION_GUIDE_PATH, "abcde");

  // Act
  const measurement = measureContextCost(rootDir);

  // Assert
  assert.equal(measurement.skillBytes, Buffer.byteLength("🛠️", "utf8"));
  assert.equal(measurement.adoptionGuideBytes, 5);
  assert.equal(
    measurement.adoptionPathEstimatedTokens,
    estimateTokens(measurement.skillBytes) + estimateTokens(measurement.adoptionGuideBytes),
  );
});

test("updateContextCost does not duplicate an unchanged snapshot", () => {
  // Arrange
  const rootDir = createFixture();
  updateContextCost({ now: new Date("2026-07-19T20:00:00.000Z"), rootDir });
  const firstHistory = fs.readFileSync(path.join(rootDir, HISTORY_PATH), "utf8");

  // Act
  const result = updateContextCost({
    now: new Date("2026-07-19T21:00:00.000Z"),
    rootDir,
  });
  const secondHistory = fs.readFileSync(path.join(rootDir, HISTORY_PATH), "utf8");

  // Assert
  assert.equal(result.historyChanged, false);
  assert.equal(secondHistory, firstHistory);
  assert.equal(parseHistory(secondHistory).length, 1);
});

test("updateContextCost replaces one pending row after a same-sized source change", () => {
  // Arrange
  const rootDir = createFixture();
  generateAndCommitSnapshot(rootDir);
  const committedHistory = fs.readFileSync(path.join(rootDir, HISTORY_PATH), "utf8");
  writeFile(rootDir, SKILL_PATH, "skill bravo\n");
  updateContextCost({ now: new Date("2026-07-19T21:00:00.000Z"), rootDir });
  const firstPendingFingerprint = parseHistory(
    fs.readFileSync(path.join(rootDir, HISTORY_PATH), "utf8"),
  ).at(-1)?.sourceSha256;

  // Act
  writeFile(rootDir, SKILL_PATH, "skill delta\n");
  updateContextCost({ now: new Date("2026-07-19T22:00:00.000Z"), rootDir });
  const currentHistory = fs.readFileSync(path.join(rootDir, HISTORY_PATH), "utf8");
  const rows = parseHistory(currentHistory);

  // Assert
  assert.equal(currentHistory.startsWith(committedHistory), true);
  assert.equal(rows.length, 2);
  assert.notEqual(rows.at(-1)?.sourceSha256, firstPendingFingerprint);
  assert.equal(rows.at(-1)?.recordedAtUtc, "2026-07-19T22:00:00.000Z");
});

test("updateContextCost rejects edits to committed history", () => {
  // Arrange
  const rootDir = createFixture();
  generateAndCommitSnapshot(rootDir);
  const historyPath = path.join(rootDir, HISTORY_PATH);
  const history = fs.readFileSync(historyPath, "utf8");
  fs.writeFileSync(historyPath, history.replace("2026-07-19T20", "2026-07-18T20"), "utf8");

  // Act and Assert
  assert.throws(
    () => updateContextCost({ rootDir }),
    /committed context-cost history is not an exact prefix/u,
  );
});

test("parseHistory rejects duplicate consecutive snapshots", () => {
  // Arrange
  const rootDir = createFixture();
  updateContextCost({ now: new Date("2026-07-19T20:00:00.000Z"), rootDir });
  const history = fs.readFileSync(path.join(rootDir, HISTORY_PATH), "utf8");
  const lines = history.trimEnd().split("\n");
  const duplicateHistory = `${lines.join("\n")}\n${lines.at(-1)}\n`;

  // Act and Assert
  assert.throws(
    () => parseHistory(duplicateHistory),
    /duplicate consecutive context snapshot/u,
  );
});

test("parseHistory rejects impossible UTC timestamps", () => {
  // Arrange
  const rootDir = createFixture();
  updateContextCost({ now: new Date("2026-07-19T20:00:00.000Z"), rootDir });
  const history = fs
    .readFileSync(path.join(rootDir, HISTORY_PATH), "utf8")
    .replace("2026-07-19T20", "2026-99-19T20");

  // Act and Assert
  assert.throws(() => parseHistory(history), /invalid recorded_at_utc/u);
});

test("updateContextCost repairs README block drift and preserves surrounding content", () => {
  // Arrange
  const rootDir = createFixture();
  generateAndCommitSnapshot(rootDir);
  const readmePath = path.join(rootDir, README_PATH);
  const readme = fs.readFileSync(readmePath, "utf8");
  const drifted = `Local prefix.\n\n${readme.replace(
    "Bright Builds Rules publishes",
    "Drifted content replaces",
  )}\nLocal suffix.\n`;
  fs.writeFileSync(readmePath, drifted, "utf8");

  // Act
  updateContextCost({ rootDir });
  const repaired = fs.readFileSync(readmePath, "utf8");

  // Assert
  assert.match(repaired, /^Local prefix\./u);
  assert.match(repaired, /Local suffix\.\n$/u);
  assert.doesNotMatch(repaired, /Drifted content replaces/u);
  assert.equal(repaired.split(README_BLOCK_BEGIN).length - 1, 1);
  assert.equal(repaired.split(README_BLOCK_END).length - 1, 1);
});

test("checkContextCost detects stale measured sources", () => {
  // Arrange
  const rootDir = createFixture();
  generateAndCommitSnapshot(rootDir);
  writeFile(rootDir, SKILL_PATH, "skill bravo\n");

  // Act and Assert
  assert.throws(
    () => checkContextCost({ rootDir }),
    /latest context-cost history snapshot does not match measured sources/u,
  );
});

test("updateContextCost rejects incomplete README block markers", () => {
  // Arrange
  const rootDir = createFixture();
  generateAndCommitSnapshot(rootDir);
  const readmePath = path.join(rootDir, README_PATH);
  const readme = fs.readFileSync(readmePath, "utf8");
  fs.writeFileSync(readmePath, readme.replace(README_BLOCK_END, ""), "utf8");

  // Act and Assert
  assert.throws(
    () => updateContextCost({ rootDir }),
    /README context-cost block markers are incomplete or duplicated/u,
  );
});

test("checkContextCost accepts multiple appended snapshots while enforcing a base prefix", {
  timeout: 20_000,
}, () => {
  // Arrange
  const rootDir = createFixture();
  const baseCommit = generateAndCommitSnapshot(rootDir);
  writeFile(rootDir, SKILL_PATH, "skill bravo\n");
  updateContextCost({ now: new Date("2026-07-19T21:00:00.000Z"), rootDir });
  runGit(rootDir, ["add", "."]);
  runGit(rootDir, ["commit", "-qm", "change context once"]);
  writeFile(rootDir, SKILL_PATH, "skill delta\n");
  updateContextCost({ now: new Date("2026-07-19T22:00:00.000Z"), rootDir });
  runGit(rootDir, ["add", "."]);
  runGit(rootDir, ["commit", "-qm", "change context twice"]);

  // Act
  const row = checkContextCost({ maybeBaseRef: baseCommit, rootDir });

  // Assert
  assert.equal(row.sourceSha256, measureContextCost(rootDir).sourceSha256);
  assert.equal(parseHistory(fs.readFileSync(path.join(rootDir, HISTORY_PATH), "utf8")).length, 3);
});

test("checkContextCost rejects history rewritten relative to a Git base", () => {
  // Arrange
  const rootDir = createFixture();
  const baseCommit = generateAndCommitSnapshot(rootDir);
  writeFile(rootDir, SKILL_PATH, "skill bravo\n");
  updateContextCost({ now: new Date("2026-07-19T21:00:00.000Z"), rootDir });
  const historyPath = path.join(rootDir, HISTORY_PATH);
  const history = fs.readFileSync(historyPath, "utf8");
  fs.writeFileSync(historyPath, history.replace("2026-07-19T20", "2026-07-18T20"), "utf8");

  // Act and Assert
  assert.throws(
    () => checkContextCost({ maybeBaseRef: baseCommit, rootDir }),
    /committed context-cost history is not an exact prefix/u,
  );
});

test("tracked pre-commit hook stages complete working-tree context files", {
  timeout: 20_000,
}, () => {
  // Arrange
  const rootDir = prepareHookFixture();
  writeFile(rootDir, SKILL_PATH, "skill bravo\n");
  runGit(rootDir, ["add", SKILL_PATH]);
  writeFile(rootDir, SKILL_PATH, "skill delta\n");
  fs.appendFileSync(path.join(rootDir, README_PATH), "\nUnstaged README note.\n", "utf8");

  // Act
  execFileSync(path.join(rootDir, ".githooks/pre-commit"), { cwd: rootDir });

  // Assert
  assert.equal(runGit(rootDir, ["show", `:${SKILL_PATH}`]), "skill delta");
  assert.match(runGit(rootDir, ["show", `:${README_PATH}`]), /Unstaged README note\./u);
  assert.equal(
    parseHistory(runGit(rootDir, ["show", `:${HISTORY_PATH}`]) + "\n").at(-1)?.sourceSha256,
    measureContextCost(rootDir).sourceSha256,
  );
  assert.doesNotThrow(() => checkContextCost({ rootDir }));
});

test("tracked pre-commit hook removes a staged-only measured edit", {
  timeout: 20_000,
}, () => {
  // Arrange
  const rootDir = prepareHookFixture();
  writeFile(rootDir, SKILL_PATH, "skill bravo\n");
  runGit(rootDir, ["add", SKILL_PATH]);
  writeFile(rootDir, SKILL_PATH, "skill alpha\n");

  // Act
  execFileSync(path.join(rootDir, ".githooks/pre-commit"), { cwd: rootDir });

  // Assert
  assert.equal(runGit(rootDir, ["show", `:${SKILL_PATH}`]), "skill alpha");
  assert.equal(runGit(rootDir, ["diff", "--cached", "--name-only"]), "");
  assert.doesNotThrow(() => checkContextCost({ rootDir }));
});

test("installGitHooks replaces an existing repository hooks path", () => {
  // Arrange
  const rootDir = createFixture();
  runGit(rootDir, ["config", "--local", "core.hooksPath", "legacy-hooks"]);

  // Act
  const hooksPath = installGitHooks(rootDir);

  // Assert
  assert.equal(hooksPath, ".githooks");
  assert.equal(runGit(rootDir, ["config", "--local", "--get", "core.hooksPath"]), ".githooks");
});
