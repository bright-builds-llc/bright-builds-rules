import path from "node:path";
import { buildCanonicalSiteBadgeSvg } from "./badge-svg.js";
import { ROOT, type GeneratedArtifactResult, writeGeneratedArtifact } from "./badge-artifacts.js";

export const DEFAULT_SITE_BADGE_OUTPUT_PATH = "public/badges/bright-builds-rules.svg";

export interface ResolvedSiteBadgeSpec {
  label: string;
  outputPath: string;
  publicPath: string;
}

export interface GenerateSiteBadgeArtifactInput {
  check?: boolean;
  outputPath?: string;
  rootDir?: string;
}

export const resolveSiteBadgeSpec = (outputPath = DEFAULT_SITE_BADGE_OUTPUT_PATH): ResolvedSiteBadgeSpec => ({
  label: "Bright Builds Rules",
  outputPath,
  publicPath: "/badges/bright-builds-rules.svg",
});

export const buildSiteBadgeSvg = (): string => buildCanonicalSiteBadgeSvg();

export const generateSiteBadgeArtifact = (
  input: GenerateSiteBadgeArtifactInput = {},
): GeneratedArtifactResult =>
  writeGeneratedArtifact({
    check: input.check,
    contents: buildSiteBadgeSvg(),
    outputPath: resolveSiteBadgeSpec(input.outputPath).outputPath,
    rootDir: input.rootDir ?? ROOT,
  });

export const formatSiteBadgeResult = (result: GeneratedArtifactResult, rootDir = ROOT): string =>
  `Site badge ${result.status}: ${path.relative(rootDir, result.outputPath)}`;
