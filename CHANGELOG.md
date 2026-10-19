# Changelog

All notable changes to this plugin are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the plugin follows
[Semantic Versioning](https://semver.org/). `manifest.json` holds the current version.

## [Unreleased]

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

[Unreleased]: https://github.com/stewartjarod/omarchy-phone-sessions/compare/v0.1.2...HEAD
[0.1.2]: https://github.com/stewartjarod/omarchy-phone-sessions/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/stewartjarod/omarchy-phone-sessions/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/stewartjarod/omarchy-phone-sessions/releases/tag/v0.1.0
