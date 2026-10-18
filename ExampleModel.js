.pragma library

// Pure logic lives in *.js files like this one: no QML, no Quickshell, no I/O. That keeps it
// testable with plain `node --test` (see tests/example.test.js). QML files stay thin glue.

function greeting(name) {
  var n = String(name || "").trim()
  return n === "" ? "Hello" : n
}

if (typeof module !== "undefined") module.exports = { greeting }
