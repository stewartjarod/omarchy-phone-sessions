"use strict"
const test = require("node:test")
const assert = require("node:assert/strict")
const fs = require("fs")
const path = require("path")

// `.pragma library` is not valid JavaScript for node; strip that line before evaluating.
function load(file) {
  const src = fs.readFileSync(path.join(__dirname, "..", file), "utf8").replace(/^\.pragma library\s*$/m, "")
  const mod = { exports: {} }
  new Function("module", src)(mod)
  return mod.exports
}

const Model = load("SessionModel.js")

const sessions = [
  { id: "a", cwd: "/x/Games", folder: "~/Projects/Games", title: "", prompt: "Review our game engine" },
  { id: "b", cwd: "/x/.config", folder: "~/.config", title: "Agent graph skill", prompt: "Is our agent graph skill global?" },
]

test("parse drops junk and bad JSON", () => {
  assert.deepEqual(Model.parse("not json"), [])
  assert.deepEqual(Model.parse("{}"), [])
  assert.equal(Model.parse(JSON.stringify([...sessions, { id: "c" }, null])).length, 2)
})

test("label prefers the title, then the prompt", () => {
  assert.equal(Model.label(sessions[0]), "Review our game engine")
  assert.equal(Model.label(sessions[1]), "Agent graph skill")
  assert.equal(Model.label({}), "(no prompt)")
})

test("filter matches every word across folder, title and prompt", () => {
  assert.equal(Model.filter(sessions, "").length, 2)
  assert.deepEqual(Model.filter(sessions, "games ENGINE").map(s => s.id), ["a"])
  assert.deepEqual(Model.filter(sessions, ".config agent").map(s => s.id), ["b"])
  assert.deepEqual(Model.filter(sessions, "games agent"), [])
})

test("ago buckets", () => {
  assert.equal(Model.ago(1000, 1030), "just now")
  assert.equal(Model.ago(0, 5 * 60), "5m ago")
  assert.equal(Model.ago(0, 3 * 3600), "3h ago")
  assert.equal(Model.ago(0, 2 * 86400), "2d ago")
  assert.equal(Model.ago(100, 50), "just now")
})

test("stateLabel names how a closed session stopped", () => {
  assert.equal(Model.stateLabel({ state: "limit" }), "stopped by a usage limit")
  assert.equal(Model.stateLabel({ state: "working" }), "closed mid-task")
  assert.equal(Model.stateLabel({ state: "idle" }), "closed")
  assert.equal(Model.stateLabel({}), "")
  assert.equal(Model.stateLabel(null), "")
})

test("needsAttention flags live phone sessions and unfinished closed ones", () => {
  assert.equal(Model.needsAttention({ live: true }), true)
  assert.equal(Model.needsAttention({ state: "working" }), true)
  assert.equal(Model.needsAttention({ state: "limit" }), true)
  assert.equal(Model.needsAttention({ state: "idle" }), false)
  assert.equal(Model.needsAttention({ live: false }), false)
})
