import process from "node:process";
import {
  checkContextCost,
  stageContextCostPaths,
  updateContextCost,
} from "./context-cost.js";

const args = process.argv.slice(2);
const command = args[0];
const baseRefIndex = args.indexOf("--base-ref");
const maybeBaseRef = baseRefIndex >= 0 ? args[baseRefIndex + 1] : undefined;

if (baseRefIndex >= 0 && maybeBaseRef === undefined) {
  throw new Error("--base-ref requires a Git revision");
}

switch (command) {
  case "update": {
    const result = updateContextCost();
    console.log(
      `Context cost ${result.historyChanged || result.readmeChanged ? "updated" : "unchanged"}: ${result.row.adoptionPathEstimatedTokens} estimated adoption-path tokens`,
    );
    break;
  }
  case "check": {
    const row = checkContextCost({ maybeBaseRef });
    console.log(
      `Context cost verified: ${row.adoptionPathEstimatedTokens} estimated adoption-path tokens`,
    );
    break;
  }
  case "precommit": {
    const result = updateContextCost();
    stageContextCostPaths();
    checkContextCost();
    console.log(
      `Context cost staged and verified: ${result.row.adoptionPathEstimatedTokens} estimated adoption-path tokens`,
    );
    break;
  }
  default:
    throw new Error("usage: bun scripts/manage-context-cost.ts update|check|precommit");
}
