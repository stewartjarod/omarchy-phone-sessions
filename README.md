# Phone Sessions

Hotkey picker for Claude Code sessions started from your phone; opens the one you pick in a new terminal tab.

Requires Omarchy 4.0.4 or newer (`OMARCHY_MIN_VERSION`).

## Requirements

List every external dependency (packages, CLIs, accounts) and how to get it. The marketplace submission
checklist asks you to document them.

## Install

```sh
omarchy plugin add https://github.com/stewartjarod/omarchy-phone-sessions.git --enable
```


## Remove

```sh
omarchy plugin remove stewartjarod.phone-sessions
```

## Settings

| Setting | Default | What it does |
|---|---|---|
| `greeting` | `Hello` | Example setting. Replace it. |

## Where things are stored

| What | Where | Notes |
|---|---|---|
| Plugin state | `~/.local/state/phone-sessions/` | Created mode 0700, files 0600. Nothing is stored in the plugin directory. |

## Privacy

State what the plugin reads, what leaves the machine and where it goes, and that credentials are never
written to files, command lines or logs. (The marketplace reviews this; keep it accurate.)

## Development

```sh
tests/run-all.sh        # lint, theme + token checks, unit tests (no desktop needed)
tests/smoke.sh          # live check against the running shell
scripts/release.sh      # cut a release from Conventional Commits
```

See [CONTRIBUTING.md](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md).

## Before you publish (delete this list when done)

- [ ] Replace the example widget, setting and `ExampleModel.js`
- [ ] Add a `preview.png` screenshot (use sample data; it shows your desktop otherwise)
- [ ] Check it under a light AND a dark theme, and a square and a rounded one
- [ ] Fill `barWidget.category` and `description` in `manifest.json`
- [ ] `tests/fetch-marketplace.sh`, then `tests/run-all.sh`: aim for marketplace outcome `passed` (see AGENTS.md)
- [ ] List dependencies in a Requirements section (the marketplace checklist asks for it)
- [ ] `git remote add origin ...`, push, then `scripts/release.sh` for 0.1.0
