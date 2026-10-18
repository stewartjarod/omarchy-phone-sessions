#!/usr/bin/env bash
# Live smoke test for stewartjarod.phone-sessions.
#
# Run by hand in the desktop session, AFTER the shell has loaded the plugin (`omarchy restart shell`,
# once; a second quick restart races and can leave you with no bar). It asks the running shell over
# IPC whether the plugin is registered and reads the shell log for QML warnings that mention it.
# It changes nothing.
#
# Exit status: 0 when every check passes, 1 when any check fails.
# Usage:  tests/smoke.sh            (OMARCHY_PATH defaults to /usr/share/omarchy)

set -u

OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}"
SHELL_DIR="$OMARCHY_PATH/shell"
ID="stewartjarod.phone-sessions"
fails=0

pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); }

for tool in qs jq timeout; do
  command -v "$tool" >/dev/null 2>&1 || { printf 'FAIL  required command not found: %s\n' "$tool"; exit 1; }
done
[ -f "$SHELL_DIR/shell.qml" ] || { printf 'FAIL  omarchy shell not found at %s\n' "$SHELL_DIR"; exit 1; }

# IPC calls can hang for ~25 s while the shell starts; always wrap them in timeout.
plugins=$(timeout 40 quickshell ipc -p "$SHELL_DIR" call shell listPlugins 2>&1) || { fail "shell did not answer listPlugins"; exit 1; }
if printf '%s' "$plugins" | jq -e --arg id "$ID" '.. | objects | select(.id? == $id)' >/dev/null 2>&1; then
  pass "plugin $ID is registered with the shell"
else
  fail "plugin $ID is not registered (enable it: omarchy plugin enable $ID)"
fi

# Plugin-specific IPC target (see Service.qml). Remove this block if the plugin has no service.
if grep -q '"service"' "$(dirname "$0")/../manifest.json"; then
  if [ "$(timeout 40 quickshell ipc -p "$SHELL_DIR" call "$ID" ping 2>/dev/null)" = "ok" ]; then
    pass "service answers ping"
  else
    fail "service did not answer ping"
  fi
fi

# Theme: the plugin must not be the source of colour/font warnings.
if journalctl --user -b --no-pager 2>/dev/null | grep -i "$ID" | grep -Ei 'is not a type|ReferenceError|TypeError|Unable to assign|undefined' | head -n 5 | grep -q .; then
  fail "shell log has QML errors mentioning $ID (journalctl --user -b | grep $ID)"
else
  pass "no QML errors for $ID in the shell log"
fi

echo
[ "$fails" -eq 0 ] && echo "smoke: passed" || echo "smoke: FAILED ($fails)"
[ "$fails" -eq 0 ]
