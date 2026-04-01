#!/usr/bin/env bash
# Babel Fish — Remote Installer
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/TheGlitchKing/babel-fish/main/install.sh | bash
#   curl -sSL https://raw.githubusercontent.com/TheGlitchKing/babel-fish/main/install.sh | bash -s -- /path/to/project
#   curl -sSL https://raw.githubusercontent.com/TheGlitchKing/babel-fish/main/install.sh | bash -s -- --dry-run
#
# What this script does (readable before you run it):
#   1. Creates a temp dir
#   2. git clone --depth=1 https://github.com/TheGlitchKing/babel-fish.git into it
#   3. Runs .claude/install.sh <target> from the cloned copy
#   4. Deletes the temp dir on exit
#
# Nothing is written outside of <target>/.claude/ and <target>/.githooks/
# Run with --dry-run to preview all changes without applying them.

set -euo pipefail

REPO="https://github.com/TheGlitchKing/babel-fish.git"
CHECKSUM_URL="https://raw.githubusercontent.com/TheGlitchKing/babel-fish/main/checksums.json"
TMP_DIR="$(mktemp -d)"
TARGET=""
DRY_RUN_FLAG=""

# Parse args
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN_FLAG="--dry-run" ;;
        -*) ;;
        *) TARGET="$arg" ;;
    esac
done

TARGET="${TARGET:-$(pwd)}"

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

echo ""
echo "  Babel Fish — Remote Installer"
echo "  Repository: $REPO"
echo "  Target:     $TARGET"
if [ -n "$DRY_RUN_FLAG" ]; then
    echo "  Mode:       DRY RUN (preview only, nothing will be modified)"
fi
echo ""

# Verify checksum if sha256sum is available
if command -v sha256sum >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
    echo "  Fetching checksum manifest..."
    CHECKSUMS_JSON="$(curl -sSL "$CHECKSUM_URL" 2>/dev/null || echo "")"
    if [ -n "$CHECKSUMS_JSON" ]; then
        EXPECTED_SHA="$(echo "$CHECKSUMS_JSON" | grep -o '"install_sh": *"[^"]*"' | grep -o '[a-f0-9]\{64\}' || echo "")"
        if [ -n "$EXPECTED_SHA" ]; then
            # Clone and verify
            echo "  Cloning plugin source..."
            git clone --depth=1 --quiet "$REPO" "$TMP_DIR/babel-fish"
            ACTUAL_SHA="$(sha256sum "$TMP_DIR/babel-fish/.claude/install.sh" | cut -d' ' -f1)"
            if [ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]; then
                echo ""
                echo "  ✗ CHECKSUM MISMATCH — aborting for your safety."
                echo "    Expected: $EXPECTED_SHA"
                echo "    Got:      $ACTUAL_SHA"
                echo ""
                echo "  This may indicate the file was tampered with in transit."
                echo "  Please report this at https://github.com/TheGlitchKing/babel-fish/issues"
                exit 1
            fi
            echo "  ✓ Checksum verified"
        else
            echo "  Cloning plugin source..."
            git clone --depth=1 --quiet "$REPO" "$TMP_DIR/babel-fish"
        fi
    else
        echo "  Cloning plugin source..."
        git clone --depth=1 --quiet "$REPO" "$TMP_DIR/babel-fish"
    fi
else
    echo "  Cloning plugin source..."
    git clone --depth=1 --quiet "$REPO" "$TMP_DIR/babel-fish"
fi

echo "  Running installer..."
echo ""
bash "$TMP_DIR/babel-fish/.claude/install.sh" $DRY_RUN_FLAG "$TARGET"
