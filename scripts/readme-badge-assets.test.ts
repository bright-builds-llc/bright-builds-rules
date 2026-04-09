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
      "assets/badges/bright-builds-rules-dark.svg",
      "assets/badges/bright-builds-rules-light.svg",
      "assets/badges/bright-builds-rules-compact.svg",
    ],
  );
  assert.match(specs[0]?.svg ?? "", /width="225" height="40" viewBox="0 0 225 40"/u);
  assert.match(specs[1]?.svg ?? "", /width="218" height="40" viewBox="0 0 218 40"/u);
  assert.match(specs[2]?.svg ?? "", /width="190" height="36" viewBox="0 0 190 36"/u);
  assert.match(specs[0]?.svg ?? "", /<text x="40" y="19"[^>]*>Bright Builds<\/text>/u);
  assert.match(specs[0]?.svg ?? "", /<text x="40" y="31\.5"[^>]*>RULES<\/text>/u);
  assert.match(
    specs[0]?.svg ?? "",
    /<text x="187\.5" y="20"[^>]*text-anchor="middle"[^>]*dominant-baseline="middle"[^>]*>ACTIVE<\/text>/u,
  );
  assert.match(specs[1]?.svg ?? "", /<text x="40" y="19"[^>]*>Bright Builds<\/text>/u);
  assert.match(specs[1]?.svg ?? "", /<text x="40" y="31\.5"[^>]*>RULES<\/text>/u);
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
    fs.existsSync(path.join(rootDir, "assets/badges/bright-builds-rules-compact.svg")),
    true,
  );
});

test("generateReadmeBadgeAssets check mode fails when an alternate badge is missing", () => {
  const rootDir = mkdtempSync(path.join(tmpdir(), "bright-builds-readme-badges-check-"));

  assert.throws(
    () => generateReadmeBadgeAssets({ check: true, rootDir }),
    /generated artifact is out of date: assets\/badges\/bright-builds-rules-dark\.svg/u,
  );
});
