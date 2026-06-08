# Changelog

All notable changes to this project will be documented in this file.

## [2.0.2] - 2026-06-08

### Fixed

- Internal lint cleanup in `generate.py`: removed an unused `os` import and
  two unused local variables, and dropped the `f` prefix from five
  placeholder-less f-strings (ruff F401/F841/F541). No behavior change.

## [2.0.1] - 2026-06-08

### Fixed

- **Frontend feature scanner now detects monorepo layouts.** `FrontendScanner`
  previously looked for `features/`, `pages/`, `views/`, etc. only at the repo
  root or under a top-level `src/`. Projects that keep the frontend in a
  subpackage (e.g. `frontend/src/features/`, the common React/Vite plus Python
  backend split) were reported as "No frontend feature directories detected,"
  leaving project-map sections 09 (Frontend Features) and 13 (Frontend to
  Backend Map) empty. The scanner now searches `frontend/`, `web/`, `client/`,
  and `ui/` (each with an optional `src/`) in addition to the repo root and
  `src/`, dedupes by resolved path, and only emits directories that actually
  contain `.jsx`/`.tsx` files so a backend package named `app/` is not
  misclassified as a frontend feature.

## [2.0.0] — 2026-04-19

### Breaking changes

- **Package is now ESM (`"type": "module"`).** If anything imports from
  `@theglitchking/babel-fish` via `require()` (the package has no `main`,
  so this is unlikely), you'll need to switch to `import`. The CLI
  (`npx @theglitchking/babel-fish <cmd>`) is unaffected.
- **Node >= 20** (was >= 16). Matches the rest of the Glitch Kingdom
  plugin ecosystem and the runtime.
- CLI is now `commander`-based. Subcommands, flags, and arguments
  behave the same as before — `init`, `dry-run`, `regen`, `grade`, and
  `help` all work identically — but you now also get `--help` and
  `--version` on every subcommand.

### Migration

No user-facing code changes required — just:

```bash
npm install @theglitchking/babel-fish@latest

# Or if you used the curl|bash installer (unaffected):
curl -sSL https://raw.githubusercontent.com/TheGlitchKing/babel-fish/main/install.sh | bash
```

Your existing `.claude/project-map/` infrastructure and `.githooks/pre-commit`
keep working — this release doesn't touch them. The only net-new files
added to your project are `.claude/babel-fish.json` (update policy —
defaults to `nudge`) and a SessionStart hook entry in
`.claude/settings.json` (only if that file exists and the plugin
marketplace version isn't already handling it).

### Added

- Adopts
  [`@theglitchking/claude-plugin-runtime`](https://github.com/TheGlitchKing/claude-plugin-runtime)
  (`^0.1.0`) for standardized update management and postinstall wiring.
- **Postinstall** (`scripts/link-skills.js`) symlinks
  `skills/babel-fish-developer-skill/` into `<project>/.claude/skills/`
  so Claude Code picks it up automatically. If you later run
  `npx @theglitchking/babel-fish init`, the install script's `cp`
  replaces the symlink with a regular copy — either way the skill is
  discoverable.
- **SessionStart hook** (`hooks/session-start.js`) checks npm for a
  newer version at session start and acts per policy (off / nudge /
  auto). Default is `nudge` — a one-liner notification, no automatic
  changes.
- **Slash + CLI subcommands:**
  - `/babel-fish:update` / `babel-fish update`
  - `/babel-fish:policy [auto|nudge|off]` / `babel-fish policy`
  - `/babel-fish:status` / `babel-fish status`
  - `/babel-fish:relink` / `babel-fish relink`

### Opt-outs

| Variable | Effect |
|---|---|
| `BABEL_FISH_UPDATE_POLICY` | One-shot policy override |
| `BABEL_FISH_SKIP_LINK=1` | Skip skill symlinking in postinstall |
| `BABEL_FISH_SKIP_HOOK_REGISTER=1` | Skip writing the SessionStart hook into `.claude/settings.json` |

---

## [1.0.2] and earlier

See git history:
https://github.com/TheGlitchKing/babel-fish/commits/main
