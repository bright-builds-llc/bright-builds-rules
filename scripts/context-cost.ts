import { createHash } from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import {
  ESTIMATOR_VERSION,
  type ContextCostRow,
  type ContextMeasurement,
  estimateTokens,
  parseHistory,
  serializeHistory,
  UNBORN_BASE_COMMIT,
} from "./context-cost-history.js";

export {
  ESTIMATOR_VERSION,
  type ContextCostRow,
  type ContextMeasurement,
  estimateTokens,
  parseHistory,
  serializeHistory,
  UNBORN_BASE_COMMIT,
} from "./context-cost-history.js";

export const HISTORY_PATH = "metrics/context-cost-history.csv";
export const README_PATH = "README.md";
export const SKILL_PATH = "skills/bright-builds-rules/SKILL.md";
export const ADOPTION_GUIDE_PATH = "AI-ADOPTION.md";
export const README_BLOCK_BEGIN = "<!-- bright-builds-rules-context-cost:begin -->";
export const README_BLOCK_END = "<!-- bright-builds-rules-context-cost:end -->";

export const CONTEXT_COST_PATHS = [
  SKILL_PATH,
  ADOPTION_GUIDE_PATH,
  README_PATH,
  HISTORY_PATH,
] as const;

export interface UpdateContextCostInput {
  now?: Date;
  rootDir?: string;
}

export interface UpdateContextCostResult {
  historyChanged: boolean;
  measurementChangedFromHead: boolean;
  readmeChanged: boolean;
  row: ContextCostRow;
}

export interface CheckContextCostInput {
  maybeBaseRef?: string;
  rootDir?: string;
}

interface GitFileAtRef {
  content: string | null;
  resolvedCommit: string | null;
}

interface PendingHistory {
  committedRows: ContextCostRow[];
  maybePendingRow: ContextCostRow | undefined;
}

const readBuffer = (rootDir: string, relativePath: string): Buffer =>
  fs.readFileSync(path.join(rootDir, relativePath));

export const measureContextCost = (rootDir = process.cwd()): ContextMeasurement => {
  const skill = readBuffer(rootDir, SKILL_PATH);
  const adoptionGuide = readBuffer(rootDir, ADOPTION_GUIDE_PATH);
  const sourceHash = createHash("sha256");

  for (const [relativePath, contents] of [
    [SKILL_PATH, skill],
    [ADOPTION_GUIDE_PATH, adoptionGuide],
  ] as const) {
    sourceHash.update(relativePath);
    sourceHash.update("\0");
    sourceHash.update(String(contents.byteLength));
    sourceHash.update("\0");
    sourceHash.update(contents);
    sourceHash.update("\0");
  }

  const skillEstimatedTokens = estimateTokens(skill.byteLength);
  const adoptionGuideEstimatedTokens = estimateTokens(adoptionGuide.byteLength);

  return {
    adoptionGuideBytes: adoptionGuide.byteLength,
    adoptionGuideEstimatedTokens,
    adoptionPathBytes: skill.byteLength + adoptionGuide.byteLength,
    adoptionPathEstimatedTokens: skillEstimatedTokens + adoptionGuideEstimatedTokens,
    skillBytes: skill.byteLength,
    skillEstimatedTokens,
    sourceSha256: sourceHash.digest("hex"),
  };
};

const runGit = (
  rootDir: string,
  args: string[],
): { stderr: string; stdout: string; status: number } => {
  const result = spawnSync("git", ["-C", rootDir, ...args], {
    encoding: "utf8",
  });

  if (result.error) {
    throw result.error;
  }

  return {
    stderr: result.stderr,
    stdout: result.stdout,
    status: result.status ?? 1,
  };
};

const resolveGitRef = (
  rootDir: string,
  ref: string,
  allowMissing: boolean,
): string | null => {
  const result = runGit(rootDir, ["rev-parse", "--verify", `${ref}^{commit}`]);
  if (result.status === 0) {
    return result.stdout.trim();
  }
  if (allowMissing) {
    return null;
  }

  throw new Error(`unable to resolve Git base ref ${ref}: ${result.stderr.trim()}`);
};

const readGitFileAtRef = (
  rootDir: string,
  ref: string,
  allowMissingRef: boolean,
): GitFileAtRef => {
  const resolvedCommit = resolveGitRef(rootDir, ref, allowMissingRef);
  if (resolvedCommit === null) {
    return { content: null, resolvedCommit: null };
  }

  const result = runGit(rootDir, ["show", `${resolvedCommit}:${HISTORY_PATH}`]);
  if (result.status === 0) {
    return { content: result.stdout, resolvedCommit };
  }

  return { content: null, resolvedCommit };
};

const maybeReadText = (rootDir: string, relativePath: string): string | null => {
  const absolutePath = path.join(rootDir, relativePath);
  return fs.existsSync(absolutePath) ? fs.readFileSync(absolutePath, "utf8") : null;
};

const validateAppendOnlyHistory = (
  currentContents: string,
  maybeBaseContents: string | null,
  maybeMaximumAppendedRows?: number,
): ContextCostRow[] => {
  const currentRows = parseHistory(currentContents);
  if (maybeBaseContents === null) {
    if (
      maybeMaximumAppendedRows !== undefined &&
      currentRows.length > maybeMaximumAppendedRows
    ) {
      throw new Error("context-cost history has more than one uncommitted snapshot");
    }
    return currentRows;
  }

  const baseRows = parseHistory(maybeBaseContents);
  if (!currentContents.startsWith(maybeBaseContents)) {
    throw new Error("committed context-cost history is not an exact prefix of the current file");
  }

  const appendedRows = currentRows.length - baseRows.length;
  if (appendedRows < 0) {
    throw new Error("context-cost history removed committed rows");
  }
  if (maybeMaximumAppendedRows !== undefined && appendedRows > maybeMaximumAppendedRows) {
    throw new Error("context-cost history has more than one uncommitted snapshot");
  }

  return currentRows;
};

const readPendingHistory = (rootDir: string): PendingHistory => {
  const committed = readGitFileAtRef(rootDir, "HEAD", true);
  const maybeCurrentContents = maybeReadText(rootDir, HISTORY_PATH);

  if (maybeCurrentContents === null) {
    if (committed.content !== null) {
      throw new Error("context-cost history removed the committed file");
    }
    return { committedRows: [], maybePendingRow: undefined };
  }

  const currentRows = validateAppendOnlyHistory(maybeCurrentContents, committed.content, 1);
  const committedRows = committed.content === null ? [] : parseHistory(committed.content);

  return {
    committedRows,
    maybePendingRow: currentRows[committedRows.length],
  };
};

const measurementMatchesRow = (
  measurement: ContextMeasurement,
  row: ContextCostRow,
): boolean =>
  row.estimator === ESTIMATOR_VERSION &&
  row.sourceSha256 === measurement.sourceSha256 &&
  row.skillBytes === measurement.skillBytes &&
  row.skillEstimatedTokens === measurement.skillEstimatedTokens &&
  row.adoptionGuideBytes === measurement.adoptionGuideBytes &&
  row.adoptionGuideEstimatedTokens === measurement.adoptionGuideEstimatedTokens &&
  row.adoptionPathBytes === measurement.adoptionPathBytes &&
  row.adoptionPathEstimatedTokens === measurement.adoptionPathEstimatedTokens;

const buildRow = (
  measurement: ContextMeasurement,
  recordedAtUtc: string,
  baseCommit: string,
): ContextCostRow => ({
  ...measurement,
  baseCommit,
  estimator: ESTIMATOR_VERSION,
  recordedAtUtc,
});

const formatCount = (value: number): string => new Intl.NumberFormat("en-US").format(value);

const buildMarkdownTable = (
  headers: string[],
  rows: string[][],
  rightAlignedColumns: Set<number>,
): string[] => {
  const widths = headers.map((header, columnIndex) =>
    Math.max(
      header.length,
      ...rows.map((row) => row[columnIndex]?.length ?? 0),
      3,
    ),
  );
  const formatCells = (cells: string[]): string =>
    `| ${cells
      .map((cell, columnIndex) =>
        rightAlignedColumns.has(columnIndex)
          ? cell.padStart(widths[columnIndex] ?? cell.length)
          : cell.padEnd(widths[columnIndex] ?? cell.length),
      )
      .join(" | ")} |`;
  const separator = widths.map((width, columnIndex) =>
    rightAlignedColumns.has(columnIndex)
      ? `${"-".repeat(width - 1)}:`
      : "-".repeat(width),
  );

  return [formatCells(headers), formatCells(separator), ...rows.map(formatCells)];
};

export const buildReadmeBlock = (row: ContextCostRow): string => {
  const shortBaseCommit =
    row.baseCommit === UNBORN_BASE_COMMIT ? row.baseCommit : row.baseCommit.slice(0, 12);
  const table = buildMarkdownTable(
    ["Baseline", "Included files", "UTF-8 bytes", "Estimated tokens"],
    [
      [
        "Skill instructions",
        `\`${SKILL_PATH}\``,
        formatCount(row.skillBytes),
        formatCount(row.skillEstimatedTokens),
      ],
      [
        "Adoption path",
        `Skill instructions + \`${ADOPTION_GUIDE_PATH}\``,
        formatCount(row.adoptionPathBytes),
        formatCount(row.adoptionPathEstimatedTokens),
      ],
    ],
    new Set([2, 3]),
  );

  return [
    README_BLOCK_BEGIN,
    "",
    "## Estimated AI context cost",
    "",
    "Bright Builds Rules publishes a conservative approximation of the instruction context an AI must load for the skill and its adoption flow.",
    "",
    ...table,
    "",
    `Latest snapshot: \`${row.recordedAtUtc}\` from base commit \`${shortBaseCommit}\`. Estimator: \`${row.estimator}\`, calculated per file and then summed.`,
    "",
    "This is a rough context approximation, not API billing or cached-token usage. Skill metadata, this README, and task-specific standards pages are excluded; standards pages are variable additional context selected for the task.",
    "",
    `[View the append-only context-cost history.](${HISTORY_PATH})`,
    "",
    README_BLOCK_END,
  ].join("\n");
};

export const renderReadme = (contents: string, row: ContextCostRow): string => {
  const beginCount = contents.split(README_BLOCK_BEGIN).length - 1;
  const endCount = contents.split(README_BLOCK_END).length - 1;
  const block = buildReadmeBlock(row);

  if (beginCount === 0 && endCount === 0) {
    const anchor = "## For AI Agents";
    const anchorIndex = contents.indexOf(anchor);
    if (anchorIndex < 0) {
      throw new Error(`README insertion anchor is missing: ${anchor}`);
    }
    return `${contents.slice(0, anchorIndex)}${block}\n\n${contents.slice(anchorIndex)}`;
  }

  if (beginCount !== 1 || endCount !== 1) {
    throw new Error("README context-cost block markers are incomplete or duplicated");
  }

  const beginIndex = contents.indexOf(README_BLOCK_BEGIN);
  const endMarkerIndex = contents.indexOf(README_BLOCK_END, beginIndex);
  if (endMarkerIndex < beginIndex) {
    throw new Error("README context-cost block markers are out of order");
  }
  const endIndex = endMarkerIndex + README_BLOCK_END.length;
  return `${contents.slice(0, beginIndex)}${block}${contents.slice(endIndex)}`;
};

const writeIfChanged = (absolutePath: string, contents: string): boolean => {
  const maybePrevious = fs.existsSync(absolutePath)
    ? fs.readFileSync(absolutePath, "utf8")
    : undefined;
  if (maybePrevious === contents) {
    return false;
  }

  fs.mkdirSync(path.dirname(absolutePath), { recursive: true });
  fs.writeFileSync(absolutePath, contents, "utf8");
  return true;
};

export const updateContextCost = (
  input: UpdateContextCostInput = {},
): UpdateContextCostResult => {
  const rootDir = input.rootDir ?? process.cwd();
  const now = input.now ?? new Date();
  const measurement = measureContextCost(rootDir);
  const { committedRows, maybePendingRow } = readPendingHistory(rootDir);
  const maybeLastCommittedRow = committedRows.at(-1);
  const measurementChangedFromHead =
    maybeLastCommittedRow === undefined ||
    maybeLastCommittedRow.sourceSha256 !== measurement.sourceSha256;

  let rows = committedRows;
  if (measurementChangedFromHead) {
    const head = readGitFileAtRef(rootDir, "HEAD", true);
    const pendingRow =
      maybePendingRow !== undefined && measurementMatchesRow(measurement, maybePendingRow)
        ? maybePendingRow
        : buildRow(
            measurement,
            now.toISOString(),
            head.resolvedCommit ?? UNBORN_BASE_COMMIT,
          );
    rows = [...committedRows, pendingRow];
  }

  const row = rows.at(-1);
  if (row === undefined) {
    throw new Error("context-cost history could not produce a current snapshot");
  }

  const historyChanged = writeIfChanged(
    path.join(rootDir, HISTORY_PATH),
    serializeHistory(rows),
  );
  const readmePath = path.join(rootDir, README_PATH);
  const readmeContents = fs.readFileSync(readmePath, "utf8");
  const readmeChanged = writeIfChanged(readmePath, renderReadme(readmeContents, row));

  return {
    historyChanged,
    measurementChangedFromHead,
    readmeChanged,
    row,
  };
};

export const checkContextCost = (input: CheckContextCostInput = {}): ContextCostRow => {
  const rootDir = input.rootDir ?? process.cwd();
  const historyContents = fs.readFileSync(path.join(rootDir, HISTORY_PATH), "utf8");
  const maybeBaseRef = input.maybeBaseRef;
  const base = maybeBaseRef
    ? readGitFileAtRef(rootDir, maybeBaseRef, false)
    : readGitFileAtRef(rootDir, "HEAD", true);
  const rows = validateAppendOnlyHistory(historyContents, base.content);
  const row = rows.at(-1);
  if (row === undefined) {
    throw new Error("context-cost history does not contain a snapshot");
  }

  const measurement = measureContextCost(rootDir);
  if (!measurementMatchesRow(measurement, row)) {
    throw new Error("latest context-cost history snapshot does not match measured sources");
  }

  const readmePath = path.join(rootDir, README_PATH);
  const readmeContents = fs.readFileSync(readmePath, "utf8");
  if (renderReadme(readmeContents, row) !== readmeContents) {
    throw new Error("README context-cost block is out of date");
  }

  return row;
};

export const stageContextCostPaths = (rootDir = process.cwd()): void => {
  const result = runGit(rootDir, ["add", "--", ...CONTEXT_COST_PATHS]);
  if (result.status !== 0) {
    throw new Error(`unable to stage context-cost paths: ${result.stderr.trim()}`);
  }
};
