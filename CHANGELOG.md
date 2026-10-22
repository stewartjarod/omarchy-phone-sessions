# Changelog

All notable changes to this plugin are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the plugin follows
[Semantic Versioning](https://semver.org/). `manifest.json` holds the current version.

## [Unreleased]

## [0.2.1] - 2026-10-21

First published release of the 0.2.0 changes (see 0.2.0 below): the plugin is now **Resume
Sessions**, with a Closed tab for reopening terminal sessions that were closed or stopped, and a
"Load older sessions" row past the 7-day, 20-session first page.

### Fixed
- CI installs python, so the list-sessions tests run. v0.2.0 was tagged but its checks failed on
  that, so it was never published as a GitHub release; 0.2.1 has the same plugin code.

## [0.2.0] - 2026-10-21

### Added
- add a Closed tab for reopening terminal sessions
- list at most 20 sessions from the last week in each tab
- load older sessions from a row at the end of the list
- outline the Load older sessions row
- rename the display name to Resume Sessions

## [0.1.2] - 2026-10-18

### Fixed
- keep the session name off command lines
- accept only a Hyprland address in the focus/new-tab Lua string

## [0.1.1] - 2026-10-18

### Fixed
- legend says terminal, not tab (some terminals get a window)

## [0.1.0] - 2026-10-18

### Added
- pick a phone-started Claude session and resume it in a terminal tab
- hand the session to the new tab's shell instead of typing it
- name the terminal tab after the session
- open in the user's default terminal

### Fixed
- start a new terminal when no Ghostty window is open
- type a Shift-free resume command and look the folder up in the tab
- never type into the terminal; hand-off only

[Unreleased]: https://github.com/stewartjarod/omarchy-phone-sessions/compare/v0.2.1...HEAD
[0.2.1]: https://github.com/stewartjarod/omarchy-phone-sessions/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/stewartjarod/omarchy-phone-sessions/compare/v0.1.2...v0.2.0
[0.1.2]: https://github.com/stewartjarod/omarchy-phone-sessions/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/stewartjarod/omarchy-phone-sessions/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/stewartjarod/omarchy-phone-sessions/releases/tag/v0.1.0
