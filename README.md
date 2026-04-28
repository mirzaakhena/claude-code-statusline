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

## Styles

Two progress-bar styles are available. Pick one when you install. To switch later, either re-run the installer (one-liner path) or edit the `STYLE=` line in `~/.claude/statusline-progress.sh` directly.

**Blocks** (default):

```
Context ████████░░ 78% │ Usage ███░░░░░░░ 32% (3h 12m / 5h)
```

**Circles**:

```
Context ●●●●●●●●○○ 78% │ Usage ●●●○○○○○○○ 32% (3h 12m / 5h)
```

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
3. Prompt you to choose a style (blocks or circles); your choice is baked into the installed script.
4. Patch `~/.claude/settings.json` to set `statusLine` to the installed script. Other settings are preserved.

Skip the prompt non-interactively:

```bash
curl -fsSL https://raw.githubusercontent.com/mirzaakhena/claude-code-status-line/main/install.sh \
  | STATUSLINE_STYLE=circles bash
```

`STATUSLINE_STYLE` accepts `blocks` or `circles`. Unknown values fall back to `blocks` with a warning.

Restart Claude Code afterward.

## Install — manual

If you prefer to install by hand:

1. Download the script:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/mirzaakhena/claude-code-status-line/main/statusline-progress.sh \
     -o ~/.claude/statusline-progress.sh
   chmod +x ~/.claude/statusline-progress.sh
   ```

2. Pick a style by editing the `STYLE=` line near the top of `~/.claude/statusline-progress.sh`:
   ```bash
   STYLE="blocks"   # or: STYLE="circles"
   ```

3. Open `~/.claude/settings.json` and add (or merge) this block:
   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "/Users/YOUR_USERNAME/.claude/statusline-progress.sh"
     }
   }
   ```
   Replace `/Users/YOUR_USERNAME` with the absolute path to your home directory (`echo $HOME`).

4. Restart Claude Code.

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
