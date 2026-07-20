export const ESTIMATOR_VERSION = "utf8-bytes-ceil-div-3-v1";
export const UNBORN_BASE_COMMIT = "UNBORN";

const HISTORY_HEADER = [
  "recorded_at_utc",
  "base_commit",
  "source_sha256",
  "estimator",
  "skill_bytes",
  "skill_estimated_tokens",
  "adoption_guide_bytes",
  "adoption_guide_estimated_tokens",
  "adoption_path_bytes",
  "adoption_path_estimated_tokens",
].join(",");

const ISO_UTC_PATTERN = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/u;
const GIT_COMMIT_PATTERN = /^[0-9a-f]{40}$/u;
const SHA256_PATTERN = /^[0-9a-f]{64}$/u;

export interface ContextMeasurement {
  adoptionGuideBytes: number;
  adoptionGuideEstimatedTokens: number;
  adoptionPathBytes: number;
  adoptionPathEstimatedTokens: number;
  skillBytes: number;
  skillEstimatedTokens: number;
  sourceSha256: string;
}

export interface ContextCostRow extends ContextMeasurement {
  baseCommit: string;
  estimator: string;
  recordedAtUtc: string;
}

export const estimateTokens = (byteCount: number): number => Math.ceil(byteCount / 3);

const parseInteger = (value: string, field: string, lineNumber: number): number => {
  if (!/^(0|[1-9]\d*)$/u.test(value)) {
    throw new Error(`invalid ${field} on context-cost history line ${lineNumber}`);
  }

  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed)) {
    throw new Error(`unsafe integer ${field} on context-cost history line ${lineNumber}`);
  }

  return parsed;
};

const validateRow = (row: ContextCostRow, lineNumber: number): void => {
  if (
    !ISO_UTC_PATTERN.test(row.recordedAtUtc) ||
    Number.isNaN(Date.parse(row.recordedAtUtc)) ||
    new Date(row.recordedAtUtc).toISOString() !== row.recordedAtUtc
  ) {
    throw new Error(`invalid recorded_at_utc on context-cost history line ${lineNumber}`);
  }
  if (row.baseCommit !== UNBORN_BASE_COMMIT && !GIT_COMMIT_PATTERN.test(row.baseCommit)) {
    throw new Error(`invalid base_commit on context-cost history line ${lineNumber}`);
  }
  if (!SHA256_PATTERN.test(row.sourceSha256)) {
    throw new Error(`invalid source_sha256 on context-cost history line ${lineNumber}`);
  }
  if (row.estimator !== ESTIMATOR_VERSION) {
    throw new Error(`unsupported estimator on context-cost history line ${lineNumber}`);
  }
  if (row.skillEstimatedTokens !== estimateTokens(row.skillBytes)) {
    throw new Error(`skill estimate mismatch on context-cost history line ${lineNumber}`);
  }
  if (row.adoptionGuideEstimatedTokens !== estimateTokens(row.adoptionGuideBytes)) {
    throw new Error(`adoption guide estimate mismatch on context-cost history line ${lineNumber}`);
  }
  if (row.adoptionPathBytes !== row.skillBytes + row.adoptionGuideBytes) {
    throw new Error(`adoption path byte total mismatch on context-cost history line ${lineNumber}`);
  }
  if (
    row.adoptionPathEstimatedTokens !==
    row.skillEstimatedTokens + row.adoptionGuideEstimatedTokens
  ) {
    throw new Error(`adoption path token total mismatch on context-cost history line ${lineNumber}`);
  }
};

const parseRow = (line: string, lineNumber: number): ContextCostRow => {
  const fields = line.split(",");
  if (fields.length !== 10) {
    throw new Error(`expected 10 fields on context-cost history line ${lineNumber}`);
  }

  const [
    recordedAtUtc = "",
    baseCommit = "",
    sourceSha256 = "",
    estimator = "",
    skillBytes = "",
    skillEstimatedTokens = "",
    adoptionGuideBytes = "",
    adoptionGuideEstimatedTokens = "",
    adoptionPathBytes = "",
    adoptionPathEstimatedTokens = "",
  ] = fields;

  const row = {
    adoptionGuideBytes: parseInteger(adoptionGuideBytes, "adoption_guide_bytes", lineNumber),
    adoptionGuideEstimatedTokens: parseInteger(
      adoptionGuideEstimatedTokens,
      "adoption_guide_estimated_tokens",
      lineNumber,
    ),
    adoptionPathBytes: parseInteger(adoptionPathBytes, "adoption_path_bytes", lineNumber),
    adoptionPathEstimatedTokens: parseInteger(
      adoptionPathEstimatedTokens,
      "adoption_path_estimated_tokens",
      lineNumber,
    ),
    baseCommit,
    estimator,
    recordedAtUtc,
    skillBytes: parseInteger(skillBytes, "skill_bytes", lineNumber),
    skillEstimatedTokens: parseInteger(
      skillEstimatedTokens,
      "skill_estimated_tokens",
      lineNumber,
    ),
    sourceSha256,
  };

  validateRow(row, lineNumber);
  return row;
};

export const parseHistory = (contents: string): ContextCostRow[] => {
  if (!contents.endsWith("\n")) {
    throw new Error("context-cost history must end with a newline");
  }

  const lines = contents.slice(0, -1).split("\n");
  if (lines[0] !== HISTORY_HEADER) {
    throw new Error("context-cost history header is invalid");
  }

  const rows = lines.slice(1).map((line, index) => parseRow(line, index + 2));
  for (let index = 1; index < rows.length; index += 1) {
    if (rows[index - 1]?.sourceSha256 === rows[index]?.sourceSha256) {
      throw new Error(`duplicate consecutive context snapshot on history line ${index + 2}`);
    }
  }

  return rows;
};

const serializeRow = (row: ContextCostRow): string =>
  [
    row.recordedAtUtc,
    row.baseCommit,
    row.sourceSha256,
    row.estimator,
    row.skillBytes,
    row.skillEstimatedTokens,
    row.adoptionGuideBytes,
    row.adoptionGuideEstimatedTokens,
    row.adoptionPathBytes,
    row.adoptionPathEstimatedTokens,
  ].join(",");

export const serializeHistory = (rows: ContextCostRow[]): string =>
  `${HISTORY_HEADER}\n${rows.map(serializeRow).join("\n")}${rows.length > 0 ? "\n" : ""}`;
