"use strict"
const test = require("node:test")
const assert = require("node:assert/strict")
const { execFileSync } = require("child_process")
const crypto = require("crypto")
const fs = require("fs")
const os = require("os")
const path = require("path")

// Runs scripts/list-sessions against synthetic transcripts in a temporary CLAUDE_CONFIG_DIR.

const lister = path.join(__dirname, "..", "scripts", "list-sessions")
const config = fs.mkdtempSync(path.join(os.tmpdir(), "phone-sessions-test-"))
const cwd = fs.mkdtempSync(path.join(os.tmpdir(), "phone-sessions-cwd-"))
const projects = path.join(config, "projects", "p")
fs.mkdirSync(projects, { recursive: true })
fs.mkdirSync(path.join(config, "sessions"))
test.after(() => {
  fs.rmSync(config, { recursive: true, force: true })
  fs.rmSync(cwd, { recursive: true, force: true })
})

const user = (id, text, entrypoint = "cli") =>
  ({ type: "user", entrypoint, cwd, sessionId: id, message: { role: "user", content: text } })
const said = (text) => ({ type: "assistant", message: { role: "assistant", content: [{ type: "text", text }] } })
const toolCall = () => ({ type: "assistant", message: { role: "assistant", content: [{ type: "tool_use", id: "t", name: "Bash", input: {} }] } })
const toolResult = (id) =>
  ({ type: "user", cwd, sessionId: id, message: { role: "user", content: [{ type: "tool_result", tool_use_id: "t", content: "ok" }] } })

function transcript(records, filler = 0) {
  const id = crypto.randomUUID()
  const rows = records.map((r) => (typeof r === "function" ? r(id) : r))
  const lines = rows.slice(0, 1).map((r) => JSON.stringify(r))
  // Padding between the first prompt and the rest makes the file long enough that --closed
  // reads only its start and end.
  for (let i = 0; i < filler; i++) lines.push(JSON.stringify({ type: "progress", data: "x".repeat(1000) }))
  lines.push(...rows.slice(1).map((r) => JSON.stringify(r)))
  fs.writeFileSync(path.join(projects, id + ".jsonl"), lines.join("\n") + "\n")
  return id
}

const ids = {
  limit: transcript([(id) => user(id, "build the thing"), said("You've hit your session limit · resets 4pm")]),
  working: transcript([(id) => user(id, "migrate the database"), toolCall(), toolResult]),
  idle: transcript([(id) => user(id, "what is two plus two"), said("Four.")]),
  long: transcript([(id) => user(id, "a long one"), said("done with step one"), toolCall()], 1200),
  running: transcript([(id) => user(id, "still open"), said("Sure.")]),
  phone: transcript([(id) => user(id, "from the phone", "sdk-cli"), said("Hi.")]),
}

// Older than a week: neither tab lists them. A day old: enough of them to hit the 20-row limit.
const age = (id, days) => {
  const t = new Date(Date.now() - days * 86400 * 1000)
  fs.utimesSync(path.join(projects, id + ".jsonl"), t, t)
  return id
}
const old = {
  cli: age(transcript([(id) => user(id, "an old one"), said("Done.")]), 8),
  phone: age(transcript([(id) => user(id, "an old phone one", "sdk-cli"), said("Done.")]), 8),
}
for (let i = 0; i < 21; i++) age(transcript([(id) => user(id, "filler " + i), said("Ok.")]), 1)

// This test process stands in for the Claude process that holds the "running" session.
const stat = fs.readFileSync("/proc/self/stat", "utf8")
const procStart = stat.slice(stat.lastIndexOf(")") + 2).split(" ")[19]
fs.writeFileSync(path.join(config, "sessions", process.pid + ".json"),
  JSON.stringify({ pid: process.pid, sessionId: ids.running, procStart }))
// A record whose pid was reused by another process must not hide its session.
fs.writeFileSync(path.join(config, "sessions", "1.json"),
  JSON.stringify({ pid: 1, sessionId: ids.idle, procStart: "0" }))

function run(...args) {
  return execFileSync(lister, args, { env: { ...process.env, CLAUDE_CONFIG_DIR: config }, encoding: "utf8" })
}

test("--closed lists terminal sessions no process holds, with how each stopped", () => {
  const out = JSON.parse(run("--closed"))
  const byId = Object.fromEntries(out.map((s) => [s.id, s]))
  assert.equal(byId[ids.limit].state, "limit")
  assert.equal(byId[ids.working].state, "working")
  assert.equal(byId[ids.idle].state, "idle")
  assert.equal(byId[ids.running], undefined, "a session a live process holds is not closed")
  assert.equal(byId[ids.phone], undefined, "phone sessions belong to the other tab")
  assert.ok(out.every((s) => s.live === false), "a closed session is never running on the phone")
})

test("both tabs list at most 20 sessions, none older than a week, newest first", () => {
  const closed = JSON.parse(run("--closed"))
  assert.equal(closed.length, 20)
  for (const id of [ids.limit, ids.working, ids.idle, ids.long]) assert.ok(closed.some((s) => s.id === id))
  assert.ok(!closed.some((s) => s.id === old.cli))
  assert.ok(closed.every((s, i) => i === 0 || closed[i - 1].mtime >= s.mtime))
  assert.ok(!JSON.parse(run()).some((s) => s.id === old.phone))
})

test("--closed reads a long transcript's first prompt and last turn", () => {
  const long = JSON.parse(run("--closed")).find((s) => s.id === ids.long)
  assert.ok(fs.statSync(path.join(projects, ids.long + ".jsonl")).size > 1024 * 1024)
  assert.equal(long.prompt, "a long one")
  assert.equal(long.state, "working")
})

test("the default listing is still phone sessions only, without a state", () => {
  const out = JSON.parse(run())
  assert.deepEqual(out.map((s) => s.id), [ids.phone])
  assert.equal(out[0].state, undefined)
})

test("--resume-info finds phone and terminal sessions", () => {
  for (const id of [ids.phone, ids.idle]) assert.equal(run("--resume-info", id).split("\n")[0], cwd)
})
