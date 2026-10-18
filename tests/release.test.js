"use strict"
// Version hygiene: one valid SemVer in manifest.json that matches the changelog, and the
// Conventional Commits hook (.githooks/commit-msg) accepts and rejects the right first lines.
const test = require("node:test")
const assert = require("node:assert/strict")
const fs = require("fs")
const os = require("os")
const path = require("path")
const { spawnSync } = require("child_process")

const ROOT = path.join(__dirname, "..")
const SEMVER = /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$/
const man = () => JSON.parse(fs.readFileSync(path.join(ROOT, "manifest.json"), "utf8"))
const log = () => fs.readFileSync(path.join(ROOT, "CHANGELOG.md"), "utf8")
const key = (v) => v.split(/[-+]/)[0].split(".").map(Number)

test("manifest.json has a valid SemVer version and a namespaced id", () => {
  assert.match(man().version, SEMVER)
  assert.match(man().id, /^[a-z0-9]+(\.[a-z0-9-]+)+$/, "id is <owner>.<name>")
})

test("manifest kinds and entry points agree, and the files exist", () => {
  const m = man()
  const want = { "bar-widget": ["barWidget", "barWidget"], service: ["service", null], overlay: ["overlay", null] }
  for (const k of m.kinds) {
    assert.ok(want[k], "known kind " + k)
    const file = m.entryPoints[want[k][0]]
    assert.ok(file, "entry point for " + k)
    assert.ok(fs.existsSync(path.join(ROOT, file)), file + " exists")
    if (want[k][1]) assert.ok(m[want[k][1]], k + " block present")
  }
})

test("OMARCHY_MIN_VERSION is a version", () => {
  assert.match(fs.readFileSync(path.join(ROOT, "OMARCHY_MIN_VERSION"), "utf8").trim(), /^\d+\.\d+\.\d+$/)
})

test("CHANGELOG.md starts with Unreleased and its newest release is the manifest version", () => {
  const heads = [...log().matchAll(/^## \[([^\]]+)\](?: - (\d{4}-\d{2}-\d{2}))?$/gm)]
  assert.ok(heads.length >= 1, "an Unreleased section")
  assert.equal(heads[0][1], "Unreleased", "Unreleased comes first")
  const released = heads.filter((h) => h[1] !== "Unreleased")
  if (released.length === 0) {
    assert.equal(man().version, "0.0.0", "only 0.0.0 may have no released section")
    return
  }
  assert.equal(released[0][1], man().version)
  for (const h of released) {
    assert.match(h[1], SEMVER)
    assert.ok(h[2], "release " + h[1] + " has a date")
    assert.ok(log().includes("[" + h[1] + "]: https://"), "link for " + h[1])
  }
  for (let i = 1; i < released.length; i++) {
    const a = key(released[i - 1][1]), b = key(released[i][1])
    assert.ok(a[0] > b[0] || (a[0] === b[0] && (a[1] > b[1] || (a[1] === b[1] && a[2] > b[2]))), "versions descend")
  }
})

function hook(line) {
  const f = path.join(fs.mkdtempSync(path.join(os.tmpdir(), "cm-")), "MSG")
  fs.writeFileSync(f, line + "\n\nbody\n")
  const r = spawnSync("sh", [path.join(ROOT, ".githooks", "commit-msg"), f], { encoding: "utf8" })
  fs.rmSync(path.dirname(f), { recursive: true, force: true })
  return r
}

test("commit-msg hook accepts Conventional Commits", () => {
  for (const ok of [
    "feat: add a thing",
    "fix(setup): find the book after the first download",
    "feat(sync)!: rename the position setting",
    "chore(release): 0.2.0",
    "docs: add a changelog",
    "Merge branch 'x'",
    'Revert "feat: x"'
  ]) assert.equal(hook(ok).status, 0, ok)
})

test("commit-msg hook rejects everything else", () => {
  for (const bad of [
    "Added a thing",
    "feat add a thing",
    "feat:no space",
    "Feat: capitalised type",
    "feature: wrong type",
    "fix(): empty scope",
    "wip",
    "feat: " + "x".repeat(100)
  ]) assert.notEqual(hook(bad).status, 0, bad)
})
