# Phone Sessions

Hotkey picker for Claude Code sessions started from your phone; opens the one you pick in a new terminal tab.

Requires Omarchy 4.0.4 or newer (`OMARCHY_MIN_VERSION`).

Sessions you start from the Claude app through `claude remote-control` run on this machine, but Claude
Code's own `/resume` picker hides them: their transcripts are recorded as SDK sessions
(`"entrypoint": "sdk-cli"`). This overlay lists exactly those sessions, newest first. Pick one and it
focuses your most recently used Ghostty window, opens a new tab, and types
`. <plugin>/scripts/resume-here <id>` into it, which `cd`s to the session's folder and runs `claude --resume <id>` in that shell. With no Ghostty window open, it starts a new terminal instead.

Rows marked **running on phone** were written to in the last two minutes. Resuming one in the terminal
stops the Remote Control process that is running it.

## Requirements

- Ghostty (Omarchy's default terminal) with its default `Ctrl+Shift+T` new-tab binding
- `wtype`, `jq`, `python3` (all present on a standard Omarchy install)
- Claude Code with Remote Control sessions in `~/.claude/projects` (or `$CLAUDE_CONFIG_DIR/projects`)

## Install

```sh
omarchy plugin add https://github.com/stewartjarod/omarchy-phone-sessions.git --enable
```

Bind a key in `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + SHIFT + R", "Resume a phone session", "omarchy-shell shell toggle stewartjarod.phone-sessions")
```

## Keys

`↑`/`↓` (or `Ctrl+P`/`Ctrl+N`) select · `Enter` open · type to filter by folder or prompt · `Esc` clears the filter, then closes.

## Remove

```sh
omarchy plugin remove stewartjarod.phone-sessions
```

Then delete the bind.

## Where things are stored

Nothing. The plugin reads transcripts on each open and writes no files.

## Privacy

The plugin reads `~/.claude/projects/*/*.jsonl` locally, to get each session's folder and first prompt.
Nothing leaves the machine. The only thing it types is the resume command, into a terminal tab it has just
opened, and only if that window still has keyboard focus.

## Development

```sh
tests/run-all.sh                       # lint, theme + token checks, unit tests (no desktop needed)
scripts/open-session --dry-run DIR ID  # show which window and command would be used
tests/smoke.sh                         # live check against the running shell
scripts/release.sh                     # cut a release from Conventional Commits
```

See [CONTRIBUTING.md](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md).
