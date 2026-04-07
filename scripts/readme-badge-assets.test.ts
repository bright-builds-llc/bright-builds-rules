import assert from "node:assert/strict";
import fs from "node:fs";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import {
  buildReadmeCompactBadgeSvg,
  buildReadmeDarkBadgeSvg,
  buildReadmeLightBadgeSvg,
} from "./badge-svg.js";
import { buildReadmeBadgeAssetSpecs, generateReadmeBadgeAssets } from "./readme-badge-assets.js";

test("buildReadmeBadgeAssetSpecs returns the retained alternate badge family", () => {
  const specs = buildReadmeBadgeAssetSpecs();

  assert.deepEqual(
    specs.map((spec: { outputPath: string }) => spec.outputPath),
    [
      "assets/badges/bright-builds-requirements-dark.svg",
      "assets/badges/bright-builds-requirements-light.svg",
      "assets/badges/bright-builds-requirements-compact.svg",
    ],
  );
  assert.match(specs[0]?.svg ?? "", /width="225" height="40" viewBox="0 0 225 40"/u);
  assert.match(specs[1]?.svg ?? "", /width="218" height="40" viewBox="0 0 218 40"/u);
  assert.match(specs[2]?.svg ?? "", /width="175" height="36" viewBox="0 0 175 36"/u);
  assert.equal(specs[0]?.svg, buildReadmeDarkBadgeSvg());
  assert.equal(specs[1]?.svg, buildReadmeLightBadgeSvg());
  assert.equal(specs[2]?.svg, buildReadmeCompactBadgeSvg());
});

test("generateReadmeBadgeAssets writes the assets and then reports unchanged", () => {
  const rootDir = mkdtempSync(path.join(tmpdir(), "bright-builds-readme-badges-"));

  const first = generateReadmeBadgeAssets({ rootDir });
  const second = generateReadmeBadgeAssets({ rootDir });

  assert.deepEqual(
    first.map((result: { status: string }) => result.status),
    ["written", "written", "written"],
  );
  assert.deepEqual(
    second.map((result: { status: string }) => result.status),
    ["unchanged", "unchanged", "unchanged"],
  );
  assert.equal(
    fs.existsSync(path.join(rootDir, "assets/badges/bright-builds-requirements-compact.svg")),
    true,
  );
});

test("generateReadmeBadgeAssets check mode fails when an alternate badge is missing", () => {
  const rootDir = mkdtempSync(path.join(tmpdir(), "bright-builds-readme-badges-check-"));

  assert.throws(
    () => generateReadmeBadgeAssets({ check: true, rootDir }),
    /generated artifact is out of date: assets\/badges\/bright-builds-requirements-dark\.svg/u,
  );
});
