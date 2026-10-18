# Contributing

## Commits: Conventional Commits

Every commit's first line is `<type>(<scope>)<!>: <subject>` (max 100 characters):

| Type | Use for | Version bump |
|---|---|---|
| `feat` | a new capability for users | minor |
| `fix` | a bug fix | patch |
| `perf`, `refactor` | code changes with no new behaviour | patch |
| `docs`, `test`, `style`, `build`, `ci`, `chore` | everything else | none |

A `!` after the type, or a `BREAKING CHANGE:` line in the body, marks a breaking change (settings
renamed or removed, a changed IPC name, a moved state file). While the version is `0.x`, a breaking
change bumps the minor number; from `1.0.0` it bumps the major.

The hook is already enabled by the scaffold. In a fresh clone run `git config core.hooksPath .githooks`.
CI checks every pushed commit regardless, so `--no-verify` only delays the failure.

## Versions

`manifest.json` holds the version; there is no other copy. Do not edit it by hand.

```sh
scripts/release.sh --dry-run   # shows the next version and the changelog entries
scripts/release.sh             # updates manifest.json + CHANGELOG.md, commits chore(release), tags vX.Y.Z
git push origin HEAD vX.Y.Z
```

Under `## [Unreleased]` in `CHANGELOG.md` you may write entries by hand (they win over generated ones).
After pushing the release, ask the marketplace to verify that exact commit:

```sh
scripts/marketplace-request.sh submit --category Widgets --tags bar   # first listing
scripts/marketplace-request.sh update                                 # every later release
```

Both print the issue (and the `gh issue create` command); they never open it for you. Verification
belongs to one commit, so do not push to the default branch while a request is open.

## Checks

`tests/run-all.sh` runs everything that works without the desktop, including the theme lint and the
token-existence check and the marketplace pre-flight (the marketplace's own security scanner). It must pass
before a push; run `tests/fetch-marketplace.sh` once so the pre-flight is not skipped locally. `tests/smoke.sh` is the live check.
