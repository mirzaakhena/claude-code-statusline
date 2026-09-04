#!/usr/bin/env bash
# install.sh — install statusline-progress.sh into ~/.claude/ and patch settings.json.
# Supports two invocation modes:
#   - Local: ./install.sh from a clone (sibling statusline-progress.sh present).
#   - Remote: curl -fsSL .../install.sh | bash (downloads the script over HTTPS).

set -euo pipefail

REMOTE_RAW_BASE="https://raw.githubusercontent.com/mirzaakhena/claude-code-statusline/main"
SCRIPT_NAME="statusline-progress.sh"
TARGET_DIR="$HOME/.claude"
TARGET_SCRIPT="$TARGET_DIR/$SCRIPT_NAME"
SETTINGS_FILE="$TARGET_DIR/settings.json"

err() { printf "error: %s\n" "$*" >&2; }
info() { printf "%s\n" "$*"; }

# --- preconditions ---------------------------------------------------------

if ! command -v jq >/dev/null 2>&1; then
    err "jq is required but not installed."
    err "  macOS:  brew install jq"
    err "  Debian: sudo apt install jq"
    err "  Fedora: sudo dnf install jq"
    exit 1
fi

if [ ! -d "$TARGET_DIR" ]; then
    err "$TARGET_DIR does not exist."
    err "Install Claude Code first: https://claude.com/claude-code"
    exit 1
fi

# --- locate the source script (local mode vs remote mode) ------------------

# BASH_SOURCE[0] is empty when the script is read from stdin (curl | bash).
SELF_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

TMP_DOWNLOAD=""
cleanup_tmp() { [ -n "$TMP_DOWNLOAD" ] && rm -f "$TMP_DOWNLOAD"; return 0; }
trap cleanup_tmp EXIT

if [ -n "$SELF_DIR" ] && [ -f "$SELF_DIR/$SCRIPT_NAME" ]; then
    info "Local mode: copying $SCRIPT_NAME from $SELF_DIR"
    SOURCE_SCRIPT="$SELF_DIR/$SCRIPT_NAME"
else
    info "Remote mode: downloading $SCRIPT_NAME from GitHub"
    if ! command -v curl >/dev/null 2>&1; then
        err "curl is required for remote install but not installed."
        exit 1
    fi
    TMP_DOWNLOAD="$(mktemp -t statusline-progress.XXXXXX)"
    if ! curl -fsSL "$REMOTE_RAW_BASE/$SCRIPT_NAME" -o "$TMP_DOWNLOAD"; then
        err "Failed to download $REMOTE_RAW_BASE/$SCRIPT_NAME"
        exit 1
    fi
    SOURCE_SCRIPT="$TMP_DOWNLOAD"
fi

# --- backup existing settings.json ----------------------------------------

BACKUP_PATH=""
if [ -f "$SETTINGS_FILE" ]; then
    BACKUP_PATH="$SETTINGS_FILE.backup-$(date +%s)"
    cp "$SETTINGS_FILE" "$BACKUP_PATH"
    info "Backed up existing settings.json to: $BACKUP_PATH"
else
    info "No existing settings.json; one will be created."
fi

# --- install the script ----------------------------------------------------

cp "$SOURCE_SCRIPT" "$TARGET_SCRIPT"
chmod +x "$TARGET_SCRIPT"
info "Installed: $TARGET_SCRIPT"

# --- patch settings.json ---------------------------------------------------

NEW_BLOCK="$(jq -n --arg cmd "$TARGET_SCRIPT" '{statusLine: {type: "command", command: $cmd}}')"

if [ -f "$SETTINGS_FILE" ]; then
    TMP_SETTINGS="$(mktemp -t settings.json.XXXXXX)"
    if ! jq --argjson patch "$NEW_BLOCK" '. + $patch' "$SETTINGS_FILE" >"$TMP_SETTINGS"; then
        err "Failed to patch $SETTINGS_FILE. Your backup is at: $BACKUP_PATH"
        rm -f "$TMP_SETTINGS"
        exit 1
    fi
    mv "$TMP_SETTINGS" "$SETTINGS_FILE"
else
    printf "%s\n" "$NEW_BLOCK" >"$SETTINGS_FILE"
fi
info "Patched: $SETTINGS_FILE"

# --- summary ---------------------------------------------------------------

cat <<EOF

Done. Restart Claude Code to see the new status line.

To uninstall:
  - Restore the backup: cp "$BACKUP_PATH" "$SETTINGS_FILE"
  - Or remove the .statusLine key from $SETTINGS_FILE and delete $TARGET_SCRIPT.
EOF
