---
description: Get or set the babel-fish update policy (auto | nudge | off)
allowed-tools: Bash(npx:*)
argument-hint: "[auto|nudge|off]"
---

Arguments: $ARGUMENTS

- If `$ARGUMENTS` is empty, run `npx --no @theglitchking/babel-fish policy` and report the current policy and config path.
- If `$ARGUMENTS` is one of `auto`, `nudge`, `off`, run `npx --no @theglitchking/babel-fish policy $ARGUMENTS` and confirm the new setting to the user.
- If `$ARGUMENTS` is anything else, tell the user the valid values are `auto`, `nudge`, `off`.

Policies:
- `auto`  — auto-run `npm update @theglitchking/babel-fish` at session start when a newer version is available.
- `nudge` — print a one-liner when a newer version is available (default).
- `off`   — do not check for updates.
