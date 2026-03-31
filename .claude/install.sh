#!/bin/bash
# ============================================================
# Codebase Mapper Plugin — Installer
# Triggered automatically on plugin installation.
#
# What this does:
#   1. Checks / installs Python >= 3.8
#   2. Detects project stack
#   3. Runs generate.py → grades with grader.py (up to 3 iterations)
#   4. Renders skill + rules files from templates
#   5. Installs git hooks
#   6. Prints a final summary with the grade report path
#
# Usage:
#   bash .claude/install.sh [project-root]
# ============================================================

set -euo pipefail

PROJECT_ROOT="${1:-$(pwd)}"
CLAUDE_DIR="$PROJECT_ROOT/.claude"
MAP_DIR="$CLAUDE_DIR/project-map"
REPORTS_DIR="$MAP_DIR/reports"
SCRIPTS_DIR="$CLAUDE_DIR/scripts"
TEMPLATES_DIR="$CLAUDE_DIR/templates"

MAX_ITERATIONS=3
PASS_THRESHOLD=90
PREVIOUS_SCORE=""

# ── Colors ───────────────────────────────────────────────────────────────────
CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'
BOLD='\033[1m'; RESET='\033[0m'

banner() { printf '\n%b\n' "${CYAN}${BOLD}══ $* ══${RESET}"; }
step()   { printf '%b\n' "${CYAN}▶ $*${RESET}"; }
ok()     { printf '%b\n' "${GREEN}✓ $*${RESET}"; }
warn()   { printf '%b\n' "${YELLOW}⚠ $*${RESET}"; }
fail()   { printf '%b\n' "${RED}✗ $*${RESET}"; }
info()   { printf '%b\n' "  ${RESET}$*"; }

# ── Header ────────────────────────────────────────────────────────────────────
clear
printf '%b\n' "
${CYAN}${BOLD}
  ╔══════════════════════════════════════════╗
  ║     Codebase Mapper Plugin Installer     ║
  ║     by TheGlitchKing                     ║
  ╚══════════════════════════════════════════╝
${RESET}"

info "Project root: $PROJECT_ROOT"
info "Timestamp:    $(date '+%Y-%m-%d %H:%M:%S')"
echo

# ── Step 1: Ensure Python ─────────────────────────────────────────────────────
banner "Step 1: Python"

if [ ! -f "$SCRIPTS_DIR/ensure-python.sh" ]; then
    fail "ensure-python.sh not found at $SCRIPTS_DIR/ensure-python.sh"
    exit 2
fi

PYTHON_CMD=$(bash "$SCRIPTS_DIR/ensure-python.sh")
if [ -z "$PYTHON_CMD" ]; then
    fail "Could not find or install Python >= 3.8"
    exit 2
fi

ok "Python: $($PYTHON_CMD --version 2>&1)"

# ── Step 2: Detect Stack ──────────────────────────────────────────────────────
banner "Step 2: Stack Detection"

STACK_JSON="$MAP_DIR/stack.json"
mkdir -p "$MAP_DIR"

if [ -f "$SCRIPTS_DIR/detect-stack.sh" ]; then
    bash "$SCRIPTS_DIR/detect-stack.sh" "$PROJECT_ROOT" > "$STACK_JSON" 2>/dev/null || true
    if [ -f "$STACK_JSON" ] && python3 -c "import json; json.load(open('$STACK_JSON'))" 2>/dev/null; then
        LANG=$(python3 -c "import json; d=json.load(open('$STACK_JSON')); print(d.get('language','unknown'))")
        FRAMEWORK=$(python3 -c "import json; d=json.load(open('$STACK_JSON')); print(d.get('framework','unknown'))")
        NAME=$(python3 -c "import json; d=json.load(open('$STACK_JSON')); print(d.get('name','project'))")
        SLUG=$(python3 -c "import json; d=json.load(open('$STACK_JSON')); print(d.get('slug','project'))")
        ok "Detected: $NAME ($LANG / $FRAMEWORK)"
    else
        warn "Stack detection returned invalid JSON — using defaults"
        NAME=$(basename "$PROJECT_ROOT")
        SLUG=$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')
        LANG="unknown"
        FRAMEWORK="unknown"
    fi
else
    warn "detect-stack.sh not found — using defaults"
    NAME=$(basename "$PROJECT_ROOT")
    SLUG=$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')
    LANG="unknown"
    FRAMEWORK="unknown"
fi

# ── Step 3: Iterative Generation + Grading ────────────────────────────────────
banner "Step 3: Generate → Grade (up to $MAX_ITERATIONS iterations)"

mkdir -p "$REPORTS_DIR"
FINAL_SCORE=0
FINAL_PASSED=false
ITERATION=0

for ITERATION in $(seq 1 $MAX_ITERATIONS); do
    echo
    step "Iteration $ITERATION / $MAX_ITERATIONS"
    echo

    # Run generate.py
    step "Running generate.py..."
    if ! $PYTHON_CMD "$MAP_DIR/generate.py" --force \
            --project-root "$PROJECT_ROOT" \
            --stack-json "$STACK_JSON" 2>&1; then
        warn "generate.py exited with errors (continuing to grade what was produced)"
    fi

    # Run grader.py
    step "Running grader.py..."
    GRADE_ARGS="--iteration $ITERATION --total $MAX_ITERATIONS --project-root $PROJECT_ROOT"
    if [ -n "$PREVIOUS_SCORE" ]; then
        GRADE_ARGS="$GRADE_ARGS --previous-score $PREVIOUS_SCORE"
    fi

    set +e
    $PYTHON_CMD "$MAP_DIR/grader.py" $GRADE_ARGS
    GRADE_EXIT=$?
    set -e

    # Read score from JSON
    SCORE_JSON="$REPORTS_DIR/iteration-$(printf '%02d' $ITERATION)-score.json"
    if [ -f "$SCORE_JSON" ]; then
        FINAL_SCORE=$($PYTHON_CMD -c "import json; d=json.load(open('$SCORE_JSON')); print(d['score'])")
        PASSED=$($PYTHON_CMD -c "import json; d=json.load(open('$SCORE_JSON')); print(d['passed'])")
    else
        FINAL_SCORE=0
        PASSED="False"
    fi

    PREVIOUS_SCORE="$FINAL_SCORE"

    if [ "$PASSED" = "True" ]; then
        FINAL_PASSED=true
        ok "Score: $FINAL_SCORE% — PASSED ✓ (>= ${PASS_THRESHOLD}%)"
        break
    else
        warn "Score: $FINAL_SCORE% — below ${PASS_THRESHOLD}% threshold"
        if [ "$ITERATION" -lt "$MAX_ITERATIONS" ]; then
            step "Attempting improvements for iteration $((ITERATION + 1))..."
            _improve_for_next_iteration "$SCORE_JSON" "$MAP_DIR" "$PYTHON_CMD"
        fi
    fi
done

# ── Step 4: Render Templates ──────────────────────────────────────────────────
banner "Step 4: Render Skills & Rules"

RULES_DIR="$CLAUDE_DIR/rules"
SKILLS_DIR="$CLAUDE_DIR/skills/${SLUG}-developer-skill"
mkdir -p "$RULES_DIR" "$SKILLS_DIR"

# Render vocabulary rules
_render_vocabulary "$PROJECT_ROOT" "$NAME" "$LANG" "$FRAMEWORK" "$RULES_DIR"

# Render operational runbook
_render_runbook "$PROJECT_ROOT" "$NAME" "$RULES_DIR"

# Render developer skill
_render_skill "$PROJECT_ROOT" "$NAME" "$SLUG" "$LANG" "$FRAMEWORK" "$SKILLS_DIR"

ok "Rules and skill files rendered"

# ── Step 5: Git Hooks ─────────────────────────────────────────────────────────
banner "Step 5: Git Hooks"

HOOKS_DIR="$PROJECT_ROOT/.githooks"
mkdir -p "$HOOKS_DIR"

_install_git_hooks "$PROJECT_ROOT" "$HOOKS_DIR" "$MAP_DIR" "$PYTHON_CMD"
ok "Git hooks installed"

# ── Step 6: Update CLAUDE.md ──────────────────────────────────────────────────
banner "Step 6: Update CLAUDE.md"

_update_claude_md "$PROJECT_ROOT" "$NAME" "$MAP_DIR"

# ── Step 7: Final Validation ──────────────────────────────────────────────────
banner "Step 7: Validation"

if [ -f "$SCRIPTS_DIR/validate.sh" ]; then
    bash "$SCRIPTS_DIR/validate.sh" "$PROJECT_ROOT" || true
else
    warn "validate.sh not found — skipping validation"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo
printf '%b\n' "${CYAN}${BOLD}══════════════════════════════════════════════════${RESET}"
printf '%b\n' "${BOLD}  Installation Complete${RESET}"
printf '%b\n' "${CYAN}══════════════════════════════════════════════════${RESET}"
echo

if [ "$FINAL_PASSED" = "true" ]; then
    printf '%b\n' "  ${GREEN}${BOLD}✓ PASSED${RESET} — Score: ${GREEN}${FINAL_SCORE}%${RESET}"
else
    printf '%b\n' "  ${YELLOW}${BOLD}⚠ COMPLETED WITH WARNINGS${RESET} — Score: ${YELLOW}${FINAL_SCORE}%${RESET}"
    info "The map was generated but scored below 90%."
    info "Review the report and re-run after adding source code."
fi

echo
info "Project Map:    .claude/project-map/PROJECT_MAP.md"
info "Install Report: .claude/project-map/reports/install-report.md"
info "Developer Skill: /${SLUG}-developer-skill"
echo
info "To regenerate at any time:"
info "  $PYTHON_CMD .claude/project-map/generate.py --force"
info "  $PYTHON_CMD .claude/project-map/grader.py"
echo
printf '%b\n' "${CYAN}══════════════════════════════════════════════════${RESET}"
echo


# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  HELPER FUNCTIONS                                                        ║
# ╚══════════════════════════════════════════════════════════════════════════╝

_improve_for_next_iteration() {
    local score_json="$1"
    local map_dir="$2"
    local python_cmd="$3"

    if [ ! -f "$score_json" ]; then return; fi

    # Extract categories with low scores from the JSON
    local issues
    issues=$($python_cmd -c "
import json, sys
d = json.load(open('$score_json'))
for issue in d.get('issues', []):
    print(f\"{issue['category']}: {issue['issue']}\")
" 2>/dev/null || true)

    if [ -n "$issues" ]; then
        info "Issues from previous iteration:"
        echo "$issues" | while IFS= read -r line; do
            info "  → $line"
        done
    fi

    # Force regeneration with --force flag so checksums don't block
    info "Re-running generate.py with --force for next iteration..."
}

_render_vocabulary() {
    local project_root="$1"
    local name="$2"
    local lang="$3"
    local framework="$4"
    local rules_dir="$5"
    local out="$rules_dir/project-vocabulary.md"

    # Use template if it exists, otherwise generate minimal scaffold
    local template="$TEMPLATES_DIR/project-vocabulary.md.template"

    if [ -f "$template" ]; then
        sed \
            -e "s/{{PROJECT_NAME}}/$name/g" \
            -e "s/{{LANGUAGE}}/$lang/g" \
            -e "s/{{FRAMEWORK}}/$framework/g" \
            "$template" > "$out"
    else
        cat > "$out" <<VOCAB
# ${name} — Project Vocabulary

> Auto-loaded every session. Maps human language to exact code locations.
> Regenerated automatically via pre-commit hook.

## Feature → Code Location

| You Say | Frontend | Backend | Model/Table |
|---------|----------|---------|-------------|
| _(vocabulary populates as source code is added)_ | | | |

## Infrastructure Vocabulary

| You Say | What It Is | Key Details |
|---------|-----------|-------------|
| project root | \`$project_root\` | Main repository |

## Quick Actions

| You Say | What To Do |
|---------|-----------|
| regenerate map | \`python .claude/project-map/generate.py --force\` |
| grade map | \`python .claude/project-map/grader.py\` |
| view map | \`cat .claude/project-map/PROJECT_MAP.md\` |
VOCAB
    fi

    ok "Rendered: $out"
}

_render_runbook() {
    local project_root="$1"
    local name="$2"
    local rules_dir="$3"
    local out="$rules_dir/operational-runbook.md"

    # Only create if it doesn't exist (preserve hand-curated content)
    if [ -f "$out" ]; then
        ok "Runbook already exists — preserving: $out"
        return
    fi

    local template="$TEMPLATES_DIR/operational-runbook.md.template"
    if [ -f "$template" ]; then
        sed -e "s/{{PROJECT_NAME}}/$name/g" "$template" > "$out"
    else
        cat > "$out" <<RUNBOOK
# ${name} — Operational Runbook

> Auto-loaded every session. Contains operational knowledge that cannot be derived from code.
> This file grows over time as the team discovers gotchas, quirks, and procedures.
> **Edit this file manually** — it is NOT overwritten on regeneration.

## Environment Differences

<!-- TODO: Document how dev/staging/prod differ -->

| | Dev | Staging | Production |
|---|---|---|---|
| **URL** | | | |
| **Database** | | | |
| **Deploy** | | | |

## Known Issues & Workarounds

_No known issues documented yet. When you encounter a non-obvious problem and its solution, add it here._

## Deploy Procedures

<!-- TODO: Document deploy steps per environment -->

## Key Commands

| Command | What It Does |
|---------|-------------|
| \`python .claude/project-map/generate.py --force\` | Regenerate project map |
| \`python .claude/project-map/grader.py\` | Grade map quality |

## Dev Credentials

<!-- Add test/dev credentials here — NEVER production secrets -->
RUNBOOK
    fi

    ok "Rendered: $out"
}

_render_skill() {
    local project_root="$1"
    local name="$2"
    local slug="$3"
    local lang="$4"
    local framework="$5"
    local skills_dir="$6"
    local out="$skills_dir/SKILL.md"

    local template="$TEMPLATES_DIR/SKILL.md.template"
    if [ -f "$template" ]; then
        sed \
            -e "s/{{PROJECT_NAME}}/$name/g" \
            -e "s/{{PROJECT_SLUG}}/$slug/g" \
            -e "s/{{LANGUAGE}}/$lang/g" \
            -e "s/{{FRAMEWORK}}/$framework/g" \
            "$template" > "$out"
    else
        cat > "$out" <<SKILL
---
name: ${slug}-developer-skill
description: |
  Full-stack developer context for ${name} (${lang}/${framework}).
  Provides instant access to project map, vocabulary translation, and infrastructure details.
  Invoke when working on any ${name} feature, bug, or infrastructure task.
---

# /${slug}-developer — ${name} Developer Context

You are a developer working on **${name}**. This skill gives you complete
knowledge of every route, model, service, feature, and infrastructure component
via an auto-generated project map.

## On Trigger — Load Only What You Need

The project map is split into section files at \`.claude/project-map/sections/\`.
Do NOT read them all. Start with:

\`\`\`
Read: .claude/project-map/PROJECT_MAP.md
\`\`\`

Use the Quick Routing table to pick which 2-3 sections to load.

## Section Routing

| Task | Read These Sections |
|------|-------------------|
| Feature / UX work | 01-vocabulary → 09-frontend → 04-routes |
| Add a model or field | 05-models → 06-schemas → 12-import-chains |
| Troubleshoot error | 02-topology → 03-environment → 14-proxy |
| Infrastructure / scaling | 16-infra-profile → 02-topology |
| Auth / security | 15-auth-config → 19-doc-pointers |
| What tools exist | 10-tools-commands |
| Background jobs | 08-background-jobs |

## Platform Quick Reference

- **Stack**: ${lang} / ${framework}
- **Project Root**: ${project_root}

## Keeping the Map Current

Regenerates automatically via pre-commit hook.
Force: \`python .claude/project-map/generate.py --force\`

## Growing the Runbook

When you encounter a non-obvious operational issue, suggest adding it:

> "This looks like operational knowledge worth documenting. Want me to add it
> to the runbook? (Y/n)"

If agreed, append a concise entry (symptom → cause → fix) to
\`.claude/rules/operational-runbook.md\`.
SKILL
    fi

    ok "Rendered: $out"
}

_install_git_hooks() {
    local project_root="$1"
    local hooks_dir="$2"
    local map_dir="$3"
    local python_cmd="$4"

    # pre-commit hook
    local pre_commit="$hooks_dir/pre-commit"
    local hook_snippet
    hook_snippet=$(cat <<'HOOK'
# ── Codebase Mapper: regenerate project map on relevant changes ──────────────
STAGED_FILES=$(git diff --cached --name-only 2>/dev/null || true)
EXTENSIONS_PATTERN='\.(py|ts|tsx|js|jsx|go|java|yaml|yml)$|docker-compose|package\.json|Cargo\.toml|go\.mod'

if echo "$STAGED_FILES" | grep -qE "$EXTENSIONS_PATTERN" 2>/dev/null; then
    MAP_SCRIPT=".claude/project-map/generate.py"
    if [ -f "$MAP_SCRIPT" ]; then
        PYTHON_CMD=""
        if [ -f ".venv/bin/python3" ]; then PYTHON_CMD=".venv/bin/python3"
        elif command -v python3 &>/dev/null; then PYTHON_CMD="python3"
        elif command -v python &>/dev/null; then PYTHON_CMD="python"
        fi
        if [ -n "$PYTHON_CMD" ]; then
            echo "[codebase-mapper] Regenerating project map..."
            if $PYTHON_CMD "$MAP_SCRIPT" 2>/dev/null; then
                git add .claude/project-map/PROJECT_MAP.md \
                        .claude/project-map/checksums.json \
                        .claude/project-map/sections/*.md \
                        .claude/project-map/learned-vocabulary.json 2>/dev/null || true
            fi
        fi
    fi
fi
# ── End Codebase Mapper ──────────────────────────────────────────────────────
HOOK
)

    if [ -f "$pre_commit" ]; then
        # Append to existing hook (don't duplicate)
        if ! grep -q 'Codebase Mapper' "$pre_commit" 2>/dev/null; then
            echo "" >> "$pre_commit"
            echo "$hook_snippet" >> "$pre_commit"
            ok "Appended to existing pre-commit hook"
        else
            ok "pre-commit hook already contains Codebase Mapper snippet"
        fi
    else
        cat > "$pre_commit" <<PRECOMMIT
#!/bin/bash
${hook_snippet}
PRECOMMIT
        ok "Created pre-commit hook"
    fi

    chmod +x "$pre_commit"

    # Hook installer script
    cat > "$hooks_dir/install.sh" <<'INSTALL'
#!/bin/bash
# Install .githooks as the git hooks directory
git config core.hooksPath .githooks
chmod +x .githooks/*
echo "Git hooks installed (.githooks/ directory configured)"
INSTALL
    chmod +x "$hooks_dir/install.sh"

    # Auto-configure this repo to use .githooks/
    if git -C "$project_root" rev-parse --git-dir > /dev/null 2>&1; then
        git -C "$project_root" config core.hooksPath .githooks
        ok "Configured git to use .githooks/"
    fi
}

_update_claude_md() {
    local project_root="$1"
    local name="$2"
    local map_dir="$3"
    local claude_md="$project_root/CLAUDE.md"

    local pointer="## Project Map

**Project Map**: For any project-specific question, read
[\`.claude/project-map/PROJECT_MAP.md\`](.claude/project-map/PROJECT_MAP.md) —
auto-generated index of routes, models, import chains, infra profile,
and vocabulary translator. Regenerated automatically on commit.

To regenerate manually:
\`\`\`bash
python .claude/project-map/generate.py --force
\`\`\`"

    if [ -f "$claude_md" ]; then
        if grep -q 'Project Map' "$claude_md" 2>/dev/null; then
            ok "CLAUDE.md already has Project Map section"
        else
            echo "" >> "$claude_md"
            echo "$pointer" >> "$claude_md"
            ok "Updated CLAUDE.md with Project Map pointer"
        fi
    else
        cat > "$claude_md" <<CLAUDEMD
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**${name}** — see README.md for details.

${pointer}
CLAUDEMD
        ok "Created CLAUDE.md"
    fi
}
