import fs from "node:fs";
import path from "node:path";

export type GeneratedArtifactStatus = "unchanged" | "written";

export interface GeneratedArtifactResult {
  outputPath: string;
  status: GeneratedArtifactStatus;
}

export interface GeneratedArtifactInput {
  check?: boolean;
  contents: string;
  outputPath: string;
  rootDir?: string;
}

export const ROOT = process.cwd();

export const absolutePath = (rootDir: string, value: string): string =>
  path.isAbsolute(value) ? value : path.join(rootDir, value);

export const ensureTrailingNewline = (value: string): string =>
  value.endsWith("\n") ? value : `${value}\n`;

export const writeGeneratedArtifact = (
  input: GeneratedArtifactInput,
): GeneratedArtifactResult => {
  const rootDir = input.rootDir ?? ROOT;
  const outputPath = absolutePath(rootDir, input.outputPath);
  const contents = ensureTrailingNewline(input.contents);
  const previous = fs.existsSync(outputPath) ? fs.readFileSync(outputPath, "utf8") : null;

  if (previous === contents) {
    return {
      outputPath,
      status: "unchanged",
    };
  }

  if (input.check) {
    throw new Error(`generated artifact is out of date: ${path.relative(rootDir, outputPath)}`);
  }

  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, contents, "utf8");

  return {
    outputPath,
    status: "written",
  };
};
