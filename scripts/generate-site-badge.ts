import process from "node:process";
import { formatSiteBadgeResult, generateSiteBadgeArtifact } from "./site-badge.js";

const check = process.argv.includes("--check");
const result = generateSiteBadgeArtifact({ check });
console.log(formatSiteBadgeResult(result));
