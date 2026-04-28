#!/usr/bin/env bash
# End-to-end test for install.sh. Runs the installer against a fake HOME
# and asserts the post-install state. Exits non-zero on first failure.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALLER="$REPO_ROOT/install.sh"
SOURCE_SCRIPT="$REPO_ROOT/statusline-progress.sh"

if [ ! -f "$INSTALLER" ]; then
    echo "FAIL: $INSTALLER does not exist"
    exit 1
fi

# Each test runs in its own fake HOME under a fresh temp directory.
make_fake_home() {
    local dir
    dir="$(mktemp -d -t cc-statusline-test.XXXXXX)"
    mkdir -p "$dir/.claude"
    printf "%s" "$dir"
}

assert() {
    local desc="$1"; shift
    if eval "$@"; then
        echo "  PASS: $desc"
    else
        echo "  FAIL: $desc"
        echo "    Command: $*"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Test 1: fresh install (no pre-existing settings.json)
# ---------------------------------------------------------------------------
echo "Test 1: fresh install with no pre-existing settings.json"
HOME_DIR="$(make_fake_home)"
trap 'rm -rf "$HOME_DIR"' EXIT

HOME="$HOME_DIR" bash "$INSTALLER" >/dev/null

assert "statusline-progress.sh installed" "[ -f \"$HOME_DIR/.claude/statusline-progress.sh\" ]"
assert "installed script is executable"   "[ -x \"$HOME_DIR/.claude/statusline-progress.sh\" ]"
assert "installed script matches source"  "diff -q \"$SOURCE_SCRIPT\" \"$HOME_DIR/.claude/statusline-progress.sh\" >/dev/null"
assert "settings.json was created"        "[ -f \"$HOME_DIR/.claude/settings.json\" ]"
assert "settings.json has statusLine.type=command" \
    "[ \"\$(jq -r '.statusLine.type' \"$HOME_DIR/.claude/settings.json\")\" = command ]"
assert "settings.json has statusLine.command pointing at installed script" \
    "[ \"\$(jq -r '.statusLine.command' \"$HOME_DIR/.claude/settings.json\")\" = \"$HOME_DIR/.claude/statusline-progress.sh\" ]"
assert "no backup created (nothing to back up)" \
    "! ls \"$HOME_DIR/.claude\"/settings.json.backup-* >/dev/null 2>&1"

rm -rf "$HOME_DIR"
trap - EXIT

# ---------------------------------------------------------------------------
# Test 2: install over existing settings.json — preserves other keys, creates backup
# ---------------------------------------------------------------------------
echo "Test 2: install over existing settings.json"
HOME_DIR="$(make_fake_home)"
trap 'rm -rf "$HOME_DIR"' EXIT

cat >"$HOME_DIR/.claude/settings.json" <<'JSON'
{
  "language": "Bahasa Indonesia",
  "statusLine": {
    "type": "command",
    "command": "/old/path.sh"
  }
}
JSON

HOME="$HOME_DIR" bash "$INSTALLER" >/dev/null

assert "language key preserved" \
    "[ \"\$(jq -r '.language' \"$HOME_DIR/.claude/settings.json\")\" = 'Bahasa Indonesia' ]"
assert "statusLine.command was overwritten to new path" \
    "[ \"\$(jq -r '.statusLine.command' \"$HOME_DIR/.claude/settings.json\")\" = \"$HOME_DIR/.claude/statusline-progress.sh\" ]"
assert "exactly one backup file was created" \
    "[ \"\$(ls \"$HOME_DIR/.claude\"/settings.json.backup-* 2>/dev/null | wc -l | tr -d ' ')\" = 1 ]"
assert "backup contains the old statusLine.command" \
    "[ \"\$(jq -r '.statusLine.command' \"$HOME_DIR/.claude\"/settings.json.backup-*)\" = '/old/path.sh' ]"

rm -rf "$HOME_DIR"
trap - EXIT

# ---------------------------------------------------------------------------
# Test 3: missing ~/.claude/ directory aborts with non-zero exit
# ---------------------------------------------------------------------------
echo "Test 3: missing ~/.claude/ aborts cleanly"
HOME_DIR="$(mktemp -d -t cc-statusline-test.XXXXXX)"
trap 'rm -rf "$HOME_DIR"' EXIT

set +e
HOME="$HOME_DIR" bash "$INSTALLER" >/dev/null 2>&1
rc=$?
set -e

assert "installer exits non-zero when ~/.claude/ missing" "[ $rc -ne 0 ]"
assert "no settings.json was created" "! [ -f \"$HOME_DIR/.claude/settings.json\" ]"

rm -rf "$HOME_DIR"
trap - EXIT

echo
echo "All tests passed."
