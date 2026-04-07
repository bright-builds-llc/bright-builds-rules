import assert from "node:assert/strict";
import fs from "node:fs";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import {
  buildFlatSiteBadgeSvg,
  DEFAULT_FLAT_SITE_BADGE_OUTPUT_PATH,
  DEFAULT_FLAT_SITE_BADGE_LOGO_PATH,
  generateFlatSiteBadgeArtifact,
  readSvgFileAsDataUrl,
  resolveFlatSiteBadgeSpec,
} from "./flat-site-badge.js";

test("resolveFlatSiteBadgeSpec returns the fixed OpenLinks-style Bright Builds badge spec", () => {
  const spec = resolveFlatSiteBadgeSpec();

  assert.deepEqual(spec, {
    label: "Bright Builds",
    message: "Coding requirements",
    labelColor: "#1c0a38",
    color: "#7f2aff",
    outputPath: "public/badges/bright-builds-flat.svg",
    publicPath: "/badges/bright-builds-flat.svg",
    style: "flat",
  });
});

test("buildFlatSiteBadgeSvg renders a stable flat badge svg", () => {
  const svg = buildFlatSiteBadgeSvg({
    logoDataUrl: "data:image/svg+xml;base64,PHN2Zz48L3N2Zz4=",
    spec: resolveFlatSiteBadgeSpec(),
  });

  assert.match(svg, /aria-label="Bright Builds: Coding requirements"/u);
  assert.match(svg, /data:image\/svg\+xml;base64,PHN2Zz48L3N2Zz4=/u);
  assert.match(svg, /#1c0a38/u);
  assert.match(svg, /#7f2aff/u);
});

test("readSvgFileAsDataUrl reads the checked-in public favicon", () => {
  const dataUrl = readSvgFileAsDataUrl();

  assert.match(dataUrl, /^data:image\/svg\+xml;base64,/u);
});

test("generateFlatSiteBadgeArtifact writes once and then reports unchanged", () => {
  const rootDir = mkdtempSync(path.join(tmpdir(), "bright-builds-flat-badge-"));
  fs.mkdirSync(path.join(rootDir, "public"), { recursive: true });
  fs.copyFileSync(
    path.join(process.cwd(), DEFAULT_FLAT_SITE_BADGE_LOGO_PATH),
    path.join(rootDir, DEFAULT_FLAT_SITE_BADGE_LOGO_PATH),
  );

  const first = generateFlatSiteBadgeArtifact({ rootDir });
  const second = generateFlatSiteBadgeArtifact({ rootDir });
  const absoluteOutputPath = path.join(rootDir, DEFAULT_FLAT_SITE_BADGE_OUTPUT_PATH);

  assert.equal(first.status, "written");
  assert.equal(second.status, "unchanged");
  assert.equal(fs.existsSync(absoluteOutputPath), true);
  const svg = fs.readFileSync(absoluteOutputPath, "utf8");
  assert.match(svg, /Bright Builds/u);
  assert.match(svg, /Coding requirements/u);
  assert.match(svg, /#1c0a38/u);
  assert.match(svg, /#7f2aff/u);
});

test("generateFlatSiteBadgeArtifact check mode fails when the flat badge is missing", () => {
  const rootDir = mkdtempSync(path.join(tmpdir(), "bright-builds-flat-badge-check-"));
  fs.mkdirSync(path.join(rootDir, "public"), { recursive: true });
  fs.copyFileSync(
    path.join(process.cwd(), DEFAULT_FLAT_SITE_BADGE_LOGO_PATH),
    path.join(rootDir, DEFAULT_FLAT_SITE_BADGE_LOGO_PATH),
  );

  assert.throws(
    () => generateFlatSiteBadgeArtifact({ check: true, rootDir }),
    /generated artifact is out of date: public\/badges\/bright-builds-flat\.svg/u,
  );
});
