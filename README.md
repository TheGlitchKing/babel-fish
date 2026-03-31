# babel-fish

**Technical-to-feature-level human translator with drift management.**

Translates technical implementation details into human-readable feature descriptions while tracking and managing semantic drift over time.

---

## Babel Fish Plugin

babel-fish ships with the **Babel Fish** plugin — a self-updating developer context system that gives any Claude Code session instant, accurate knowledge of every route, model, service, feature, and infrastructure element in a codebase, plus a vocabulary translation layer that maps how humans talk about features to exact file paths.

### What It Does

- **Project map**: Auto-generated index of routes, models, schemas, services, background jobs, frontend features, migrations, auth config, and infrastructure — split into 19 focused sections (2-50KB each) so Claude loads only what's needed per task
- **Vocabulary translator**: Maps plain-English phrases to exact code locations (`"deal pipeline"` → `features/deal-pipeline/DealPipeline.tsx`)
- **Learned vocabulary**: Mines past Claude Code sessions to discover aliases you use naturally, scoring by frequency × recency
- **Operational runbook**: Auto-loaded every session — captures gotchas, deploy procedures, and environment differences that can't be derived from code
- **Self-updating**: Pre-commit hook regenerates the map automatically whenever source files change
- **Quality grading**: Install loop runs up to 3 iterations, grading output 0-100% across 7 categories. Must reach 90% to pass.

### Install

```bash
bash .claude/install.sh
```

That's it. The installer:
1. Checks for Python ≥3.8 (installs if missing)
2. Detects your stack (language, framework, database, ORM, auth, infra)
3. Runs `generate.py` → grades with `grader.py` (iterates until 90%+ or 3 attempts)
4. Renders your developer skill and rules files
5. Installs the pre-commit hook
6. Updates `CLAUDE.md`
7. Prints a full quality report

### Install via Claude Marketplace

```
/plugin install TheGlitchKing/babel-fish
```

### Project Map Structure

```
.claude/
├── project-map/
│   ├── generate.py              # Introspection script — run to regenerate
│   ├── grader.py                # Quality grader — run to re-score
│   ├── PROJECT_MAP.md           # TOC + stats + quick routing guide
│   ├── sections/
│   │   ├── 01-vocabulary.md     # Human language → code location
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
│   ├── reports/
│   │   └── install-report.md    # Quality report with per-iteration scores
│   ├── checksums.json           # Input hash — skip regeneration if unchanged
│   └── learned-vocabulary.json  # Session-mined aliases (persists across runs)
├── rules/
│   ├── project-vocabulary.md    # Auto-loaded every session
│   └── operational-runbook.md   # Auto-loaded every session (edit manually)
└── skills/
    └── <project>-developer-skill/
        └── SKILL.md
.githooks/
├── pre-commit                   # Auto-regenerates map on commit
└── install.sh                   # Register hooks: bash .githooks/install.sh
```

### Using the Developer Skill

After install, a skill is available for your project:

```
/<project-slug>-developer
```

The skill reads `PROJECT_MAP.md` and uses the Quick Routing table to load only the 2-3 sections relevant to your current task — typically 5-20KB of context instead of 100KB+.

### Keeping the Map Current

The pre-commit hook regenerates the map automatically. To force a manual regeneration:

```bash
python .claude/project-map/generate.py --force
```

To re-grade the current output:

```bash
python .claude/project-map/grader.py
```

### Grading Criteria

| Category | Weight | What It Checks |
|----------|--------|----------------|
| Section completeness | 25% | All 19 sections generated |
| Vocabulary accuracy | 20% | Entries map to real files |
| Import chain validity | 15% | Chains trace to real modules |
| Secret safety | 15% | No API keys, passwords, or tokens leaked |
| Section size bounds | 10% | Each section 0.1–50KB |
| Structural integrity | 10% | Valid markdown, working TOC links |
| Checksum functionality | 5% | Re-run skips when nothing changed |

**Pass threshold: 90%**

### Operational Runbook

`.claude/rules/operational-runbook.md` is loaded every session and is meant to grow organically. When you encounter a non-obvious issue, the developer skill will prompt:

> "This looks like operational knowledge worth documenting. Want me to add it to the runbook? (Y/n)"

Entries are short: symptom → cause → fix. This is the anti-drift mechanism — knowledge that can't be derived from code lives here.

### Learned Vocabulary

Every Claude Code session is mined for vocabulary. When you say "the numbers page" and Claude opens `DealAnalyzerV2.tsx`, that alias is recorded with a score (frequency × recency). Aliases with a score ≥5 appear in `17-learned-vocabulary.md` and the vocabulary translator. Scores decay over time; aliases drop after 90 sessions of inactivity.

Run the miner manually:

```bash
python .claude/project-map/mine-sessions.py
```

### Supported Stacks

| Language | Frameworks |
|----------|-----------|
| Python | FastAPI, Django, Flask |
| TypeScript / JavaScript | Next.js, NestJS, Express, React, Vue, Svelte |
| Go | Gin, Echo, Chi, stdlib |
| Java | Spring Boot |
| Any | docker-compose, nginx, Caddy, Terraform, Prisma, SQLAlchemy, TypeORM |

### Requirements

- Claude Code ≥1.0.0
- Python ≥3.8 (auto-installed if missing)
- bash
- Optional: `pip install pyyaml` for docker-compose YAML parsing (regex fallback included)

---

## License

MIT — see [LICENSE](LICENSE)
