# Task Plan: codebase-mapper-plugin

## Goal
Build an installable codebase mapper plugin with automated install flow, iterative generation with grading, and human-readable reports.

## Architecture

```
Plugin Install Triggered
  → install.sh runs automatically
    → 1. Check/install Python (>=3.8)
    → 2. Detect stack (language, framework, infra)
    → 3. Iterative generation loop:
    │     → Run generate.py (produces sections + map)
    │     → Run grader.py (separate script, scores 0-100%)
    │     → Generate human-readable report
    │     → If score >= 90%: PASS → finalize
    │     → If score < 90% and iterations < 3: refine → re-run
    │     → If 3 iterations and still < 90%: finalize with warning
    → 4. Install git hooks
    → 5. Render skill + rules files
    → 6. Print summary with final grade + report path
```

## Key Files

```
codebase-mapper/
├── install.sh                  # Main installer (entry point)
├── scripts/
│   ├── detect-stack.sh         # Auto-detect project stack
│   ├── ensure-python.sh        # Check/install Python
│   └── validate.sh             # Post-install validation
├── templates/
│   ├── generate.py             # Introspection script (copied to target)
│   ├── grader.py               # Separate grading script (scores 0-100%)
│   ├── SKILL.md.template
│   ├── project-vocabulary.md.template
│   └── operational-runbook.md.template
├── plugin-metadata.json        # Marketplace metadata
└── README.md
```

**Installed at target repo:**
```
.claude/
├── project-map/
│   ├── generate.py
│   ├── grader.py
│   ├── PROJECT_MAP.md
│   ├── sections/               # 01-vocabulary.md through 19-doc-pointers.md
│   ├── reports/                # Human-readable iteration reports
│   │   └── install-report.md   # Final report with all iterations
│   ├── checksums.json
│   └── learned-vocabulary.json
├── rules/
│   ├── project-vocabulary.md
│   └── operational-runbook.md
└── skills/
    └── <project>-developer-skill/
        └── SKILL.md
.githooks/
├── pre-commit
└── install.sh
```

## Grading Criteria (grader.py)

| Category | Weight | What It Checks |
|----------|--------|----------------|
| Section completeness | 25% | Expected sections generated for detected stack |
| Vocabulary accuracy | 20% | Entries point to real files that exist |
| Import chain validity | 15% | Chains trace to real modules/files |
| Section size bounds | 10% | Each section 0.1-50KB (not empty, not bloated) |
| Secret safety | 15% | No API keys, passwords, tokens in output |
| Structural integrity | 10% | Valid markdown, proper headings, TOC links work |
| Checksum functionality | 5% | Re-run produces skip (0 changes) |

**Pass threshold: 90%**
**Max iterations: 3**

## Report Format (per iteration)

```markdown
# Codebase Mapper — Installation Report

## Iteration N of 3 | Score: XX%  | PASS/FAIL

### Stack Detection
- Language: ...
- Framework: ...
- Infrastructure: ...

### Scoring Breakdown
| Category | Score | Max | Details |
|----------|-------|-----|---------|
| ...      | ...   | ... | ...     |

### Issues Found
- ❌ [issue description + file/line]

### Improvements Made (iterations 2+)
- ✅ [what was fixed from previous iteration]

### Final Verdict
✅ PASSED (XX%) — Map is production-ready
  or
⚠️  COMPLETED WITH WARNINGS (XX%) — See issues above
```

## Phases
- [x] Phase 1: Discovery (greenfield repo)
- [ ] Phase 2: Build install.sh + ensure-python.sh + detect-stack.sh
- [ ] Phase 3: Build generate.py (stack-agnostic introspection)
- [ ] Phase 4: Build grader.py (separate scoring + reporting)
- [ ] Phase 5: Build templates (skill, vocabulary, runbook)
- [ ] Phase 6: Wire git hooks
- [ ] Phase 7: Plugin metadata + README
- [ ] Phase 8: Update CLAUDE.md
- [ ] Phase 9: Full install test (run install.sh, iterate to 90%+)

## Decisions Made
- Grading: standalone Python script (no Claude dependency at install time)
- Platform: Linux/WSL primary, with macOS fallback in ensure-python.sh
- 90% pass threshold, max 3 iterations
- Reports stored at `.claude/project-map/reports/install-report.md`
- generate.py refines itself between iterations based on grader feedback

## Status
**Currently in Phase 2** — Building installer scripts
