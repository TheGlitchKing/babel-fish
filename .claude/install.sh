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

# Resolve absolute path immediately
PROJECT_ROOT="$(cd "${1:-$(pwd)}" && pwd)"
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
info()   { printf '%b\n' "  $*"; }


# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  HELPER FUNCTIONS  (must be defined before main flow)                   ║
# ╚══════════════════════════════════════════════════════════════════════════╝

_improve_for_next_iteration() {
    local score_json="$1"
    local python_cmd="$3"

    [ -f "$score_json" ] || return

    local issues
    issues=$("$python_cmd" -c "
import json
d = json.load(open('$score_json'))
for issue in d.get('issues', []):
    print(issue['category'] + ': ' + issue['issue'])
" 2>/dev/null || true)

    if [ -n "$issues" ]; then
        info "Issues from previous iteration:"
        echo "$issues" | while IFS= read -r line; do
            info "  → $line"
        done
    fi
    info "Will re-run generate.py with --force for next iteration..."
}

_render_vocabulary() {
    local project_root="$1"
    local name="$2"
    local lang="$3"
    local framework="$4"
    local rules_dir="$5"
    local out="$rules_dir/project-vocabulary.md"
    local template="$TEMPLATES_DIR/project-vocabulary.md.template"

    if [ -f "$template" ]; then
        sed \
            -e "s|{{PROJECT_NAME}}|$name|g" \
            -e "s|{{LANGUAGE}}|$lang|g" \
            -e "s|{{FRAMEWORK}}|$framework|g" \
            "$template" > "$out"
    else
        cat > "$out" <<VOCAB
# ${name} — Project Vocabulary

> Auto-loaded every session. Maps human language to exact code locations.

## Feature → Code Location

| You Say | Frontend | Backend | Model/Table |
|---------|----------|---------|-------------|
| _(vocabulary populates as source code is added)_ | | | |

## Quick Actions

| You Say | What To Do |
|---------|-----------|
| regenerate map | \`python .claude/project-map/generate.py --force\` |
| grade map | \`python .claude/project-map/grader.py\` |
VOCAB
    fi
    ok "Rendered: $out"
}

_render_runbook() {
    local name="$2"
    local rules_dir="$3"
    local out="$rules_dir/operational-runbook.md"
    local template="$TEMPLATES_DIR/operational-runbook.md.template"

    if [ -f "$out" ]; then
        ok "Runbook already exists — preserving: $out"
        return
    fi

    if [ -f "$template" ]; then
        sed -e "s|{{PROJECT_NAME}}|$name|g" "$template" > "$out"
    else
        cat > "$out" <<RUNBOOK
# ${name} — Operational Runbook

> Auto-loaded every session. Edit this file manually — NOT overwritten on regeneration.

## Environment Differences

| | Dev | Staging | Production |
|---|---|---|---|
| **URL** | | | |
| **Database** | | | |

## Known Issues & Workarounds

_No known issues documented yet._

## Key Commands

| Command | What It Does |
|---------|-------------|
| \`python .claude/project-map/generate.py --force\` | Regenerate project map |
| \`python .claude/project-map/grader.py\` | Grade map quality |
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
            -e "s|{{PROJECT_NAME}}|$name|g" \
            -e "s|{{PROJECT_SLUG}}|$slug|g" \
            -e "s|{{LANGUAGE}}|$lang|g" \
            -e "s|{{FRAMEWORK}}|$framework|g" \
            "$template" > "$out"
    else
        cat > "$out" <<SKILL
---
name: ${slug}-developer-skill
description: |
  Full-stack developer context for ${name} (${lang}/${framework}).
  Invoke when working on any ${name} feature, bug, or infrastructure task.
---

# /${slug}-developer — ${name} Developer Context

## On Trigger

\`\`\`
Read: .claude/project-map/PROJECT_MAP.md
\`\`\`

Use the Quick Routing table to pick 2-3 sections to load.

## Section Routing

| Task | Read These Sections |
|------|-------------------|
| Feature / UX work | 01-vocabulary → 09-frontend → 04-routes |
| Add a model or field | 05-models → 06-schemas → 12-import-chains |
| Troubleshoot error | 02-topology → 03-environment → 14-proxy |
| Infrastructure | 16-infra-profile → 02-topology |
| Auth / security | 15-auth-config |
| Tools | 10-tools-commands |

## Stack: ${lang} / ${framework}
SKILL
    fi
    ok "Rendered: $out"
}

_install_git_hooks() {
    local project_root="$1"
    local hooks_dir="$2"
    local pre_commit="$hooks_dir/pre-commit"

    local hook_snippet='# ── Codebase Mapper: regenerate project map on relevant changes ──
STAGED_FILES=$(git diff --cached --name-only 2>/dev/null || true)
EXTENSIONS_PATTERN='"'"'\.(py|ts|tsx|js|jsx|go|java|yaml|yml)$|docker-compose|package\.json|Cargo\.toml|go\.mod'"'"'
if echo "$STAGED_FILES" | grep -qE "$EXTENSIONS_PATTERN" 2>/dev/null; then
    MAP_SCRIPT=".claude/project-map/generate.py"
    if [ -f "$MAP_SCRIPT" ]; then
        PYTHON=""
        if [ -f ".venv/bin/python3" ]; then PYTHON=".venv/bin/python3"
        elif command -v python3 &>/dev/null; then PYTHON="python3"
        elif command -v python &>/dev/null; then PYTHON="python"
        fi
        if [ -n "$PYTHON" ]; then
            echo "[codebase-mapper] Regenerating project map..."
            if $PYTHON "$MAP_SCRIPT" 2>/dev/null; then
                git add .claude/project-map/PROJECT_MAP.md .claude/project-map/checksums.json \
                        .claude/project-map/sections/*.md .claude/project-map/learned-vocabulary.json 2>/dev/null || true
            fi
        fi
    fi
fi
# ── End Codebase Mapper ──────────────────────────────────────────────────────'

    if [ -f "$pre_commit" ]; then
        if ! grep -q 'Codebase Mapper' "$pre_commit" 2>/dev/null; then
            { echo ""; echo "$hook_snippet"; } >> "$pre_commit"
            ok "Appended to existing pre-commit hook"
        else
            ok "pre-commit hook already contains Codebase Mapper snippet"
        fi
    else
        printf '#!/bin/bash\n%s\n' "$hook_snippet" > "$pre_commit"
        ok "Created pre-commit hook"
    fi

    chmod +x "$pre_commit"

    cat > "$hooks_dir/install.sh" <<'INSTALL'
#!/bin/bash
git config core.hooksPath .githooks
chmod +x .githooks/*
echo "Git hooks installed (.githooks/ directory configured)"
INSTALL
    chmod +x "$hooks_dir/install.sh"

    if git -C "$project_root" rev-parse --git-dir > /dev/null 2>&1; then
        git -C "$project_root" config core.hooksPath .githooks
        ok "Configured git to use .githooks/"
    fi
}

_update_claude_md() {
    local project_root="$1"
    local name="$2"
    local claude_md="$project_root/CLAUDE.md"

    if [ -f "$claude_md" ] && grep -q 'Project Map' "$claude_md" 2>/dev/null; then
        ok "CLAUDE.md already has Project Map section"
        return
    fi

    local pointer
    pointer=$(cat <<'POINTER'

## Project Map

**Project Map**: For any project-specific question, read
[`.claude/project-map/PROJECT_MAP.md`](.claude/project-map/PROJECT_MAP.md) —
auto-generated index of routes, models, import chains, infra profile,
and vocabulary translator. Regenerated automatically on commit.

To regenerate manually:
```bash
python .claude/project-map/generate.py --force
```
POINTER
)

    if [ -f "$claude_md" ]; then
        echo "$pointer" >> "$claude_md"
        ok "Updated CLAUDE.md with Project Map pointer"
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


# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  MAIN FLOW                                                               ║
# ╚══════════════════════════════════════════════════════════════════════════╝

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

ok "Python: $("$PYTHON_CMD" --version 2>&1)"

# ── Step 2: Detect Stack ──────────────────────────────────────────────────────
banner "Step 2: Stack Detection"

STACK_JSON="$MAP_DIR/stack.json"
mkdir -p "$MAP_DIR" "$REPORTS_DIR"

if [ -f "$SCRIPTS_DIR/detect-stack.sh" ]; then
    bash "$SCRIPTS_DIR/detect-stack.sh" "$PROJECT_ROOT" > "$STACK_JSON" 2>/dev/null || true
fi

if [ -f "$STACK_JSON" ] && "$PYTHON_CMD" -c "import json; json.load(open('$STACK_JSON'))" 2>/dev/null; then
    LANG=$("$PYTHON_CMD"   -c "import json; d=json.load(open('$STACK_JSON')); print(d.get('language','unknown'))")
    FRAMEWORK=$("$PYTHON_CMD" -c "import json; d=json.load(open('$STACK_JSON')); print(d.get('framework','unknown'))")
    NAME=$("$PYTHON_CMD"   -c "import json; d=json.load(open('$STACK_JSON')); print(d.get('name','project'))")
    SLUG=$("$PYTHON_CMD"   -c "import json; d=json.load(open('$STACK_JSON')); print(d.get('slug','project'))")
    ok "Detected: $NAME ($LANG / $FRAMEWORK)"
else
    warn "Stack detection unavailable — using directory name as defaults"
    NAME=$(basename "$PROJECT_ROOT")
    SLUG=$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g;s/^-//;s/-$//')
    LANG="unknown"
    FRAMEWORK="unknown"
fi

# ── Step 3: Iterative Generation + Grading ────────────────────────────────────
banner "Step 3: Generate → Grade (up to $MAX_ITERATIONS iterations)"

FINAL_SCORE=0
FINAL_PASSED=false

for ITERATION in $(seq 1 $MAX_ITERATIONS); do
    echo
    step "Iteration $ITERATION / $MAX_ITERATIONS"
    echo

    step "Running generate.py..."
    set +e
    "$PYTHON_CMD" "$MAP_DIR/generate.py" --force \
        --project-root "$PROJECT_ROOT" \
        --stack-json "$STACK_JSON"
    GEN_EXIT=$?
    set -e
    [ $GEN_EXIT -ne 0 ] && warn "generate.py exited with errors (continuing to grade what was produced)"

    step "Running grader.py..."
    GRADE_ARGS=(--iteration "$ITERATION" --total "$MAX_ITERATIONS" --project-root "$PROJECT_ROOT")
    [ -n "$PREVIOUS_SCORE" ] && GRADE_ARGS+=(--previous-score "$PREVIOUS_SCORE")

    set +e
    "$PYTHON_CMD" "$MAP_DIR/grader.py" "${GRADE_ARGS[@]}"
    GRADE_EXIT=$?
    set -e

    SCORE_JSON="$REPORTS_DIR/iteration-$(printf '%02d' "$ITERATION")-score.json"
    if [ -f "$SCORE_JSON" ]; then
        FINAL_SCORE=$("$PYTHON_CMD" -c "import json; print(json.load(open('$SCORE_JSON'))['score'])")
        PASSED=$("$PYTHON_CMD"      -c "import json; print(json.load(open('$SCORE_JSON'))['passed'])")
    else
        FINAL_SCORE=0
        PASSED="False"
    fi

    PREVIOUS_SCORE="$FINAL_SCORE"

    if [ "$PASSED" = "True" ]; then
        FINAL_PASSED=true
        ok "Score: ${FINAL_SCORE}% — PASSED ✓ (>= ${PASS_THRESHOLD}%)"
        break
    else
        warn "Score: ${FINAL_SCORE}% — below ${PASS_THRESHOLD}% threshold"
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

_render_vocabulary "$PROJECT_ROOT" "$NAME" "$LANG" "$FRAMEWORK" "$RULES_DIR"
_render_runbook    "$PROJECT_ROOT" "$NAME" "$RULES_DIR"
_render_skill      "$PROJECT_ROOT" "$NAME" "$SLUG" "$LANG" "$FRAMEWORK" "$SKILLS_DIR"

# ── Step 5: Git Hooks ─────────────────────────────────────────────────────────
banner "Step 5: Git Hooks"

HOOKS_DIR="$PROJECT_ROOT/.githooks"
mkdir -p "$HOOKS_DIR"
_install_git_hooks "$PROJECT_ROOT" "$HOOKS_DIR"

# ── Step 6: Update CLAUDE.md ──────────────────────────────────────────────────
banner "Step 6: Update CLAUDE.md"
_update_claude_md "$PROJECT_ROOT" "$NAME"

# ── Step 7: Final Validation ──────────────────────────────────────────────────
banner "Step 7: Validation"

if [ -f "$SCRIPTS_DIR/validate.sh" ]; then
    bash "$SCRIPTS_DIR/validate.sh" "$PROJECT_ROOT" || true
else
    warn "validate.sh not found — skipping"
fi

# ── Summary ────���──────────────────────────────────────────────────────────────
echo
printf '%b\n' "${CYAN}${BOLD}══════════════════════════════════════════════════${RESET}"
printf '%b\n' "${BOLD}  Installation Complete${RESET}"
printf '%b\n' "${CYAN}══════════════════════════════════════════════════${RESET}"
echo

if [ "$FINAL_PASSED" = "true" ]; then
    printf '%b\n' "  ${GREEN}${BOLD}✓ PASSED${RESET} — Score: ${GREEN}${FINAL_SCORE}%${RESET}"
else
    printf '%b\n' "  ${YELLOW}${BOLD}⚠ COMPLETED WITH WARNINGS${RESET} — Score: ${YELLOW}${FINAL_SCORE}%${RESET}"
    info "Map generated but scored below 90%. Review report for details."
fi

echo
info "Project Map:     .claude/project-map/PROJECT_MAP.md"
info "Install Report:  .claude/project-map/reports/install-report.md"
info "Developer Skill: /${SLUG}-developer-skill"
echo
info "To regenerate:"
info "  $PYTHON_CMD .claude/project-map/generate.py --force"
info "  $PYTHON_CMD .claude/project-map/grader.py"
echo
printf '%b\n' "${CYAN}══════════════════════════════════════════════════${RESET}"
echo
