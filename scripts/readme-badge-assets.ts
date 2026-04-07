import path from "node:path";
import {
  buildReadmeCompactBadgeSvg,
  buildReadmeDarkBadgeSvg,
  buildReadmeLightBadgeSvg,
} from "./badge-svg.js";
import { ROOT, type GeneratedArtifactResult, writeGeneratedArtifact } from "./badge-artifacts.js";

export interface ReadmeBadgeAssetSpec {
  filename: string;
  outputPath: string;
  svg: string;
}

export interface GenerateReadmeBadgeAssetsInput {
  check?: boolean;
  rootDir?: string;
}

export const buildReadmeBadgeAssetSpecs = (): ReadmeBadgeAssetSpec[] => [
  {
    filename: "bright-builds-requirements-dark.svg",
    outputPath: "assets/badges/bright-builds-requirements-dark.svg",
    svg: buildReadmeDarkBadgeSvg(),
  },
  {
    filename: "bright-builds-requirements-light.svg",
    outputPath: "assets/badges/bright-builds-requirements-light.svg",
    svg: buildReadmeLightBadgeSvg(),
  },
  {
    filename: "bright-builds-requirements-compact.svg",
    outputPath: "assets/badges/bright-builds-requirements-compact.svg",
    svg: buildReadmeCompactBadgeSvg(),
  },
];

export const generateReadmeBadgeAssets = (
  input: GenerateReadmeBadgeAssetsInput = {},
): GeneratedArtifactResult[] => {
  const rootDir = input.rootDir ?? ROOT;
  return buildReadmeBadgeAssetSpecs().map((asset) =>
    writeGeneratedArtifact({
      check: input.check,
      contents: asset.svg,
      outputPath: asset.outputPath,
      rootDir,
    }),
  );
};

export const formatReadmeBadgeAssetResults = (
  results: GeneratedArtifactResult[],
  rootDir = ROOT,
): string =>
  results
    .map((result) => `README badge asset ${result.status}: ${path.relative(rootDir, result.outputPath)}`)
    .join("\n");
