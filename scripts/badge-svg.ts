import fs from "node:fs";
import path from "node:path";
import { ROOT } from "./badge-artifacts.js";

export const LOGO_SOURCE_URL =
  "https://raw.githubusercontent.com/bright-builds-llc/logo/main/assets/logo/primary/bright-builds-logo.svg";
export const GENERATOR_SITE_BADGE_PATH = "scripts/generate-site-badge.ts";
export const GENERATOR_README_BADGE_ASSETS_PATH = "scripts/generate-readme-badge-assets.ts";
export const FONT_STACK = "Avenir Next, Inter, Segoe UI, Arial, sans-serif";
export const PRIMARY_TEXT_Y = "19";
export const SECONDARY_TEXT_Y = "31.5";

const TEMPLATE_DIR = path.join(ROOT, "scripts/badge-templates");
const PLACEHOLDER_PATTERN = /\{\{[A-Z0-9_]+\}\}/u;

const readTemplate = (filename: string): string =>
  fs.readFileSync(path.join(TEMPLATE_DIR, filename), "utf8");

export const renderTemplate = (templateName: string, values: Record<string, string>): string => {
  let template = readTemplate(templateName);
  for (const [key, value] of Object.entries(values)) {
    template = template.replaceAll(`{{${key}}}`, value);
  }

  if (PLACEHOLDER_PATTERN.test(template)) {
    throw new Error(`unresolved placeholder(s) remain in ${templateName}`);
  }

  return template;
};

const renderLogoSymbol = (): string => readTemplate("logo-symbol.svg.fragment");

const buildTemplateValues = (
  generatorPath: string,
  svgWidth: string,
  svgHeight: string,
  outerWidth: string,
): Record<string, string> => ({
  FONT_STACK,
  GENERATOR_PATH: generatorPath,
  LOGO_SOURCE_URL,
  LOGO_SYMBOL: renderLogoSymbol(),
  OUTER_WIDTH: outerWidth,
  PRIMARY_TEXT_Y,
  SECONDARY_TEXT_Y,
  SVG_HEIGHT: svgHeight,
  SVG_WIDTH: svgWidth,
});

export const buildCanonicalSiteBadgeSvg = (): string =>
  renderTemplate(
    "site-badge.svg.tmpl",
    buildTemplateValues(GENERATOR_SITE_BADGE_PATH, "225", "40", "223.5"),
  );

export const buildReadmeDarkBadgeSvg = (): string =>
  renderTemplate(
    "readme-dark.svg.tmpl",
    buildTemplateValues(GENERATOR_README_BADGE_ASSETS_PATH, "225", "40", "223.5"),
  );

export const buildReadmeLightBadgeSvg = (): string =>
  renderTemplate(
    "readme-light.svg.tmpl",
    buildTemplateValues(GENERATOR_README_BADGE_ASSETS_PATH, "218", "40", "216.5"),
  );

export const buildReadmeCompactBadgeSvg = (): string =>
  renderTemplate(
    "readme-compact.svg.tmpl",
    buildTemplateValues(GENERATOR_README_BADGE_ASSETS_PATH, "190", "36", "188.5"),
  );
