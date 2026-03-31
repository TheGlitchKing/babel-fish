#!/usr/bin/env bash
# Babel Fish — Remote Installer
# Usage: curl -sSL https://raw.githubusercontent.com/TheGlitchKing/babel-fish/main/install.sh | bash
# Or:    curl -sSL https://raw.githubusercontent.com/TheGlitchKing/babel-fish/main/install.sh | bash -s -- /path/to/project

set -e

REPO="https://github.com/TheGlitchKing/babel-fish.git"
TMP_DIR="$(mktemp -d)"
TARGET="${1:-$(pwd)}"

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

echo "  Babel Fish — fetching plugin source..."
git clone --depth=1 --quiet "$REPO" "$TMP_DIR"

echo "  Running installer for: $TARGET"
bash "$TMP_DIR/.claude/install.sh" "$TARGET"
