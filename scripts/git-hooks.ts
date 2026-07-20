import { spawnSync } from "node:child_process";

export const installGitHooks = (rootDir = process.cwd()): string => {
  const result = spawnSync(
    "git",
    ["-C", rootDir, "config", "--local", "core.hooksPath", ".githooks"],
    { encoding: "utf8" },
  );

  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    throw new Error(`unable to configure Git hooks: ${result.stderr.trim()}`);
  }

  return ".githooks";
};
