import process from "node:process";
import { formatFlatSiteBadgeResult, generateFlatSiteBadgeArtifact } from "./flat-site-badge.js";

const check = process.argv.includes("--check");
const result = generateFlatSiteBadgeArtifact({ check });
console.log(formatFlatSiteBadgeResult(result));
