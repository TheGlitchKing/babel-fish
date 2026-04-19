#!/usr/bin/env node

import { program } from "commander";
import { registerUpdateCommands } from "@theglitchking/claude-plugin-runtime";
import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const require_ = createRequire(import.meta.url);
const { version } = require_("../package.json");

const PKG = "@theglitchking/babel-fish";
const PACKAGE_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const INSTALL_SH = join(PACKAGE_ROOT, ".claude", "install.sh");

function requireBash() {
  const r = spawnSync("bash", ["--version"], { stdio: "ignore" });
  if (r.status !== 0) {
    console.error("  ✗ bash is required but not found.");
    process.exit(1);
  }
}

function runBash(bashArgs, opts = {}) {
  requireBash();
  const r = spawnSync("bash", bashArgs, { stdio: "inherit", ...opts });
  if (r.status !== 0) process.exit(r.status ?? 1);
}

function runRelink(cwd) {
  const linker = join(cwd, "node_modules", "@theglitchking", "babel-fish", "scripts", "link-skills.js");
  const script = existsSync(linker) ? linker : resolve(PACKAGE_ROOT, "scripts", "link-skills.js");
  if (!existsSync(script)) {
    console.error("link-skills.js not found — is the package installed?");
    return;
  }
  spawnSync(process.execPath, [script], {
    cwd,
    env: { ...process.env, INIT_CWD: cwd },
    stdio: "inherit",
  });
}

program
  .name("babel-fish")
  .description("babel-fish — gives your AI assistant instant codebase context")
  .version(version);

registerUpdateCommands(program, {
  packageName: PKG,
  pluginName: "babel-fish",
  configFile: "babel-fish.json",
  onAfterUpdate: (cwd) => runRelink(cwd),
});

program
  .command("init [path]")
  .description("Install babel-fish into a project (default: current dir)")
  .action((path) => {
    const target = path || process.cwd();
    console.log(`\n  babel-fish init → ${target}\n`);
    runBash([INSTALL_SH, target]);
  });

program
  .command("dry-run [path]")
  .description("Preview all changes without applying them")
  .action((path) => {
    const target = path || process.cwd();
    runBash([INSTALL_SH, "--dry-run", target]);
  });

program
  .command("regen")
  .description("Force-regenerate the project map")
  .action(() => {
    const generatePy = join(process.cwd(), ".claude", "project-map", "generate.py");
    if (!existsSync(generatePy)) {
      console.error("  ✗ .claude/project-map/generate.py not found. Run `babel-fish init` first.");
      process.exit(1);
    }
    const r = spawnSync("python3", [generatePy, "--force"], { stdio: "inherit" });
    process.exit(r.status ?? 0);
  });

program
  .command("grade")
  .description("Grade the current project map quality")
  .action(() => {
    const graderPy = join(process.cwd(), ".claude", "project-map", "grader.py");
    if (!existsSync(graderPy)) {
      console.error("  ✗ .claude/project-map/grader.py not found. Run `babel-fish init` first.");
      process.exit(1);
    }
    const r = spawnSync("python3", [graderPy], { stdio: "inherit" });
    process.exit(r.status ?? 0);
  });

program.parse();
