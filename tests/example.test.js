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

const Model = load("ExampleModel.js")

test("greeting falls back when empty", () => {
  assert.equal(Model.greeting(""), "Hello")
  assert.equal(Model.greeting("  "), "Hello")
  assert.equal(Model.greeting("Hi"), "Hi")
})
