import process from "node:process";
import { formatReadmeBadgeAssetResults, generateReadmeBadgeAssets } from "./readme-badge-assets.js";

const check = process.argv.includes("--check");
const results = generateReadmeBadgeAssets({ check });
console.log(formatReadmeBadgeAssetResults(results));
