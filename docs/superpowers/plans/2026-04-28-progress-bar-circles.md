# Progress bar circles variant — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `circles` (●●●○○) progress-bar variant alongside the existing `blocks` (████░░), with the choice picked at install time and baked into the installed script.

**Architecture:** The runtime script gains a `STYLE` shell variable that switches the filled/empty characters used by `make_bar()`. The installer prompts the user (or honors a `STATUSLINE_STYLE` env var) and uses `sed` to patch the `STYLE=` line in the installed copy. Runtime stays config-free — no env var lookups, no extra files.

**Tech Stack:** Bash, `jq`, `sed`. Tests are bash scripts under `tests/`.

Spec: `docs/superpowers/specs/2026-04-28-progress-bar-circles-design.md`

---

## File Structure

**Modified:**
- `statusline-progress.sh` — add `STYLE="blocks"` line near the top; switch characters in `make_bar()` based on `$STYLE`.
- `install.sh` — pick a style (env var → TTY prompt → default blocks), then `sed`-patch the installed copy.
- `tests/install_test.sh` — update Test 1's assertion, add Tests 4 and 5.
- `README.md` — document the two styles and how to choose / re-pick.

**Created:**
- `tests/runtime_style_test.sh` — runtime-side test that verifies the script renders the right character for each `STYLE` value.

---

## Task 1: Runtime — STYLE variable and per-style characters

**Files:**
- Create: `tests/runtime_style_test.sh`
- Modify: `statusline-progress.sh` (top of file + `make_bar()`)

This task is TDD-only and has no installer changes. The test directly creates copies of `statusline-progress.sh` with the `STYLE=` line patched to each value, pipes a fixed JSON to it, and greps the output.

- [ ] **Step 1: Write the failing test**

Create `tests/runtime_style_test.sh`:

```bash
#!/usr/bin/env bash
# Runtime-side tests for STATUSLINE_STYLE variants. Each case patches a
# temp copy of statusline-progress.sh, pipes a fixed JSON sample, and
# asserts the rendered characters.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_SCRIPT="$REPO_ROOT/statusline-progress.sh"

# A 50% / 30% snapshot. With width 10 that's 5 filled + 5 empty for Context.
SAMPLE_JSON='{"context_window":{"used_percentage":50},"rate_limits":{"five_hour":{"used_percentage":30,"resets_at":9999999999}}}'

assert_contains() {
    local desc="$1" haystack="$2" needle="$3"
    if printf '%s' "$haystack" | grep -q -- "$needle"; then
        echo "  PASS: $desc"
    else
        echo "  FAIL: $desc"
        echo "    Expected to find: $needle"
        echo "    In output:        $haystack"
        exit 1
    fi
}

assert_not_contains() {
    local desc="$1" haystack="$2" needle="$3"
    if ! printf '%s' "$haystack" | grep -q -- "$needle"; then
        echo "  PASS: $desc"
    else
        echo "  FAIL: $desc"
        echo "    Did not expect:  $needle"
        echo "    In output:       $haystack"
        exit 1
    fi
}

run_with_style() {
    local style="$1"
    local tmp
    tmp="$(mktemp -t statusline-runtime.XXXXXX)"
    cp "$SOURCE_SCRIPT" "$tmp"
    sed -i.bak "s/^STYLE=.*/STYLE=\"$style\"/" "$tmp"
    rm -f "$tmp.bak"
    chmod +x "$tmp"
    local output
    output="$(printf '%s' "$SAMPLE_JSON" | bash "$tmp")"
    rm -f "$tmp"
    printf '%s' "$output"
}

echo "Test 1: STYLE=blocks renders block characters"
out="$(run_with_style blocks)"
assert_contains "output contains █ (U+2588)" "$out" $'\xe2\x96\x88'
assert_contains "output contains ░ (U+2591)" "$out" $'\xe2\x96\x91'

echo "Test 2: STYLE=circles renders circle characters"
out="$(run_with_style circles)"
assert_contains "output contains ● (U+25CF)" "$out" $'\xe2\x97\x8f'
assert_contains "output contains ○ (U+25CB)" "$out" $'\xe2\x97\x8b'
assert_not_contains "output has no block char" "$out" $'\xe2\x96\x88'

echo "Test 3: STYLE=invalid falls back to blocks"
out="$(run_with_style bogus)"
assert_contains "output contains █ (fallback)" "$out" $'\xe2\x96\x88'
assert_not_contains "output has no circle char" "$out" $'\xe2\x97\x8f'

echo
echo "All runtime style tests passed."
```

- [ ] **Step 2: Make the test runnable and run it to verify it fails**

Run:
```bash
chmod +x tests/runtime_style_test.sh
bash tests/runtime_style_test.sh
```
Expected: FAIL on Test 1 — `sed` substitutes nothing (no `STYLE=` line in source yet) and the script still renders blocks, but Test 2 fails because circles don't appear.

- [ ] **Step 3: Add STYLE variable and per-style characters in `statusline-progress.sh`**

Add a new line right after `FG_GRAY="\033[90m"` (line 15):

```bash

# Progress-bar style: "blocks" or "circles". Patched by install.sh.
STYLE="blocks"
```

Then replace the body of `make_bar()` (lines 21–40) with this version that picks characters from `$STYLE`:

```bash
make_bar() {
    local pct=$1
    local width=${2:-10}
    local filled=$(( pct * width / 100 ))
    [ "$filled" -gt "$width" ] && filled=$width
    local empty=$(( width - filled ))

    local filled_char empty_char
    case "$STYLE" in
        circles)
            filled_char="\xe2\x97\x8f"  # U+25CF BLACK CIRCLE
            empty_char="\xe2\x97\x8b"   # U+25CB WHITE CIRCLE
            ;;
        *)
            filled_char="\xe2\x96\x88"  # U+2588 FULL BLOCK
            empty_char="\xe2\x96\x91"   # U+2591 LIGHT SHADE
            ;;
    esac

    local bar=""
    local i=0
    while [ "$i" -lt "$filled" ]; do
        bar="${bar}${filled_char}"
        i=$(( i + 1 ))
    done
    i=0
    while [ "$i" -lt "$empty" ]; do
        bar="${bar}${empty_char}"
        i=$(( i + 1 ))
    done
    printf "%b" "$bar"
}
```

- [ ] **Step 4: Run the runtime test to verify it passes**

Run: `bash tests/runtime_style_test.sh`
Expected: All three tests print PASS lines and the script ends with `All runtime style tests passed.`

- [ ] **Step 5: Commit**

```bash
git add statusline-progress.sh tests/runtime_style_test.sh
git commit -m "$(cat <<'EOF'
feat(runtime): add STYLE variable with circles variant

Adds a STYLE shell variable in statusline-progress.sh that selects
filled/empty characters in make_bar(). "blocks" stays the default;
"circles" renders ●●●○○. Unknown values silently fall back to blocks.

Includes tests/runtime_style_test.sh covering all three cases.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Installer — env-var-driven style selection and patching

**Files:**
- Modify: `install.sh` (insert style-selection block before `# --- patch settings.json`)
- Modify: `tests/install_test.sh` (update Test 1, add Tests 4 and 5)

This task wires up the env-var path only. The interactive TTY prompt comes in Task 3.

- [ ] **Step 1: Update Test 1's strict-diff assertion and add Tests 4 + 5 to `tests/install_test.sh`**

In `tests/install_test.sh`, find the line in Test 1:

```bash
assert "installed script matches source"  "diff -q \"$SOURCE_SCRIPT\" \"$HOME_DIR/.claude/statusline-progress.sh\" >/dev/null"
```

Replace it with:

```bash
assert "installed script has STYLE=\"blocks\" (default)" \
    "grep -qE '^STYLE=\"blocks\"\$' \"$HOME_DIR/.claude/statusline-progress.sh\""
```

Then append Tests 4 and 5 at the end of the file, just before the final `echo "All tests passed."` line:

```bash
# ---------------------------------------------------------------------------
# Test 4: STATUSLINE_STYLE=circles bakes circles into the installed script
# ---------------------------------------------------------------------------
echo "Test 4: STATUSLINE_STYLE=circles installs the circles variant"
HOME_DIR="$(make_fake_home)"
trap 'rm -rf "$HOME_DIR"' EXIT

HOME="$HOME_DIR" STATUSLINE_STYLE=circles bash "$INSTALLER" >/dev/null

assert "installed script has STYLE=\"circles\"" \
    "grep -qE '^STYLE=\"circles\"\$' \"$HOME_DIR/.claude/statusline-progress.sh\""
assert "no leftover sed backup file" \
    "! [ -f \"$HOME_DIR/.claude/statusline-progress.sh.bak\" ]"

rm -rf "$HOME_DIR"
trap - EXIT

# ---------------------------------------------------------------------------
# Test 5: invalid STATUSLINE_STYLE falls back to blocks (still exit 0)
# ---------------------------------------------------------------------------
echo "Test 5: invalid STATUSLINE_STYLE falls back to blocks"
HOME_DIR="$(make_fake_home)"
trap 'rm -rf "$HOME_DIR"' EXIT

set +e
HOME="$HOME_DIR" STATUSLINE_STYLE=neon bash "$INSTALLER" >/dev/null 2>&1
rc=$?
set -e

assert "installer still exits 0 on invalid style" "[ $rc -eq 0 ]"
assert "installed script falls back to STYLE=\"blocks\"" \
    "grep -qE '^STYLE=\"blocks\"\$' \"$HOME_DIR/.claude/statusline-progress.sh\""

rm -rf "$HOME_DIR"
trap - EXIT
```

- [ ] **Step 2: Run install tests to verify Test 1 still passes and 4 + 5 fail**

Run: `bash tests/install_test.sh`
Expected:
- Test 1: PASS (Task 1 already added `STYLE="blocks"` to the source, so the default install carries it through unmodified).
- Test 4: FAIL — installed script still says `STYLE="blocks"` because the installer doesn't patch yet.
- Test 5: same FAIL on the fallback assertion would also surface only if the installer somehow misbehaved; in practice it'll PASS trivially because the script is unmodified — that's OK, we're keeping the assertion to lock in the contract.

- [ ] **Step 3: Add style selection and patching to `install.sh`**

In `install.sh`, between the `info "Installed: $TARGET_SCRIPT"` line (line 78) and the `# --- patch settings.json` comment (line 80), insert:

```bash

# --- pick and bake the progress-bar style ---------------------------------

valid_style() {
    case "$1" in
        blocks|circles) return 0 ;;
        *) return 1 ;;
    esac
}

chosen_style=""
if [ -n "${STATUSLINE_STYLE:-}" ]; then
    if valid_style "$STATUSLINE_STYLE"; then
        chosen_style="$STATUSLINE_STYLE"
    else
        err "Unknown STATUSLINE_STYLE='$STATUSLINE_STYLE'; falling back to blocks."
        chosen_style="blocks"
    fi
fi

if [ -z "$chosen_style" ]; then
    chosen_style="blocks"
fi

# Patch the STYLE= line in the installed copy. -i.bak is the spelling that
# works on both BSD sed (macOS) and GNU sed (Linux).
sed -i.bak "s/^STYLE=.*/STYLE=\"$chosen_style\"/" "$TARGET_SCRIPT"
rm -f "$TARGET_SCRIPT.bak"
info "Style: $chosen_style"
```

- [ ] **Step 4: Run install tests again to verify all pass**

Run: `bash tests/install_test.sh`
Expected: Tests 1–5 all print PASS and the script ends with `All tests passed.`

- [ ] **Step 5: Run the runtime tests too as a sanity check**

Run: `bash tests/runtime_style_test.sh`
Expected: still passing (no runtime changes in this task).

- [ ] **Step 6: Commit**

```bash
git add install.sh tests/install_test.sh
git commit -m "$(cat <<'EOF'
feat(install): pick progress-bar style and patch installed script

Install now reads STATUSLINE_STYLE (blocks|circles) and sed-patches the
STYLE= line in the installed copy of statusline-progress.sh. Unknown
values warn and fall back to blocks. Default with no env var is blocks.

Test 1 in install_test.sh now asserts the STYLE= line directly instead
of byte-equal source diff (the installer mutates the file). Tests 4 and
5 cover the circles and invalid-fallback paths.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Installer — interactive TTY prompt

**Files:**
- Modify: `install.sh` (add the prompt branch in the style-selection block)

This task adds the prompt path. Per the spec, this is **manually verified only** — automated tests cannot exercise a real `/dev/tty`. We use `[ -t 1 ]` (stdout is a terminal) plus `[ -e /dev/tty ]` as the "interactive" check, so the existing tests (which redirect stdout to `/dev/null`) keep landing in the default-blocks branch.

- [ ] **Step 1: Update the style-selection block in `install.sh`**

Find the block added in Task 2:

```bash
if [ -z "$chosen_style" ]; then
    chosen_style="blocks"
fi
```

Replace it with:

```bash
if [ -z "$chosen_style" ]; then
    if [ -t 1 ] && [ -e /dev/tty ]; then
        # Interactive: prompt for a choice. Read from /dev/tty so this works
        # under `curl -fsSL ... | bash`, where stdin is the curl pipe.
        attempts=0
        while [ "$attempts" -lt 3 ]; do
            cat <<'PROMPT'

Choose progress bar style:
  1) blocks   ████████░░  (default)
  2) circles  ●●●●●●●●○○
PROMPT
            printf "Style [1]: "
            choice=""
            read -r choice </dev/tty || choice=""
            case "$choice" in
                ""|1|blocks)  chosen_style="blocks"; break ;;
                2|circles)    chosen_style="circles"; break ;;
                *)
                    err "Invalid choice: '$choice'. Enter 1, 2, blocks, or circles."
                    attempts=$(( attempts + 1 ))
                    ;;
            esac
        done
        [ -z "$chosen_style" ] && chosen_style="blocks"
    else
        chosen_style="blocks"
    fi
fi
```

- [ ] **Step 2: Run all automated tests to verify nothing regressed**

Run:
```bash
bash tests/install_test.sh
bash tests/runtime_style_test.sh
```
Expected: both scripts end with their `All ... passed.` line. Tests 1–5 in install_test.sh stay green because stdout is redirected to `/dev/null` in those tests, which makes `[ -t 1 ]` false and the prompt path is never reached.

- [ ] **Step 3: Manually verify the prompt in a terminal**

Run interactively (as your real user, in a real terminal):

```bash
cd /tmp
mkdir -p fake-home/.claude
HOME=$PWD/fake-home bash /Users/mirza/Workspace/claude-code-status-line/install.sh
```

Expected: the prompt appears, defaults to blocks on Enter, accepts `2` or `circles` for the circles variant, re-prompts (up to 3 times) on bogus input, and after install:

```bash
grep '^STYLE=' fake-home/.claude/statusline-progress.sh
```

shows the value you picked.

Clean up:
```bash
rm -rf /tmp/fake-home
```

- [ ] **Step 4: Commit**

```bash
git add install.sh
git commit -m "$(cat <<'EOF'
feat(install): interactive style prompt under a real TTY

When STATUSLINE_STYLE is unset and stdout is a terminal with /dev/tty
available, install.sh now prompts for the style and reads the answer
from /dev/tty (so curl|bash flows work). Up to 3 invalid attempts
before defaulting to blocks. Non-interactive contexts still default to
blocks silently.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: README updates

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add a "Styles" section and update the install instructions**

In `README.md`, immediately after the "What it shows" section (after line 16), insert the following content (the outer 4-backtick fence is just for this plan; in README itself the inner 3-backtick fences are the real fences):

````markdown

## Styles

Two progress-bar styles are available. Pick one when you install — to switch later, re-run the installer.

**Blocks** (default):

```
Context ████████░░ 78% │ Usage ███░░░░░░░ 32% (3h 12m / 5h)
```

**Circles**:

```
Context ●●●●●●●●○○ 78% │ Usage ●●●○○○○○○○ 32% (3h 12m / 5h)
```
````

Then update the **Install — one-liner** section (around line 26–38). Replace the existing "This will:" list with the content below (again, outer 4-backtick fence is for this plan only):

````markdown
This will:

1. Back up `~/.claude/settings.json` to `~/.claude/settings.json.backup-<timestamp>` (if one exists).
2. Download `statusline-progress.sh` to `~/.claude/` and make it executable.
3. Prompt you to choose a style (blocks or circles); your choice is baked into the installed script.
4. Patch `~/.claude/settings.json` to set `statusLine` to the installed script. Other settings are preserved.

Skip the prompt non-interactively:

```bash
curl -fsSL https://raw.githubusercontent.com/mirzaakhena/claude-code-status-line/main/install.sh \
  | STATUSLINE_STYLE=circles bash
```

Restart Claude Code afterward.
````

In the **Install — manual** section (around line 41–62), add a new step 2 between the existing steps 1 and 2 (renumbering the rest accordingly):

````markdown
2. Pick a style by editing the `STYLE=` line near the top of `~/.claude/statusline-progress.sh`:
   ```bash
   STYLE="blocks"   # or: STYLE="circles"
   ```
````

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "$(cat <<'EOF'
docs(readme): document blocks/circles styles and selection

Adds a Styles section showing both variants and explains how the
installer picks one (interactive prompt or STATUSLINE_STYLE env var).
Notes that re-running install is how to switch.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Final verification

- [ ] Run both test suites once more from a clean working tree:
  ```bash
  bash tests/install_test.sh
  bash tests/runtime_style_test.sh
  ```
  Expected: both end with their "All ... passed." line.

- [ ] Skim `git log --oneline -n 5` — there should be four new commits (runtime, installer env path, installer TTY prompt, README), each focused.
