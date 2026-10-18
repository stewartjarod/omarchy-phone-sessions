import QtQuick
import Quickshell
import Quickshell.Io

// stewartjarod.phone-sessions service: the single owner of state for this plugin (one instance per shell).
// Bar widgets exist once per monitor, so they read from here and stay thin.
// Register IPC targets here, never in the widget.
Item {
  id: root

  // ---- settings (pushed in by the bar widget from shell.json) -------------
  property var settings: ({})
  function applySettings(s) { settings = s || ({}) }

  // ---- paths: keep state under XDG dirs, never inside the plugin directory --
  readonly property string home: Quickshell.env("HOME")
  readonly property string stateDir: home + "/.local/state/phone-sessions"

  IpcHandler {
    target: "stewartjarod.phone-sessions"
    function ping(): string { return "ok" }
  }
}
