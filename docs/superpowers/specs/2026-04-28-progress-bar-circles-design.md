# Progress bar style variant: circles

Date: 2026-04-28

## Problem

The status line currently renders progress with block characters only:

```
████████░░ 78%
```

We want a second visual variant using filled and empty circles:

```
●●●●●●●●○○ 78%
```

The user picks a variant once at install time. To change variant later, they re-run the installer. The runtime script does not look up configuration — its style is fixed when installed.

## Goals

- Add a `circles` variant alongside the existing `blocks` variant.
- Let the user choose during install, with a sensible default and a non-interactive override for `curl | bash` flows and CI.
- Keep the runtime path simple: no env var lookups, no config files, no CLI flags.

## Non-goals

- Custom characters or arbitrary theming.
- Runtime style switching.
- Per-progress-bar styles (Context vs Usage). Both bars use the same style.
- Width changes. Both variants stay 10 segments wide.

## Design

### Runtime script (`statusline-progress.sh`)

A `STYLE` shell variable near the top fixes the variant. Default in the repo source is `blocks`:

```bash
STYLE="blocks"
```

`make_bar()` picks the filled/empty characters from `$STYLE`:

| `$STYLE` | filled    | empty     | codepoints      |
|----------|-----------|-----------|-----------------|
| `blocks` | `█`       | `░`       | U+2588 / U+2591 |
| `circles`| `●`       | `○`       | U+25CF / U+25CB |
| _other_  | _blocks_  | _blocks_  | silent fallback |

No environment variable is read. The source file checked into the repo is runnable as-is and renders blocks. The installer's job is to mutate the `STYLE` line in the *installed copy* to the user's choice.

### Installer (`install.sh`)

Two new responsibilities, both inserted between "copy source to target" and "patch settings.json":

**1. Determine the chosen style.** In priority order:

1. If `STATUSLINE_STYLE` is set in the environment when `install.sh` runs, use it. Validate against `blocks` / `circles`. Invalid value → fall back to `blocks` and print a one-line warning.
2. Else, if `/dev/tty` is readable, prompt:
   ```
   Choose progress bar style:
     1) blocks   ████████░░  (default)
     2) circles  ●●●●●●●●○○
   Style [1]:
   ```
   Read response from `/dev/tty` (this works under `curl | bash`). Empty input → `blocks`. Invalid input → re-prompt up to 3 times, then default to `blocks`.
3. Else (no env, no TTY — CI, scripted install) → `blocks`, no prompt, no warning.

**2. Patch the installed script.** After copying the source to `$TARGET_SCRIPT`:

```bash
sed -i.bak "s/^STYLE=.*/STYLE=\"$chosen_style\"/" "$TARGET_SCRIPT"
rm -f "$TARGET_SCRIPT.bak"
```

`sed -i.bak` is the portable spelling that works on both BSD `sed` (macOS) and GNU `sed` (Linux). The `.bak` is removed immediately. The `^STYLE=` anchor matches the single `STYLE=` line at the top of the file.

After patching, print: `Installed with style: <chosen_style>`.

### Tests (`tests/install_test.sh`)

Extend the existing test file. Each test runs in its own fake `HOME`.

- **Update Test 1 (default install):**
  Replace the `installed script matches source` assertion (now too strict — the installer may mutate the file) with:
  ```
  installed script has STYLE="blocks"
  ```
  Run the installer with no `STATUSLINE_STYLE` env var and stdin redirected from `/dev/null` (non-TTY) so the prompt path is skipped.

- **New Test 4: explicit circles via env var.**
  Run with `STATUSLINE_STYLE=circles`. Assert installed script's `STYLE=` line is `"circles"`.

- **New Test 5: invalid env var falls back to blocks.**
  Run with `STATUSLINE_STYLE=invalid`. Assert `STYLE="blocks"` and assert installer exit code is 0 (warning, not failure).

The interactive `/dev/tty` prompt path is not covered by automated tests — it requires a real TTY. Manual verification only.

### Documentation (`README.md`)

- Add a "Styles" section after "What it shows" showing both variants in fenced code blocks.
- Update the install sections (one-liner + manual) to mention the prompt.
- Add a non-interactive example: `STATUSLINE_STYLE=circles bash <(curl -fsSL ...)`.
- Note that re-running install is how to change style.

## Files touched

- `statusline-progress.sh` — add `STYLE` variable and per-style character selection in `make_bar()`.
- `install.sh` — add style selection (env / TTY prompt / default) and post-copy `sed` patch.
- `tests/install_test.sh` — update Test 1, add Tests 4 and 5.
- `README.md` — document styles and non-interactive override.

## Risks and mitigations

- **`sed -i` portability.** macOS BSD `sed` requires an argument to `-i`; GNU `sed` accepts an empty argument but also accepts `-i.bak`. Using `-i.bak` and then deleting the backup works on both.
- **Pattern reliability.** The `^STYLE=` anchor assumes exactly one line in the script starting with `STYLE=`. The runtime script is small and we control it, so this is safe — but the spec calls it out so future edits to `statusline-progress.sh` keep this invariant.
- **Prompt under `curl | bash`.** Reading directly from `/dev/tty` (not stdin) is the standard pattern for installers piped through bash and works on macOS and Linux.
