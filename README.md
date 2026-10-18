# Phone Sessions

Hotkey picker for Claude Code sessions started from your phone; opens the one you pick in a new terminal tab.

Requires Omarchy 4.0.4 or newer (`OMARCHY_MIN_VERSION`).

Sessions you start from the Claude app through `claude remote-control` run on this machine, but Claude
Code's own `/resume` picker hides them: their transcripts are recorded as SDK sessions
(`"entrypoint": "sdk-cli"`). This overlay lists exactly those sessions, newest first. Pick one and it
focuses your most recently used Ghostty window and opens a new tab. The tab's shell picks the session up
through a small hook in `~/.bashrc`, `cd`s to the session's folder and runs `claude --resume <id> --name=<name>`.
The name (the session's title, else the start of its first prompt) becomes the tab title. It is also saved
as the session's display name, so `/resume` shows it too. Nothing is
typed into the terminal. With no Ghostty window open, it starts a new terminal instead.

Rows marked **running on phone** were written to in the last two minutes. Resuming one in the terminal
stops the Remote Control process that is running it.

## Requirements

- Ghostty (Omarchy's default terminal) with its default `Ctrl+Shift+T` new-tab binding
- bash as your shell, with the hook below; `jq` and `python3` (present on a standard Omarchy install)
- Claude Code with Remote Control sessions in `~/.claude/projects` (or `$CLAUDE_CONFIG_DIR/projects`)

## Install

```sh
omarchy plugin add https://github.com/stewartjarod/omarchy-phone-sessions.git --enable
```

Add the hand-off hook as the **last** line of `~/.bashrc` (after anything that defines a `claude` wrapper):

```bash
[[ -f ~/.config/omarchy/plugins/stewartjarod.phone-sessions/scripts/shell-hook.bash ]] && source ~/.config/omarchy/plugins/stewartjarod.phone-sessions/scripts/shell-hook.bash
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

Then delete the bind and the `~/.bashrc` line.

## Where things are stored

Only the hand-off: `$XDG_RUNTIME_DIR/phone-sessions/next` (dir 0700, file 0600) holds the chosen session id
for the moment between picking and the new tab's shell starting. Hand-offs older than 5 seconds are ignored.

## Privacy

The plugin reads `~/.claude/projects/*/*.jsonl` locally, to get each session's folder and first prompt.
Nothing leaves the machine. It types nothing; the session id is handed to the new tab through the runtime
file above.

## Development

```sh
tests/run-all.sh                       # lint, theme + token checks, unit tests (no desktop needed)
scripts/open-session --dry-run DIR ID  # show which window and command would be used
tests/smoke.sh                         # live check against the running shell
scripts/release.sh                     # cut a release from Conventional Commits
```

See [CONTRIBUTING.md](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md).
