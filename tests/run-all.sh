#!/usr/bin/env bash
# Runs every check that works without the desktop:
#   1. duplicate root signal handlers   (breaks a QML file at load time; qmllint misses it)
#   2. no always-present text input     (a marketplace review finding: it listens to the clipboard)
#   3. privacy scan                     (tests/privacy.sh: no home paths, e-mails or secrets committed)
#   3b. theme lint                       (tests/theme-lint.sh: no hard-coded colours/fonts/radii)
#   4. token existence                  (tests/tokens.js: every Color./Style. token exists in the shell)
#   5. Omarchy minimum version note     (OMARCHY_MIN_VERSION vs the installed shell)
#   5b. marketplace pre-flight          (omarchy plugin validate + the marketplace's own security scanner)
#   6. node --test tests/*.test.js             (pure-model tests, version hygiene, commit hook)
#   7. qmllint over every .qml
# The live checks are NOT here: they need the running shell. See tests/smoke.sh.
#
# Usage: tests/run-all.sh        Exit 0 when everything passes, 1 otherwise.
# CI sets REQUIRE_COMMONS=1 / REQUIRE_MARKETPLACE=1 (those checks may not be skipped), OMARCHY_COMMONS, MARKETPLACE_SCRIPTS.

set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd) || exit 1
cd "$ROOT" || exit 1

TMP=$(mktemp -d) || exit 1
cleanup() {
  if [ -n "${TMP:-}" ] && [ -d "$TMP" ]; then
    find "${TMP:?}" -mindepth 1 -delete
    rmdir "${TMP:?}"
  fi
}
trap cleanup EXIT

status=0

# ------------------------------------------------------------------ duplicate handlers
# A second `onXChanged` on the same root item breaks the whole file at load time ("Property value set
# multiple times"); qmllint does not catch it, and the plugin then refuses to load.
echo "== duplicate root signal handlers"
dups=$(for f in *.qml; do [ -f "$f" ] && grep -o -E '^  on[A-Z][A-Za-z]*(Changed)?:|^  on[A-Z][A-Za-z]*(Changed)?\b' "$f" | sed 's/:$//' | sort | uniq -d | sed "s|^|$f: |"; done)
if [ -n "$dups" ]; then echo "$dups"; status=1; else echo "none"; fi

# ------------------------------------------------------------------ text inputs
# A text input that exists all the time listens to clipboard changes inside the shell, even with the
# popup closed. Create it from a Loader whose `active` is true only while it is needed, and add that
# file to ALLOW below (one file name per entry, space separated).
echo "== text inputs only where allowed"
ALLOW=""
inputs=$(grep -n -E '^[[:space:]]*(TextField|TextInput|TextArea)[[:space:]]*\{' $(find . -name '*.qml' -not -path './.git/*' -not -path './tests/*' -not -path './.omarchy-ref/*') 2>/dev/null || true)
for a in $ALLOW; do inputs=$(printf '%s\n' "$inputs" | grep -v "/$a:" || true); done
if [ -n "$(printf '%s' "$inputs" | tr -d '[:space:]')" ]; then echo "$inputs"; status=1; else echo "none"; fi

# ------------------------------------------------------------------ theme
echo "== theme lint"
bash tests/theme-lint.sh || status=1

echo "== privacy scan"
bash tests/privacy.sh || status=1

echo "== theme tokens exist in the installed shell"
node tests/tokens.js
rc=$?
if [ "$rc" -eq 1 ]; then
  status=1
elif [ "$rc" -eq 2 ]; then
  if [ "${REQUIRE_COMMONS:-0}" = 1 ]; then echo "tokens: REQUIRE_COMMONS is set but Commons was not found"; status=1; fi
fi

# ------------------------------------------------------------------ minimum Omarchy version
echo "== Omarchy minimum version"
MIN=$(tr -d '[:space:]' < OMARCHY_MIN_VERSION 2>/dev/null || true)
# `omarchy-version` is the reliable source (the version file under /usr/share/omarchy can be stale).
INSTALLED=$( (omarchy-version 2>/dev/null || cat "${OMARCHY_PATH:-/usr/share/omarchy}/version" 2>/dev/null) | sed -nE 's/^([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' | head -n1)
if [ -z "$INSTALLED" ]; then
  echo "note: no installed Omarchy found; the token check above ran against: ${OMARCHY_COMMONS:-nothing}"
elif [ -n "$MIN" ] && [ "$(printf '%s\n%s\n' "$MIN" "$INSTALLED" | sort -V | head -n1)" != "$MIN" ]; then
  echo "WARNING: installed Omarchy $INSTALLED is older than the minimum $MIN."
  echo "         The token check ran against $INSTALLED, so it does not prove $MIN compatibility."
  echo "         Check against upstream: OMARCHY_COMMONS=\$(tests/fetch-commons.sh) node tests/tokens.js"
else
  echo "installed $INSTALLED >= minimum $MIN"
fi

# ------------------------------------------------------------------ marketplace verification
echo "== omarchy plugin validate (the shell's own manifest rules)"
if command -v omarchy >/dev/null 2>&1; then
  omarchy plugin validate . && echo "ok" || status=1
else
  echo "note: omarchy not installed; skipped (the marketplace pre-flight below re-checks the listing rules)"
fi

echo "== marketplace pre-flight (listing rules + the marketplace's own security scanner, on committed HEAD)"
MP_SCRIPTS="${MARKETPLACE_SCRIPTS:-}"
[ -n "$MP_SCRIPTS" ] || MP_SCRIPTS=$(ls -d .omarchy-ref/marketplace/*/scripts 2>/dev/null | head -n1 || true)
if [ -n "$MP_SCRIPTS" ] && git rev-parse -q --verify HEAD >/dev/null 2>&1; then
  node tests/marketplace-preflight.mjs --scripts "$MP_SCRIPTS" || status=1
elif [ "${REQUIRE_MARKETPLACE:-0}" = 1 ]; then
  echo "marketplace-preflight: REQUIRE_MARKETPLACE is set but the scanner or a git HEAD is missing"; status=1
else
  echo "skipped: run tests/fetch-marketplace.sh once (needs network) and commit your work; CI always runs it"
fi

# ------------------------------------------------------------------ node
echo "== node --test tests/*.test.js"
if node --test tests/*.test.js > "$TMP/node.out" 2>&1; then
  grep -E '^ℹ (tests|pass|fail) ' "$TMP/node.out"
else
  grep -E '^✖|^ℹ (tests|pass|fail) ' "$TMP/node.out" | head -n 40
  echo "node tests FAILED"
  status=1
fi

# ------------------------------------------------------------------ qmllint
QMLLINT="${QMLLINT:-/usr/lib/qt6/bin/qmllint}"
if [ ! -x "$QMLLINT" ]; then
  QMLLINT=$(command -v qmllint 2>/dev/null || true)
fi
if [ -z "$QMLLINT" ]; then
  echo "== qmllint: not found (set QMLLINT or install the Qt 6 declarative tools)"
  status=1
else
  echo "== qmllint over every .qml"
  # Known noise from running outside the Omarchy shell (qs.* and Quickshell modules are not on the lint path,
  # e.g. on a CI runner; then Color resolves to Qt's own type)
  # and from qmllint's stricter style checks. Anything else reported as Error or Warning fails.
  NOISE='Unqualified access|Failed to import qs\.|importing module "qs\.|Did you add all imports|is used but it is not resolved|inheritance cycle|not found on type "QObject"|unknown grouped property scope|is missing required property|Failed to import Quickshell|Warnings occurred while importing module|not found on type "QQuickColor"|not found on type \[missing-property\]|unknown attached property scope|Type PanelWindow is not creatable'
  : > "$TMP/lint.real"
  count=0
  while IFS= read -r f; do
    count=$((count + 1))
    "$QMLLINT" "$f" > "$TMP/lint.one" 2>&1
    grep -E '^(Error|Warning):' "$TMP/lint.one" | grep -vE "$NOISE" | sed "s|^|$f: |" >> "$TMP/lint.real" || true
  done < <(find . -name '*.qml' -not -path './.git/*' -not -path './tests/*' -not -path './.omarchy-ref/*' | sort)
  if [ -s "$TMP/lint.real" ]; then
    echo "qmllint: real problems in $(wc -l < "$TMP/lint.real") place(s) across $count file(s):"
    sed 's/^/  /' "$TMP/lint.real"
    status=1
  else
    echo "qmllint: $count file(s), no real errors"
  fi
fi

echo
if [ "$status" -eq 0 ]; then
  echo "run-all: passed"
else
  echo "run-all: FAILED"
fi
exit "$status"
