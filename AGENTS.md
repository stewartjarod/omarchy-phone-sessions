# Phone Sessions (`stewartjarod.phone-sessions`)

An Omarchy shell plugin (Quickshell / QML). Read this before changing anything.

## Non-negotiables (CI enforces them)

- **Theme: tokens only.** Colours come from `import qs.Commons` (`Color.foreground/background/accent/
  urgent/muted`, `Color.popups.*`, `Color.menu.*`, ...). Sizes from `Style.space(n)`, `Style.font.*`,
  `Style.spacing.*`, `Style.cornerRadius`. Never write a hex colour, `Qt.rgba(...)`, a named colour
  (other than `"transparent"`), a numeric `font.pixelSize`, a font family string, or a numeric `radius`.
  Omarchy themes can be light, dark, square or rounded; a hard-coded value breaks on some of them.
  `tests/theme-lint.sh` fails on these. A deliberate exception needs `// theme-ok: <why>` on that line.
- **Tokens must exist.** `tests/tokens.js` checks every `Color.x.y` / `Style.x` you use against the
  shell's `Commons/*.qml`. If it fails after an Omarchy update, upstream renamed a token: fix the
  plugin, don't silence the check. Check upstream: `OMARCHY_COMMONS=$(tests/fetch-commons.sh) node tests/tokens.js`.
- **Minimum Omarchy version** is in `OMARCHY_MIN_VERSION` (the manifest has no such field, so the
  shell does not enforce it; keep README's "Requires" line in sync).
- **Conventional Commits** on every commit: `<type>(<scope>)<!>: <subject>`. `.githooks/commit-msg`
  enforces it locally (it is wired by `core.hooksPath`; re-run `git config core.hooksPath .githooks`
  in a fresh clone) and CI re-checks every pushed commit.
- **Version lives only in `manifest.json`.** Never edit it or `CHANGELOG.md`'s release sections by
  hand: run `scripts/release.sh`. It derives the bump from the commits.
- **No always-present text input.** A `TextField`/`TextInput` that exists while its UI is closed
  listens to every clipboard change inside the shell. Create it from a `Loader` active only when needed.

- **Privacy.** State lives under `~/.local/state/phone-sessions/` with mode 0700 dir / 0600 files. Never put
  credentials in files, command lines or logs. `tests/privacy.sh` fails on committed home paths, e-mail
  addresses and token-like strings; captured fixtures must be scrubbed (replace account names, drop ids)
  and listed in `tests/fixtures/README.md` with the scrub rules.

## Passing marketplace verification

Source: `omacom/omarchy-plugin-marketplace` (`VERIFICATION.md`, `SECURITY.md`, `SUBMISSION.md`). Verification
is a **deterministic static scan of one exact commit** (never AI, never executes your code). It is not a
security audit. `tests/marketplace-preflight.mjs` runs the marketplace's own scanner on your committed HEAD:
`tests/fetch-marketplace.sh` once, then `tests/run-all.sh`.

Outcomes: `passed` (verified automatically) · `review-required` (a maintainer must accept the listed
capabilities; slower, still verifiable) · `needs-fixes` (findings; must be fixed in a new commit).
Of ~5,400 recorded scans about half passed outright, and ~70% of the most popular plugins did.

- **Findings (blocking).** `curl`/`wget` piped to a shell or run later without verification;
  `cargo install --git` without a full 40-char `--rev`; building/running code from an *external* git repo
  without pinning to a full commit (detached checkout); a passwordless `sudoers` rule for `ALL`, a shell,
  or a wildcard of `kill`/`systemctl`/file tools; a PID read from a predictable `/tmp` file and passed to
  `sudo`/`pkexec`. Fix: don't. Pin to a full SHA, use `$XDG_RUNTIME_DIR` for PID/state.
- **Capabilities (cause human review).** Matched on *text*, so READMEs and UI strings count too:
  `installer` (files named like install/setup/uninstall), `privilege` (`sudo`, `pkexec`),
  `package-manager` (`omarchy pkg add`, `pacman -S`, `yay`, `pip/npm/cargo/go/gem install`, `brew`),
  `service-management` (`systemctl`, `systemd-run`, `*.service` units), `remote-build` (`git clone`/`curl`
  from your own repo then running it), `sudoers-modification`, `bundled-executable-binary` (ELF/PE/Mach-O).
  A pure QML/JS plugin triggers none. If you must mention one (e.g. "install mpv with `omarchy pkg add mpv`"),
  that is fine: record it in `marketplace-expected.json` so a *new* one never slips in unnoticed.
- **Scan limits (fail closed).** ≤1,000 relevant files, ≤8 MiB text in total, ≤512 KiB per file; a complete
  binary with a setup-ish name cannot be excluded. Keep fixtures, test data and vendored code small, in
  `tests/`, `fixtures/`, `docs/` or similar (those directories are not scanned as runtime source). No symlinks.
- **Listing rules.** One `manifest.json` at the repo root; lowercase id, not `omarchy.*` (prefer
  `io.github.<owner>.<name>` or `<owner>.<name>`; ids are permanent and never reused); entry points exist;
  root README (install **and** removal, dependencies documented) and LICENSE; optional root `preview.png|jpg|webp|avif`
  (every popular plugin has one). Category and 1-3 tags come from fixed lists: `scripts/marketplace-request.sh`
  validates them and prints the exact issue.
- **Exact-commit binding.** Verification covers one commit. Every later commit shows "Update unverified" until
  promoted via the *Plugin verification* issue form (`scripts/marketplace-request.sh update`). So: batch changes,
  release deliberately, and don't push to the default branch while a request is open. The shell's installer
  fetches mutable HEAD, so what users get may be newer than what was verified.
- **Never** weaken or hand-edit a baseline result, and don't describe verification as a security review.
- Also run `omarchy plugin validate .` (the shell's own manifest rules; `run-all.sh` does it).

## Architecture

- `Service.qml` (kind `service`): exactly one instance per shell. Owns all state, processes, sockets,
  timers, files and the IPC target. State files go under `~/.local/state/phone-sessions/`, never in the plugin dir.
- `Widget.qml` (kind `bar-widget`): instantiated **once per monitor**. Keep it thin; read the service via
  `bar?.shell?.serviceFor("stewartjarod.phone-sessions")`. Register no IPC targets here.
- `*Model.js`: pure logic, no QML/IO, with `.pragma library` and a `module.exports` guard so
  `node --test` can load it (`tests/example.test.js` shows how). Put anything testable here.
- Use `qs.Ui` primitives (`BarIconButton`, `WidgetButton`, `KeyboardPanel`, `PanelKeyCatcher`,
  `Toggle`, `TextField`, ...). Bar clicks only reach registered click targets, so do not use a plain `MouseArea`.
  Study `/usr/share/omarchy/shell/Ui/` and `plugins/` as the style reference.
- Keyboard-first: everything reachable without the mouse, with a one-line key legend at the bottom of
  every popup. Never use a layer-shell overlay with exclusive keyboard focus (it blocks every other app).

## Working on it (gotchas)

- **Develop in a clone outside `~/.config/omarchy/plugins/`.** Every save under that directory reloads
  the shell and leaks ~127 MB. Work in `~/Projects/...`, then install with `omarchy plugin add <path-or-url>`
  or fast-forward the live checkout.
- The picker (an overlay with `keepLoaded`) does not pick up edits via hot reload either: the shell logs
  "reloading" but keeps the old Picker and SessionModel, so a change can look broken or absent.
- Service plugins do not pick up edits via hot reload. Run `omarchy restart shell` **once**, then verify
  `pgrep -f "quickshell -n -p"`. A second quick restart races and leaves you with no bar.
- IPC calls can hang ~25 s while the shell starts: `timeout 40 quickshell ipc -p /usr/share/omarchy/shell call <target> <fn>`.
- `omarchy-shell shell ping` can say "not responding" while the shell is fine.
- Long-running helpers must be launched via `setsid -f uwsm-app -- <cmd>`, or they die with the terminal.
- Collect command output whole (`StdioCollector`); appending huge output line by line to a QML string freezes the shell.
- Never `pkill -f <pattern>` where the pattern appears in your own command line.
- Delete screenshots afterwards; they show your desktop. `scratch/` is git-ignored for that.

## Checks

`tests/run-all.sh` (no desktop needed) must pass before a push; `tests/smoke.sh` is the live check
against the running shell, run after a restart.

## Release

`scripts/release.sh --dry-run`, then `scripts/release.sh`, then `git push origin HEAD vX.Y.Z`.
CI verifies the tag equals the manifest version and publishes the GitHub release from the changelog.
