import { installGitHooks } from "./git-hooks.js";

const hooksPath = installGitHooks();
console.log(`Configured repository Git hooks path: ${hooksPath}`);
