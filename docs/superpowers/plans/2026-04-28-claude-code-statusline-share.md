# claude-code-status-line — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish `statusline-progress.sh` as a public GitHub repository at `mirzaakhena/claude-code-status-line` so others can install it via `curl … | bash` or by manual clone.

**Architecture:** Five-file dotfile-style repo. The status line script is a verbatim copy of `~/.claude/statusline-progress.sh`. The installer is a single `install.sh` that detects local-vs-remote invocation, backs up `~/.claude/settings.json`, copies the script, and patches `settings.json` with `jq`. End-to-end tested with a self-contained bash test script that runs in a temp `HOME`.

**Tech Stack:** Bash 3.2+, `jq`, `curl`, plain `git`. No build tools, no test framework dependencies (tests use raw bash).

**Working directory for all tasks:** `/Users/mirza/Workspace/claude-code-status-line`

**Reference spec:** `docs/superpowers/specs/2026-04-28-claude-code-statusline-share-design.md`

---

## File Structure

```
claude-code-status-line/
├── .gitignore
├── LICENSE
├── README.md
├── install.sh
├── statusline-progress.sh
├── tests/
│   └── install_test.sh
└── docs/                # already populated (spec + plan)
```

Each file has one responsibility:
- `statusline-progress.sh` — the status line itself (copy from `~/.claude/`)
- `install.sh` — installer; sole I/O surface against `~/.claude/`
- `tests/install_test.sh` — end-to-end test of installer in a fake `HOME`
- `README.md` — user-facing docs (preview, install, uninstall)
- `LICENSE`, `.gitignore` — boilerplate

---

## Task 1: Initialize repo and add the status line script

**Files:**
- Create: `/Users/mirza/Workspace/claude-code-status-line/.gitignore`
- Create: `/Users/mirza/Workspace/claude-code-status-line/statusline-progress.sh` (copy of `/Users/mirza/.claude/statusline-progress.sh`)

- [ ] **Step 1: Initialize git repo**

```bash
cd /Users/mirza/Workspace/claude-code-status-line
git init -b main
```

Expected: `Initialized empty Git repository in /Users/mirza/Workspace/claude-code-status-line/.git/`.

- [ ] **Step 2: Copy the status line script verbatim**

```bash
cp /Users/mirza/.claude/statusline-progress.sh ./statusline-progress.sh
chmod +x ./statusline-progress.sh
```

- [ ] **Step 3: Verify the copy is byte-identical to the source**

Run:
```bash
diff /Users/mirza/.claude/statusline-progress.sh ./statusline-progress.sh && echo OK
```
Expected: `OK` (no diff output).

- [ ] **Step 4: Smoke-test the script with sample JSON input**

Run:
```bash
echo '{"context_window":{"used_percentage":42},"rate_limits":{"five_hour":{"used_percentage":60,"resets_at":'"$(($(date +%s)+7200))"'}}}' | ./statusline-progress.sh
```
Expected: a single line containing `Context`, a progress bar, `42%`, ` │ `, `Usage`, another progress bar, `60%`, and `(2h 0m / 5h)` (or `1h 59m`). ANSI escape codes around them are fine.

- [ ] **Step 5: Write `.gitignore`**

Create `/Users/mirza/Workspace/claude-code-status-line/.gitignore`:

```
.DS_Store
*.backup-*
```

- [ ] **Step 6: Stage and commit**

```bash
cd /Users/mirza/Workspace/claude-code-status-line
git add .gitignore statusline-progress.sh docs/
git commit -m "chore: initialize repo with status line script and design docs"
```

Expected: commit succeeds; `git log --oneline` shows one commit.

---

## Task 2: Add MIT LICENSE

**Files:**
- Create: `/Users/mirza/Workspace/claude-code-status-line/LICENSE`

- [ ] **Step 1: Write the LICENSE file**

Create `/Users/mirza/Workspace/claude-code-status-line/LICENSE` with exactly this content:

```
MIT License

Copyright (c) 2026 Mirza Akhena

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 2: Commit**

```bash
git add LICENSE
git commit -m "chore: add MIT license"
```

---

## Task 3: Write the end-to-end test for the installer (test first)

**Files:**
- Create: `/Users/mirza/Workspace/claude-code-status-line/tests/install_test.sh`

This task writes the test before the installer. The test will fail to find `install.sh` (it does not exist yet); that is the expected red state. Task 4 implements `install.sh` to make the test go green.

- [ ] **Step 1: Create `tests/install_test.sh`**

Create `/Users/mirza/Workspace/claude-code-status-line/tests/install_test.sh` with this content:

```bash
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
```

- [ ] **Step 2: Make the test executable**

```bash
chmod +x tests/install_test.sh
```

- [ ] **Step 3: Run the test — confirm it fails because `install.sh` is missing**

Run:
```bash
bash tests/install_test.sh
```
Expected: exits non-zero with `FAIL: …/install.sh does not exist`. This is the red state.

- [ ] **Step 4: Commit the test**

```bash
git add tests/install_test.sh
git commit -m "test: add end-to-end install.sh test (red)"
```

---

## Task 4: Implement `install.sh`

**Files:**
- Create: `/Users/mirza/Workspace/claude-code-status-line/install.sh`

- [ ] **Step 1: Write `install.sh`**

Create `/Users/mirza/Workspace/claude-code-status-line/install.sh` with this content:

```bash
#!/usr/bin/env bash
# install.sh — install statusline-progress.sh into ~/.claude/ and patch settings.json.
# Supports two invocation modes:
#   - Local: ./install.sh from a clone (sibling statusline-progress.sh present).
#   - Remote: curl -fsSL .../install.sh | bash (downloads the script over HTTPS).

set -euo pipefail

REMOTE_RAW_BASE="https://raw.githubusercontent.com/mirzaakhena/claude-code-status-line/main"
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
cleanup_tmp() { [ -n "$TMP_DOWNLOAD" ] && rm -f "$TMP_DOWNLOAD"; }
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
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x install.sh
```

- [ ] **Step 3: Run the end-to-end test — confirm green**

Run:
```bash
bash tests/install_test.sh
```
Expected output ends with `All tests passed.` and exit code 0. All three test scenarios (fresh install, install-over-existing, missing `~/.claude/`) should report `PASS`.

- [ ] **Step 4: Commit**

```bash
git add install.sh
git commit -m "feat: add installer with backup and jq-based settings.json patch"
```

---

## Task 5: Write `README.md`

**Files:**
- Create: `/Users/mirza/Workspace/claude-code-status-line/README.md`

- [ ] **Step 1: Write the README**

Create `/Users/mirza/Workspace/claude-code-status-line/README.md`:

````markdown
# claude-code-status-line

A progress-bar status line for [Claude Code](https://claude.com/claude-code). Shows your context window usage and 5-hour rate-limit usage at a glance.

## Preview

```
Context ████████░░ 78% │ Usage ███░░░░░░░ 32% (3h 12m / 5h)
```

Real output is colored: **green** below 50%, **yellow** 50–74%, **red** at 75% and above.

## What it shows

- **Context** — context window usage with a 10-segment progress bar and percentage.
- **Usage** — 5-hour rate-limit usage with a progress bar, percentage, and time remaining until the window resets.

## Requirements

- [Claude Code](https://claude.com/claude-code) installed (so `~/.claude/` exists).
- `jq` available on `PATH`.
  - macOS: `brew install jq`
  - Debian/Ubuntu: `sudo apt install jq`
  - Fedora: `sudo dnf install jq`

## Install — one-liner

```bash
curl -fsSL https://raw.githubusercontent.com/mirzaakhena/claude-code-status-line/main/install.sh | bash
```

This will:

1. Back up `~/.claude/settings.json` to `~/.claude/settings.json.backup-<timestamp>` (if one exists).
2. Download `statusline-progress.sh` to `~/.claude/` and make it executable.
3. Patch `~/.claude/settings.json` to set `statusLine` to the installed script. Other settings are preserved.

Restart Claude Code afterward.

## Install — manual

If you prefer to install by hand:

1. Download the script:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/mirzaakhena/claude-code-status-line/main/statusline-progress.sh \
     -o ~/.claude/statusline-progress.sh
   chmod +x ~/.claude/statusline-progress.sh
   ```

2. Open `~/.claude/settings.json` and add (or merge) this block:
   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "/Users/YOUR_USERNAME/.claude/statusline-progress.sh"
     }
   }
   ```
   Replace `/Users/YOUR_USERNAME` with the absolute path to your home directory (`echo $HOME`).

3. Restart Claude Code.

## Uninstall

Either:

- Restore the backup created during install:
  ```bash
  cp ~/.claude/settings.json.backup-<timestamp> ~/.claude/settings.json
  rm ~/.claude/statusline-progress.sh
  ```

- Or manually remove the `statusLine` key from `~/.claude/settings.json` and delete `~/.claude/statusline-progress.sh`.

## License

MIT — see [LICENSE](./LICENSE).
````

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README with install, manual install, and uninstall instructions"
```

---

## Task 6: Final verification — re-run the full test suite

**Files:** none (verification only)

- [ ] **Step 1: Re-run end-to-end tests from clean state**

```bash
bash tests/install_test.sh
```
Expected: `All tests passed.`

- [ ] **Step 2: Verify the repo contents**

```bash
ls -la
```
Expected to see (at minimum): `.git/`, `.gitignore`, `LICENSE`, `README.md`, `docs/`, `install.sh`, `statusline-progress.sh`, `tests/`. `install.sh` and `statusline-progress.sh` and `tests/install_test.sh` should be marked executable.

- [ ] **Step 3: Confirm git status is clean**

```bash
git status
```
Expected: `nothing to commit, working tree clean`.

- [ ] **Step 4: Show commit history**

```bash
git log --oneline
```
Expected: 5 commits (init, license, test red, installer, readme).

- [ ] **Step 5: Tell the user the repo is ready to push**

Print to the user (do not auto-push):

> Repo is ready at `/Users/mirza/Workspace/claude-code-status-line`. To publish:
>
> ```bash
> cd /Users/mirza/Workspace/claude-code-status-line
> gh repo create mirzaakhena/claude-code-status-line --public --source=. --remote=origin --push
> ```
>
> Or, if creating the repo manually on github.com first:
>
> ```bash
> git remote add origin https://github.com/mirzaakhena/claude-code-status-line.git
> git push -u origin main
> ```

Pushing is the user's call — confirm before doing it for them.

---

## Self-Review Notes

- **Spec coverage:**
  - Repo layout (5 files + tests/) — Tasks 1–5 all create these.
  - Status line script verbatim copy — Task 1 step 2 + diff verification step 3.
  - Installer preconditions (`jq`, `~/.claude/`) — Task 4 install.sh implements; Test 3 in Task 3 verifies `~/.claude/` precondition. (`jq`-missing precondition is not test-automated because removing `jq` from `PATH` mid-test is fragile; the code path is straightforward enough that visual inspection suffices.)
  - Local vs remote mode detection — Task 4 implements via `BASH_SOURCE[0]` check; tests cover local mode (the more complex JSON-merge path). Remote mode is verified manually after push via the one-liner.
  - Backup of `settings.json` — Task 4 implements; Test 2 in Task 3 asserts a backup is created and contains the old contents.
  - JSON merge preserving other keys — Test 2 asserts `language` key survives.
  - README sections — Task 5 covers all 8 sections from the spec.
  - LICENSE MIT, copyright Mirza Akhena 2026 — Task 2.
  - `.gitignore` — Task 1 step 5.
- **Placeholder scan:** All steps have concrete commands or full file contents. No "TBD" / "implement later".
- **Type consistency:** Path constants (`TARGET_SCRIPT`, `SETTINGS_FILE`) are defined once in `install.sh` and referenced consistently. Test assertions reference the same paths via `$HOME_DIR/.claude/...`.
- **Known unmocked path:** Remote-mode download is exercised only post-push by the user's friends running the one-liner. Acceptable for v1 — failure mode is loud (curl error, immediate exit before any state mutation).
