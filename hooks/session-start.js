#!/usr/bin/env node
// babel-fish SessionStart hook. Runs the runtime's update check per
// policy (off / nudge / auto). No plugin-specific .mcp.json reconcile.

import { runSessionStart } from "@theglitchking/claude-plugin-runtime";

await runSessionStart({
  packageName: "@theglitchking/babel-fish",
  pluginName: "babel-fish",
  configFile: "babel-fish.json",
});
