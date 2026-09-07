# claude-code-statusline

A progress-bar status line for [Claude Code](https://claude.com/claude-code). Shows your context window usage and 5-hour rate-limit usage at a glance.

## Preview

![Preview](./screenshot.png)

Output is colored: **green** below 50%, **yellow** 50–74%, **red** at 75% and above.

## What it shows

- **Context** — context window usage with a 10-dot gauge and percentage.
- **Usage** — 5-hour rate-limit usage with a gauge, percentage, and time remaining until the window resets.

## The gauge

Each dot holds four quarter-steps, so a 10-dot gauge resolves **2.5%** rather than 10%:

| Glyph | Codepoint | Fill |
| :---: | --------- | ---- |
| `○` | U+25CB | empty |
| `◔` | U+25D4 | ¼ |
| `◑` | U+25D1 | ½ |
| `◕` | U+25D5 | ¾ |
| `●` | U+25CF | full |

```
  1%  ◔○○○○○○○○○
 23%  ●●◔○○○○○○○
 50%  ●●●●●○○○○○
 68%  ●●●●●●◕○○○
 99%  ●●●●●●●●●◕
100%  ●●●●●●●●●●
```

Both ends of the scale are clamped on purpose: the gauge never reads empty while anything is in use, and never reads full before the value actually reaches 100%.

The partial glyphs come from the same Unicode block as `○` and `●`, so any font that renders those renders the quarters at a matching size. Their on-screen size follows your terminal's font size; it is not something the script controls.

## Requirements

- [Claude Code](https://claude.com/claude-code) installed (so `~/.claude/` exists).
- `jq` available on `PATH`.
  - macOS: `brew install jq`
  - Debian/Ubuntu: `sudo apt install jq`
  - Fedora: `sudo dnf install jq`

## Install — one-liner

```bash
curl -fsSL https://raw.githubusercontent.com/mirzaakhena/claude-code-statusline/main/install.sh | bash
```

This will:

1. Back up `~/.claude/settings.json` to `~/.claude/settings.json.backup-<timestamp>` (if one exists).
2. Download `statusline-progress.sh` to `~/.claude/` and make it executable.
3. Patch `~/.claude/settings.json` to set `statusLine` to the installed script. Other settings are preserved.

The installer is non-interactive and asks nothing.

Restart Claude Code afterward.

## Install — manual

If you prefer to install by hand:

1. Download the script:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/mirzaakhena/claude-code-statusline/main/statusline-progress.sh \
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

## Tests

```bash
bash tests/render_test.sh
bash tests/install_test.sh
```

## License

MIT — see [LICENSE](./LICENSE).
