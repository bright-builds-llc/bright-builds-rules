import fs from "node:fs";
import path from "node:path";
import { makeBadge } from "badge-maker";
import { ROOT, absolutePath, type GeneratedArtifactResult, writeGeneratedArtifact } from "./badge-artifacts.js";

export const DEFAULT_FLAT_SITE_BADGE_OUTPUT_PATH = "public/badges/bright-builds-rules-flat.svg";
export const DEFAULT_FLAT_SITE_BADGE_LOGO_PATH = "public/favicon.svg";
export const DEFAULT_FLAT_SITE_BADGE_LABEL = "Bright Builds";
export const DEFAULT_FLAT_SITE_BADGE_MESSAGE = "Rules";
export const DEFAULT_FLAT_SITE_BADGE_LABEL_COLOR = "#1c0a38";
export const DEFAULT_FLAT_SITE_BADGE_MESSAGE_COLOR = "#7f2aff";
export const DEFAULT_FLAT_SITE_BADGE_STYLE = "flat" as const;

export interface ResolvedFlatSiteBadgeSpec {
  label: string;
  message: string;
  labelColor: string;
  color: string;
  outputPath: string;
  publicPath: string;
  style: "flat";
}

export interface BuildFlatSiteBadgeSvgInput {
  logoDataUrl: string;
  spec: ResolvedFlatSiteBadgeSpec;
}

export interface GenerateFlatSiteBadgeArtifactInput {
  check?: boolean;
  logoPath?: string;
  outputPath?: string;
  rootDir?: string;
}

export const resolveFlatSiteBadgeSpec = (
  outputPath = DEFAULT_FLAT_SITE_BADGE_OUTPUT_PATH,
): ResolvedFlatSiteBadgeSpec => ({
  label: DEFAULT_FLAT_SITE_BADGE_LABEL,
  message: DEFAULT_FLAT_SITE_BADGE_MESSAGE,
  labelColor: DEFAULT_FLAT_SITE_BADGE_LABEL_COLOR,
  color: DEFAULT_FLAT_SITE_BADGE_MESSAGE_COLOR,
  outputPath,
  publicPath: "/badges/bright-builds-rules-flat.svg",
  style: DEFAULT_FLAT_SITE_BADGE_STYLE,
});

export const readSvgFileAsDataUrl = (
  rootDir = ROOT,
  relativePath = DEFAULT_FLAT_SITE_BADGE_LOGO_PATH,
): string => {
  const absolute = absolutePath(rootDir, relativePath);
  const svg = fs.readFileSync(absolute, "utf8");
  return `data:image/svg+xml;base64,${Buffer.from(svg, "utf8").toString("base64")}`;
};

export const buildFlatSiteBadgeSvg = (input: BuildFlatSiteBadgeSvgInput): string =>
  makeBadge({
    color: input.spec.color,
    idSuffix: "brightBuildsRulesFlatBadge",
    label: input.spec.label,
    labelColor: input.spec.labelColor,
    logoBase64: input.logoDataUrl,
    message: input.spec.message,
    style: input.spec.style,
  });

export const generateFlatSiteBadgeArtifact = (
  input: GenerateFlatSiteBadgeArtifactInput = {},
): GeneratedArtifactResult => {
  const rootDir = input.rootDir ?? ROOT;
  const spec = resolveFlatSiteBadgeSpec(input.outputPath);
  return writeGeneratedArtifact({
    check: input.check,
    contents: buildFlatSiteBadgeSvg({
      logoDataUrl: readSvgFileAsDataUrl(rootDir, input.logoPath ?? DEFAULT_FLAT_SITE_BADGE_LOGO_PATH),
      spec,
    }),
    outputPath: spec.outputPath,
    rootDir,
  });
};

export const formatFlatSiteBadgeResult = (result: GeneratedArtifactResult, rootDir = ROOT): string =>
  `Flat site badge ${result.status}: ${path.relative(rootDir, result.outputPath)}`;
