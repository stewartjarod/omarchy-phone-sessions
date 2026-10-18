"use strict"
// The checks that guard theme compatibility must themselves be proven: a planted violation fails,
// a clean file and an annotated exception pass.
const test = require("node:test")
const assert = require("node:assert/strict")
const path = require("path")
const { spawnSync } = require("child_process")

const T = __dirname
const run = (cmd, args) => spawnSync(cmd, args, { encoding: "utf8" })

test("theme-lint flags every kind of hard-coded style", () => {
  const r = run("bash", [path.join(T, "theme-lint.sh"), path.join(T, "fixtures/theme-bad")])
  assert.equal(r.status, 1)
  for (const what of ["hard-coded hex colour", "Qt.rgba", "named colour", "numeric font size", "hard-coded font family", "numeric corner radius"])
    assert.ok(r.stdout.includes(what), "reports " + what + "\n" + r.stdout)
})

test("theme-lint passes token use, comments, transparent and theme-ok lines", () => {
  const r = run("bash", [path.join(T, "theme-lint.sh"), path.join(T, "fixtures/theme-good")])
  assert.equal(r.status, 0, r.stdout)
})

test("tokens.js reports tokens the shell does not provide, and only those", () => {
  const r = run("node", [path.join(T, "tokens.js"), "--commons", path.join(T, "fixtures/commons"), "--root", path.join(T, "fixtures/tokens-bad")])
  assert.equal(r.status, 1)
  assert.match(r.stdout, /Color\.popups\.notAThing/)
  assert.match(r.stdout, /Style\.noSuchStyle/)
  assert.doesNotMatch(r.stdout, /Color\.foreground|Color\.popups\.text|Style\.space/)
})

test("tokens.js exits 2 (skipped) when Commons is missing", () => {
  const r = run("node", [path.join(T, "tokens.js"), "--commons", "/nonexistent/Commons"])
  assert.equal(r.status, 2)
})
