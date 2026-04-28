# Design — Sharing `statusline-progress.sh` as a Public GitHub Project

**Date:** 2026-04-28
**Owner:** mirza
**Status:** Approved (pending user review of this doc)

## Goal

Publish the existing `~/.claude/statusline-progress.sh` script (a Claude Code status line that renders progress bars for context window and 5-hour rate-limit usage) as a standalone public GitHub repository so others can install it on their own machines.

## Scope

**In scope:**
- A new repository at `/Users/mirza/Workspace/claude-code-status-line` containing one status line script (`statusline-progress.sh`), an installer, README, and license.
- An installer that supports both local (`./install.sh` after clone) and remote (`curl … | bash`) invocation.
- Instructions for manual installation.

**Out of scope (deferred):**
- Other variants in `~/.claude/` (`statusline-minimalist.sh`, `statusline-robbyrussell.sh`).
- Screenshots of the status line in action — README will use ASCII previews only.
- CI, release tags, package managers (npm/homebrew).
- Automatic updates / version checks.

## Repository Layout

```
claude-code-status-line/
├── README.md
├── LICENSE                  # MIT
├── install.sh               # installer (executable)
├── statusline-progress.sh   # the script users install (executable)
└── .gitignore
```

Five files. No build step, no dependency manager, no CI.

## Component: `statusline-progress.sh`

Verbatim copy of `/Users/mirza/.claude/statusline-progress.sh` as it exists on 2026-04-28. Behavior is unchanged: reads JSON from stdin, renders one line of ANSI-colored output containing two segments separated by `│`:

- **Context** — bar + percentage from `.context_window.used_percentage`
- **Usage** — bar + percentage from `.rate_limits.five_hour.used_percentage`, plus a dim `(Xh Ym / 5h)` time-remaining suffix derived from `.rate_limits.five_hour.resets_at`

Color thresholds: green < 50%, yellow < 75%, red ≥ 75%. Falls back to dim `--` when the corresponding JSON field is missing.

Dependencies inside the script itself: `bash`, `jq`, `date`, `printf`, `awk` — all assumed present on macOS/Linux.

## Component: `install.sh`

### Preconditions checked, in order

1. `bash` is the interpreter (shebang `#!/usr/bin/env bash`).
2. `jq` exists on `PATH`. If missing, print install hint (`brew install jq` for macOS, `apt install jq` / `dnf install jq` for Linux) and exit 1.
3. `~/.claude/` directory exists. If missing, print "Install Claude Code first: https://claude.com/claude-code" and exit 1.

### Mode detection

- **Local mode:** the script is run from a clone (i.e., `statusline-progress.sh` exists in the same directory as `install.sh`). Source file is copied directly.
- **Remote mode:** the script is piped from `curl` (no sibling `statusline-progress.sh` available). The installer fetches `statusline-progress.sh` from the raw GitHub URL: `https://raw.githubusercontent.com/mirzaakhena/claude-code-status-line/main/statusline-progress.sh`.

Detection rule: if a sibling `statusline-progress.sh` is readable next to the running script, use local mode; otherwise fall back to remote mode (download via `curl -fsSL`, fail with a clear error if the download fails).

### Install steps

1. **Backup** `~/.claude/settings.json` to `~/.claude/settings.json.backup-<unix-timestamp>` if the file exists. Print the backup path.
2. **Install script:** copy / download to `~/.claude/statusline-progress.sh`, then `chmod +x`.
3. **Patch `settings.json`** with `jq`:
   - If `~/.claude/settings.json` does not exist, create it with `{"statusLine": {"type": "command", "command": "<HOME>/.claude/statusline-progress.sh"}}`.
   - If it exists, merge `.statusLine = {"type": "command", "command": "<HOME>/.claude/statusline-progress.sh"}` while preserving every other key. Use `jq` with a temp file + atomic `mv` to avoid partial writes.
4. **Print summary** showing: backup path (or "no prior settings.json"), installed script path, and the next steps ("restart Claude Code; to revert, restore the backup or run the snippet under Uninstall in the README").

`<HOME>` is expanded to the absolute path of `$HOME` so the entry in `settings.json` is portable across shells.

### Failure modes

- Missing `jq` → exit before touching anything; nothing changes.
- Missing `~/.claude/` → exit before touching anything.
- Remote download fails (no network, 404) → print error and exit 1; no backup is created and no files are written, because failure happens before step 1.
- `jq` write fails after backup → backup is already on disk, so the user can recover by `cp` from the backup. Surface the backup path in the error message.

No interactive confirmation prompts — keep the installer non-interactive so it can run under `curl … | bash`. The backup mechanism is the safety net.

## Component: `README.md`

Sections, in order:

1. **Title + tagline** — one line: progress-bar status line for Claude Code, shows context window & 5-hour rate-limit usage at a glance.
2. **Preview** — a fenced code block with a representative ASCII rendering, e.g.:
   ```
   Context ████████░░ 78% │ Usage ███░░░░░░░ 32% (3h 12m / 5h)
   ```
   Note that real output is colored (green / yellow / red).
3. **What it shows** — bullet list:
   - Context window usage percentage with a 10-segment progress bar.
   - 5-hour rate-limit usage percentage with a 10-segment progress bar.
   - Time remaining until the 5-hour window resets.
   - Color coding: green below 50%, yellow 50–74%, red 75% and above.
4. **Requirements** — `jq`, an existing Claude Code installation (so `~/.claude/` exists).
5. **Install — one-liner**:
   ```
   curl -fsSL https://raw.githubusercontent.com/mirzaakhena/claude-code-status-line/main/install.sh | bash
   ```
   Note: this writes `~/.claude/statusline-progress.sh` and patches `~/.claude/settings.json` (with backup).
6. **Install — manual** — three steps:
   1. Download `statusline-progress.sh` to `~/.claude/` and `chmod +x`.
   2. Add the `statusLine` block to `~/.claude/settings.json` (snippet provided).
   3. Restart Claude Code.
7. **Uninstall** — two paths:
   - Restore the timestamped backup over `~/.claude/settings.json`.
   - Or manually remove the `statusLine` key from `settings.json` and delete `~/.claude/statusline-progress.sh`.
8. **License** — MIT.

GitHub username is `mirzaakhena` — already baked into the install one-liner.

## Component: `LICENSE`

Standard MIT license, copyright 2026 Mirza Akhena.

## Component: `.gitignore`

Minimal — backup files, macOS metadata:

```
.DS_Store
*.backup-*
```

## Open Questions / Caveats

- **No screenshot:** README relies on ASCII preview only. If users complain the visual is unclear, screenshot can be added later (out of scope for v1).
- **Settings merge semantics:** `jq` `.statusLine = …` overwrites any existing `statusLine` block. This is the intended behavior (we are installing a new status line), but if the user had a custom one configured, it will be replaced. The backup makes this recoverable.
