import assert from "node:assert/strict";
import fs from "node:fs";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import { buildCanonicalSiteBadgeSvg } from "./badge-svg.js";
import {
  buildSiteBadgeSvg,
  DEFAULT_SITE_BADGE_OUTPUT_PATH,
  generateSiteBadgeArtifact,
  resolveSiteBadgeSpec,
} from "./site-badge.js";

test("resolveSiteBadgeSpec returns the canonical Bright Builds badge spec", () => {
  const spec = resolveSiteBadgeSpec();

  assert.deepEqual(spec, {
    label: "Bright Builds Rules",
    outputPath: "public/badges/bright-builds-rules.svg",
    publicPath: "/badges/bright-builds-rules.svg",
  });
});

test("buildSiteBadgeSvg renders a stable canonical badge svg", () => {
  const svg = buildSiteBadgeSvg();

  assert.match(svg, /aria-label="Bright Builds Rules"/u);
  assert.match(svg, /Bright Builds/u);
  assert.match(svg, /RULES/u);
  assert.match(svg, /ACTIVE/u);
  assert.match(svg, /width="225" height="40" viewBox="0 0 225 40"/u);
  assert.match(svg, /<text x="40" y="19"[^>]*>Bright Builds<\/text>/u);
  assert.match(svg, /<text x="40" y="31\.5"[^>]*>RULES<\/text>/u);
});

test("buildSiteBadgeSvg matches the template-backed canonical renderer", () => {
  assert.equal(buildSiteBadgeSvg(), buildCanonicalSiteBadgeSvg());
});

test("generateSiteBadgeArtifact writes once and then reports unchanged", () => {
  const rootDir = mkdtempSync(path.join(tmpdir(), "bright-builds-site-badge-"));

  const first = generateSiteBadgeArtifact({ rootDir });
  const second = generateSiteBadgeArtifact({ rootDir });
  const absoluteOutputPath = path.join(rootDir, DEFAULT_SITE_BADGE_OUTPUT_PATH);

  assert.equal(first.status, "written");
  assert.equal(second.status, "unchanged");
  assert.equal(fs.existsSync(absoluteOutputPath), true);
  assert.match(fs.readFileSync(absoluteOutputPath, "utf8"), /Bright Builds/u);
});

test("generateSiteBadgeArtifact check mode fails when the canonical badge is missing", () => {
  const rootDir = mkdtempSync(path.join(tmpdir(), "bright-builds-site-badge-check-"));

  assert.throws(
    () => generateSiteBadgeArtifact({ check: true, rootDir }),
    /generated artifact is out of date: public\/badges\/bright-builds-rules\.svg/u,
  );
});

test("badge-svg module does not embed raw svg tags inline", () => {
  const source = fs.readFileSync(path.join(process.cwd(), "scripts/badge-svg.ts"), "utf8");

  assert.doesNotMatch(source, /<svg/u);
  assert.doesNotMatch(source, /<rect/u);
  assert.doesNotMatch(source, /<text/u);
  assert.doesNotMatch(source, /<symbol/u);
  assert.doesNotMatch(source, /<path/u);
});

test("template rendering fails when placeholders remain unresolved", async () => {
  const { renderTemplate } = await import("./badge-svg.js");

  assert.throws(
    () => renderTemplate("site-badge.svg.tmpl", {
      FONT_STACK: "Avenir Next, Inter, Segoe UI, Arial, sans-serif",
    }),
    /unresolved placeholder\(s\) remain in site-badge\.svg\.tmpl/u,
  );
});
