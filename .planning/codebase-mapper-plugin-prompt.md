# Codebase Mapper Plugin — LLM Bootstrap Prompt

> Drop this prompt into a new Claude Code session on ANY repository.
> It will build a developer skill with a project map, vocabulary translation layer,
> and git hooks that keep everything current on every commit.

## Glitch Kingdom Plugin Marketplace

This plugin is designed for distribution via the [Glitch Kingdom of Plugins](https://github.com/TheGlitchKing/glitch-kingdom-of-plugins) marketplace. After building the plugin for a target repo, it should also be packageable as a standalone Claude plugin (`type: "claude-plugin"`) conforming to the marketplace's `plugin-schema.json`.

### Marketplace Entry

When publishing to the marketplace, the plugin entry in `marketplace.json` should follow this structure:

```json
{
  "id": "codebase-mapper",
  "name": "codebase-mapper",
  "displayName": "Codebase Mapper",
  "type": "claude-plugin",
  "version": "1.0.0",
  "description": "Auto-generates a project map, vocabulary translation layer, and developer skill for any codebase. Introspects routes, models, services, features, infrastructure, and session history to give Claude instant full-stack context. Self-updates via pre-commit hook.",
  "author": {
    "name": "TheGlitchKing"
  },
  "repository": {
    "type": "github",
    "owner": "TheGlitchKing",
    "repo": "codebase-mapper",
    "url": "https://github.com/TheGlitchKing/codebase-mapper"
  },
  "source": {
    "type": "submodule",
    "path": "plugins/codebase-mapper"
  },
  "installation": {
    "methods": [
      {
        "type": "claude-marketplace",
        "command": "/plugin install TheGlitchKing/codebase-mapper"
      },
      {
        "type": "manual",
        "steps": [
          "Clone or copy the plugin into your project",
          "Run: python .claude/project-map/generate.py",
          "Run: .githooks/install.sh"
        ]
      }
    ],
    "requirements": {
      "claude-code": ">=1.0.0",
      "python": ">=3.8",
      "bash": true,
      "optional": {
        "pyyaml": "For YAML parsing (falls back to regex)"
      }
    }
  },
  "category": "developer-tools",
  "tags": ["codebase-context", "project-map", "vocabulary", "developer-skill", "introspection"],
  "keywords": ["project map", "codebase mapper", "vocabulary translation", "developer context", "code introspection", "auto-generated docs"],
  "license": "MIT",
  "homepage": "https://github.com/TheGlitchKing/codebase-mapper",
  "status": "production-ready",
  "features": {
    "hooks": ["pre-commit (auto-regenerate project map)"],
    "skills": ["<project-slug>-developer-skill"],
    "commands": []
  },
  "compatibility": {
    "claude-code": ">=1.0.0"
  }
}
```

### Plugin Structure for Distribution

When packaged as a standalone plugin repo, the structure should be:

```
codebase-mapper/
├── README.md                    # Installation + usage guide
├── LICENSE                      # MIT
├── install.sh                   # One-command installer (copies files, runs generate.py, installs hooks)
├── plugin-metadata.json         # Marketplace-compatible metadata
├── templates/
│   ├── generate.py              # The introspection script (stack-agnostic)
│   ├── SKILL.md.template        # Skill template with {{placeholders}}
│   ├── project-vocabulary.md.template
│   ├── operational-runbook.md.template
│   └── pre-commit.sh            # Git hook snippet
└── scripts/
    ├── detect-stack.sh           # Auto-detect project stack (Python/TS/Go/Java/etc.)
    └── validate.sh              # Post-install validation
```

The `install.sh` script should:
1. Detect the project stack via `detect-stack.sh`
2. Copy `generate.py` to `.claude/project-map/`
3. Render skill + rules templates with detected project name/stack
4. Install the git hook (append to existing pre-commit or create new)
5. Run `generate.py` for initial map generation
6. Run `validate.sh` to confirm sections were generated
7. Print a summary of what was created

---

## Prompt

You are a codebase cartographer. Your job is to build a self-updating developer context system for this repository — a "project map" that gives any future LLM session instant, accurate knowledge of every route, model, service, feature, component, and infrastructure element in this codebase, plus a vocabulary translation layer that maps how humans talk about features to exact file paths.

### What You Will Build

```
.claude/
├── project-map/
│   ├── generate.py              # Python introspection script (~2000 lines)
│   ├── PROJECT_MAP.md           # Auto-generated TOC (~2-3KB, points to sections)
│   ├── sections/                # Split output files (2-50KB each)
│   │   ├── 01-vocabulary.md     # Human language → code location mapping
│   │   ├── 02-service-topology.md
│   │   ├── 03-environment.md
│   │   ├── 04-api-routes.md
│   │   ├── 05-data-models.md
│   │   ├── 06-schemas.md
│   │   ├── 07-services.md
│   │   ├── 08-background-jobs.md
│   │   ├── 09-frontend-features.md
│   │   ├── 10-tools-commands.md
│   │   ├── 11-migrations.md
│   │   ├── 12-import-chains.md
│   │   ├── 13-frontend-backend-map.md
│   │   ├── 14-reverse-proxy.md
│   │   ├── 15-auth-config.md
│   │   ├── 16-infra-profile.md
│   │   ├── 17-learned-vocabulary.md
│   │   ├── 18-dead-code.md
│   │   └── 19-doc-pointers.md
│   ├── checksums.json           # Input hash for skip-if-unchanged
│   └── learned-vocabulary.json  # Session-mined aliases (persists across regenerations)
├── rules/
│   ├── project-vocabulary.md    # Concise feature→code table (auto-loaded every session)
│   └── operational-runbook.md   # Hand-curated ops knowledge (auto-loaded every session)
├── skills/
│   └── <project>-developer-skill/
│       └── SKILL.md             # Skill that routes to project map sections
└── agents.json                  # Optional: trigger keywords for auto-invocation
```

### Phase 1: Discover the Codebase

Before writing any code, explore this repository thoroughly:

1. **Detect the stack** — What language(s)? What frameworks? What package manager? What database? What ORM? What auth system? What message queue? What cache? Containerized with what?

2. **Detect project structure patterns**:
   - Backend: Look for routers/controllers, models, schemas/DTOs, services, middleware, tasks/jobs, migrations
   - Frontend: Look for features/pages, components, hooks, stores, API service files, route definitions
   - Infrastructure: docker-compose files, CI configs, deploy scripts, env files, nginx/caddy configs
   - Docs: Any documentation directory

3. **Detect conventions**:
   - Python: Are models SQLAlchemy? Django ORM? Prisma? Do routers use decorators (`@router.get`)?
   - JS/TS: React? Vue? Angular? Next.js? Feature-based dirs? Barrel exports?
   - Go: Standard library? Gin? Echo? Chi?
   - Java: Spring Boot? Jakarta?

4. **Map dependencies**: What services depend on what? What ports? What health checks?

Record your findings before proceeding.

### Phase 2: Build generate.py

Write `generate.py` at `.claude/project-map/generate.py`. This is a **pure Python script** (no external dependencies except PyYAML if available, with regex fallback). It must:

#### Core Parsers (adapt to detected stack)

**For Python backends (FastAPI, Django, Flask):**
- **Router/View parser**: Use `ast` module to parse decorators (`@router.get`, `@app.route`, `@api_view`), extract method, path, auth dependencies, response models, file:line
- **Model parser**: Use `ast` to find ORM classes (SQLAlchemy `Column()`, Django `models.Field()`), extract table name, columns with types/nullable/FK/index, relationships
- **Schema parser**: Use `ast` to find Pydantic `BaseModel` or serializer classes, extract fields with types
- **Service parser**: Use `ast` to find service classes, extract public methods, constructor dependencies

**For TypeScript/JavaScript backends (Express, NestJS, Next.js API):**
- **Route parser**: Regex for `router.get/post`, `@Get()/@Post()`, `export async function GET/POST`
- **Model parser**: Regex for Prisma schema, TypeORM entities, Mongoose schemas
- **Service parser**: Regex for class exports with methods

**For Go backends:**
- **Route parser**: Regex for `r.HandleFunc`, `e.GET`, `router.GET`
- **Model parser**: Regex for struct definitions with db tags
- **Handler parser**: Regex for handler function signatures

**For all stacks:**
- **Docker-compose parser**: YAML (or regex fallback) for services, ports, depends_on, health checks, resource limits
- **Env parser**: Key=value from `.env*` files (NEVER include secret values — only key names and non-secret config like providers, feature flags)
- **Frontend feature scanner**: Directory walk of feature/page dirs — count components, hooks, stores, API files
- **Tools & commands discovery**: Scan for available CLIs, scripts, npm/poetry/cargo scripts, skills
- **Migration parser**: Extract revision chain, tables affected per migration

#### Relationship Tracers

- **Import chain tracer**: Follow imports from route → service → model → table. Output as `Route → Service.method → Model → table_name`
- **Frontend → Backend matcher**: Match frontend API service URLs to backend route paths
- **Reverse proxy parser**: Parse nginx/caddy/traefik configs for location → upstream mappings

#### Vocabulary Translation Layer

This is the key innovation. Build a table that maps **how humans talk about features** to **exact code locations**:

**Source 1 — Code-derived aliases (always available):**
- Feature directory name → primary alias (`features/properties/` → "property search", "properties")
- Component names → UI aliases (`DealPipeline.tsx` → "deal pipeline", "kanban board")
- Router/controller names → API aliases (`property_search.py` → "property search API")
- Service class names → system aliases (`DocumentService` → "document handler", "doc management")
- Model class names → data aliases (`PropertyListing` → "property listing", "listing")
- README/docs mentions → product aliases (scan for feature names in docs)

**Source 2 — Session-mined aliases (learned over time):**
- Parse Claude Code conversation JSONL files from `~/.claude/projects/<project-slug>/`
- Extract user messages, match to subsequent Read/Edit/Grep tool calls
- Pattern: user said "the numbers page" → Claude opened `DealAnalyzerV2.tsx` = learned alias
- Score: `frequency × recency_weight` (1.0 for last 30 sessions, decay to 0.25, drop after 90)
- Store in `learned-vocabulary.json` with per-alias metadata (count, last_seen, targets)
- Minimum score of 5 to appear in output (filters one-off mentions)

**Merge strategy:** Code-derived aliases are baseline. Session-mined aliases add net-new vocabulary and reinforce existing mappings. Code-derived wins on conflicts (canonical names).

**Dead Code Detection:** Cross-reference vocabulary decay (score below threshold) + file still exists + no recent git commits (`git log --since="3 months ago" -- <file>`) → flag in Dead Code Candidates section for human review.

#### Output Format

Split the output into **section files** under `sections/`. Each section is a self-contained markdown file (2-50KB). The main `PROJECT_MAP.md` is just a table of contents (~2-3KB) with:
- Stats line (route count, model count, etc.)
- Section index table (filename, size, when-to-read guidance)
- Quick routing table (question type → which sections to read)

This split is critical — it lets the skill load only 5-20KB for any given task instead of 100KB+.

#### Checksums

Hash all input files (mtimes + file list). Store in `checksums.json`. Skip regeneration if hash matches. This makes the pre-commit hook cost 0s when nothing changed and <5s when something did.

### Phase 3: Build the Vocabulary Rules File

Create `.claude/rules/project-vocabulary.md` — a concise (~2-5KB) file that's auto-loaded every session. Structure:

```markdown
# <Project Name> — Project Vocabulary

> Auto-loaded every session. Maps human language to exact code locations.

## Feature → Code Location

| You Say | Frontend | Backend | Model/Table |
|---------|----------|---------|-------------|
| <feature alias> | <frontend path> | <backend path> → <Service> | <Model> → `<table>` |
...

## Infrastructure Vocabulary

| You Say | What It Is | Key Details |
|---------|-----------|-------------|
| <infra alias> | <description> | <ports, constraints, gotchas> |
...

## Quick Actions

| You Say | What To Do |
|---------|-----------|
| <action phrase> | <exact command> |
...
```

### Phase 4: Seed the Operational Runbook

Create `.claude/rules/operational-runbook.md` — this is where ops knowledge lives that can't be derived from code (environment differences, known gotchas, deploy procedures, platform quirks).

**For new/greenfield projects**, seed it with a minimal scaffold and discovery prompts:

```markdown
# <Project Name> — Operational Runbook

> Auto-loaded every session. Contains operational knowledge that cannot be derived from code.
> This file grows over time as the team discovers gotchas, quirks, and procedures.

## Environment Differences

<!-- TODO: Document how dev/staging/prod differ (DB, deploy method, secrets, URLs) -->
<!-- Suggestion: Run the project locally, note any setup friction, and document it here -->

| | Dev | Staging | Production |
|---|---|---|---|
| **URL** | | | |
| **Database** | | | |
| **Deploy** | | | |
| **Secrets** | | | |

## Known Issues & Workarounds

<!-- This section fills in naturally. When you hit a non-obvious issue, add it here. -->
<!-- Examples: "HMR doesn't work on WSL2", "port 6543 breaks migrations" -->

_No known issues documented yet. When you encounter a non-obvious problem and its solution, add it here so future sessions don't re-discover it._

## Deploy Procedures

<!-- TODO: Document how to deploy to each environment -->

## Key Commands

<!-- TODO: Add frequently-used commands that aren't obvious from package.json/Makefile -->

## Dev Credentials

<!-- Add test/dev credentials here (NEVER production secrets) -->
```

**For established projects**, populate it by reading existing READMEs, docker-compose files, deploy scripts, and CI configs. Extract operational knowledge that isn't obvious from code alone.

**Runbook growth strategy:** The runbook should grow organically during normal work. When configuring the skill, also add this behavior to the skill's instructions:

> When you encounter or help resolve a non-obvious operational issue (a platform quirk,
> a workaround, a "this silently fails unless you do X" situation), suggest adding it
> to the operational runbook:
>
> "This looks like operational knowledge that could save time in future sessions.
> Want me to add it to the runbook? (Y/n)"
>
> The user can decline — this is a suggestion, not a requirement. If they agree,
> append a concise entry to `.claude/rules/operational-runbook.md` under the
> appropriate section. Keep entries short (2-4 lines: symptom, cause, fix).

### Phase 5: Build the Developer Skill

Create `.claude/skills/<project-slug>-developer-skill/SKILL.md`:

```markdown
---
name: <project-slug>-developer-skill
description: |
  <2-3 sentence description of what this project is, what the skill provides,
  and when to invoke it. Mention the project map, vocabulary translator,
  and any non-standard infrastructure.>
---

# /<project-slug>-developer — <Project Name> Developer Context

You are a full-stack developer working on <Project Name>. You have complete
knowledge of every route, model, service, feature, and infrastructure component
because this skill gives you an auto-generated project map.

## On Trigger — Load Only What You Need

The project map is split into section files at `.claude/project-map/sections/`.
Do NOT read them all. Start with:

```
Read: .claude/project-map/PROJECT_MAP.md
```

Use the Quick Routing table to pick which 2-3 sections to load.

## Section Routing

| Task | Read These Sections |
|------|-------------------|
| Feature/UX work | 01-vocabulary → 09-frontend → 04-routes |
| Add a model/field | 05-models → 06-schemas → 12-import-chains |
| Troubleshoot error | 02-topology → 03-environment → 14-proxy |
| Infrastructure/scaling | 16-infra-profile → 02-topology |
| Auth/security | 15-auth-config → 19-doc-pointers |
| What tools exist | 10-tools-commands |

## Platform Quick Reference

- **Stack**: <detected stack summary>
- **Dev URL**: <dev URL>
- **Test credentials**: <if applicable>

## Keeping the Map Current

Regenerates automatically via pre-commit hook. Force: `python .claude/project-map/generate.py --force`

## Growing the Runbook

When you encounter or help resolve a non-obvious operational issue — a platform
quirk, a silent failure, a "you have to do X before Y" situation — suggest adding
it to the runbook:

> "This looks like operational knowledge worth documenting. Want me to add it
> to the runbook? (Y/n)"

This is a suggestion, not automatic. If the user agrees, append a concise entry
(symptom → cause → fix) to `.claude/rules/operational-runbook.md`.
```

### Phase 6: Wire the Git Hooks

Add to the pre-commit hook (create `.githooks/pre-commit` or append to existing):

```bash
# Regenerate PROJECT_MAP.md if relevant files changed
STAGED_FILES=$(git diff --cached --name-only)
EXTENSIONS_PATTERN='\.(py|ts|tsx|js|jsx|go|java|yaml|yml)$|docker-compose|package\.json|Cargo\.toml|go\.mod'

if echo "$STAGED_FILES" | grep -qE "$EXTENSIONS_PATTERN"; then
    if [ -f ".claude/project-map/generate.py" ]; then
        PYTHON_CMD=""
        if [ -f ".venv/bin/python3" ]; then
            PYTHON_CMD=".venv/bin/python3"
        elif command -v python3 &>/dev/null; then
            PYTHON_CMD="python3"
        elif command -v python &>/dev/null; then
            PYTHON_CMD="python"
        fi

        if [ -n "$PYTHON_CMD" ]; then
            echo "Regenerating PROJECT_MAP.md..."
            $PYTHON_CMD .claude/project-map/generate.py 2>/dev/null
            if [ $? -eq 0 ]; then
                git add .claude/project-map/PROJECT_MAP.md .claude/project-map/checksums.json 2>/dev/null
                git add .claude/project-map/sections/*.md 2>/dev/null
                [ -f .claude/project-map/learned-vocabulary.json ] && \
                    git add .claude/project-map/learned-vocabulary.json 2>/dev/null
            fi
        fi
    fi
fi
```

Create a hook installer at `.githooks/install.sh`:

```bash
#!/bin/bash
git config core.hooksPath .githooks
chmod +x .githooks/*
echo "Git hooks installed (using .githooks/ directory)"
```

### Phase 7: Update CLAUDE.md

Add a pointer in CLAUDE.md (create it if it doesn't exist):

```markdown
**Project Map**: For any project-specific question, read
[`.claude/project-map/PROJECT_MAP.md`](.claude/project-map/PROJECT_MAP.md) —
auto-generated index of N routes, N models, import chains, infra profile,
and vocabulary translator.
```

### Phase 8: Validate

1. Run `generate.py` — confirm it completes without errors
2. Check stats: routes, models, services, features should all be non-zero for the detected stack
3. Spot-check 3-5 vocabulary entries — do they map to real files?
4. Spot-check 3-5 import chains — do they trace correctly?
5. Run `generate.py` again — confirm checksums skip (0s)
6. Modify a source file, run again — confirm it regenerates

### Critical Design Principles

1. **Zero external dependencies** — generate.py uses only stdlib (`ast`, `json`, `re`, `hashlib`, `pathlib`, `subprocess`). Optional PyYAML with regex fallback.

2. **AST over regex for Python** — regex breaks on multiline decorators, nested calls, string interpolation. `ast` is reliable. Use regex only for non-Python files.

3. **Never include secrets** — parse `.env` for key names and non-sensitive config (DB_PROVIDER=supabase, STORAGE_PROVIDER=s3) but NEVER include API keys, passwords, or tokens.

4. **Section splitting is mandatory** — a 100KB monolith wastes context. Split into 2-50KB sections so the skill loads only what's needed per task (5-20KB typical).

5. **Vocabulary is code-derived, not hand-written** — if an alias doesn't map to code that exists, it shouldn't be in the vocabulary. This is the anti-drift guarantee.

6. **Checksums for speed** — the pre-commit hook must cost <1s when nothing changed. Hash inputs, skip if unchanged.

7. **Stack-agnostic parsers** — detect the stack first, then activate the right parser set. A Python project doesn't need Go parsers. A Next.js monorepo doesn't need FastAPI parsers.

8. **Learned vocabulary is additive** — session-mined aliases supplement code-derived ones. They're stored separately in `learned-vocabulary.json` so they survive full regenerations. They decay naturally via frequency × recency scoring.

9. **PROJECT_MAP.md is committed to git** — it's versioned, visible in PRs, and available to any team member or CI pipeline that reads CLAUDE.md.

10. **Rules files are auto-loaded** — anything in `.claude/rules/` is loaded every session without explicit triggers. Put the vocabulary and runbook there for zero-cost context.

### Begin

Start by exploring this repository. Identify the stack, project structure, conventions, and infrastructure. Then proceed through the phases in order. Ask me questions if anything about the codebase is ambiguous.
