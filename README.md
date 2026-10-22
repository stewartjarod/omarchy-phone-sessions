# Phone Sessions

Hotkey picker for Claude Code sessions started from your phone; opens the one you pick in your default terminal (a new tab where it can).

Requires Omarchy 4.0.4 or newer (`OMARCHY_MIN_VERSION`).

Sessions you start from the Claude app through `claude remote-control` run on this machine, but Claude
Code's own `/resume` picker hides them: their transcripts are recorded as SDK sessions
(`"entrypoint": "sdk-cli"`). This overlay lists exactly those sessions, newest first. Pick one and it opens
in your default terminal (the one `xdg-terminal-exec` and `omarchy default terminal` use), in the session's
folder, running `claude --resume <id>`:

| Default terminal | Opens |
|---|---|
| Ghostty, kitty | A new tab in that terminal's most recently focused window, if the bash hook below is installed. Otherwise a new window. |
| Alacritty, foot, anything else | A new window. |

The tab or window is titled with the session's title, else the start of its first prompt, until Claude
sets its own title. That text is set with a terminal escape sequence and never put on a command line,
where other users on the machine could read it. The session always runs in your
interactive shell, so shell functions such as a `claude` wrapper apply. Nothing is typed into a terminal.

Each tab opens with up to 20 sessions from the last week, newest first. When older ones exist, the
list ends with a **Load older sessions** row: its caption says what is listed so far ("Showing the last
7 days", "Showing the 20 newest"), and `Enter` on it adds the next 20, going back past the week. Typing
filters only the sessions loaded so far, so load more if a session you want doesn't match.

Rows marked **running on phone** were written to in the last two minutes. Resuming one in the terminal
stops the Remote Control process that is running it.

Press `Tab` for the **Closed** tab: terminal sessions that no running Claude
process holds, because their terminal was closed or the machine restarted. Each row says how it stopped:
**closed mid-task**, **stopped by a usage limit**, or **closed** after a finished reply. Opening one works
the same way as a phone session. It resumes with no new message, so tell a session that was mid-task to
carry on; anything it ran in the background (subagents, dev servers) is gone. A session counts as running
when Claude Code's `~/.claude/sessions/<pid>.json` record names it and that process is still alive.

Tested on Ghostty (tab and window) and foot. kitty and Alacritty use the same paths but have not been tried.

## Requirements

- Hyprland (Omarchy), `xdg-terminal-exec`, `jq`, `python3`: all present on a standard Omarchy install
- For tabs: Ghostty or kitty with the default `Ctrl+Shift+T` new-tab shortcut, and bash as your shell
  (the hand-off hook is bash-only; zsh and fish get a new window)

## Install

```sh
omarchy plugin add https://github.com/stewartjarod/omarchy-phone-sessions.git --enable
```

Optional, for tabs in Ghostty or kitty: add the hand-off hook as the **last** line of `~/.bashrc` (after
anything that defines a `claude` wrapper). Without it, sessions open in a new window.

```bash
[[ -f ~/.config/omarchy/plugins/stewartjarod.phone-sessions/scripts/shell-hook.bash ]] && source ~/.config/omarchy/plugins/stewartjarod.phone-sessions/scripts/shell-hook.bash
```

The hook runs this plugin's code in every interactive bash you start, so plugin updates reach your
terminals too, not just omarchy-shell. Apart from creating its folder once, it runs only shell builtins
until a hand-off is waiting.

Bind a key in `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + SHIFT + R", "Resume a phone session", "omarchy-shell shell toggle stewartjarod.phone-sessions")
```

## Keys

`↑`/`↓` (or `Ctrl+P`/`Ctrl+N`) select (`↑` from the top jumps to **Load older sessions**) · `Enter` open, or load older · `Tab` switch between Phone and Closed · type to filter by folder or prompt · `Esc` clears the filter, then closes.

## Remove

```sh
omarchy plugin remove stewartjarod.phone-sessions
```

Then delete the bind and the `~/.bashrc` line.

## Where things are stored

Only in `$XDG_RUNTIME_DIR/phone-sessions/` (dir 0700, cleared at logout or reboot): `next` (0600) holds the
chosen session id for the moment between picking and the new tab's shell starting, and hand-offs older than
5 seconds are ignored; `hook` is an empty marker the bash hook touches so the picker knows tabs will work.

## Privacy

The plugin reads `~/.claude/projects/*/*.jsonl` locally, to get each session's folder, title, first prompt
and how its last turn ended, and `~/.claude/sessions/*.json` to tell which sessions are still running.
Nothing leaves the machine. It types nothing; the session id reaches the new tab through the runtime file
above, or a new window through its command line.

## Development

```sh
tests/run-all.sh                       # lint, theme + token checks, unit tests (no desktop needed)
scripts/open-session --dry-run DIR ID  # show which window and command would be used
tests/smoke.sh                         # live check against the running shell
scripts/release.sh                     # cut a release from Conventional Commits
```

See [CONTRIBUTING.md](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md).
