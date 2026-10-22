.pragma library

// Pure logic for the picker: parsing the lister's JSON, filtering, and labels. No QML or I/O.

// One page from list-sessions: { sessions, more, before, stoppedBy, days }. A bare array (older lister) is
// a single page with nothing after it.
function parsePage(raw) {
  var page = { sessions: [], more: false, before: "", stoppedBy: "end", days: 7 }
  var data
  try {
    data = JSON.parse(raw)
  } catch (e) {
    return page
  }
  var list = Array.isArray(data) ? data : (data && Array.isArray(data.sessions) ? data.sessions : [])
  page.sessions = list.filter(function(s) { return s && s.id && s.cwd })
  if (data && !Array.isArray(data)) {
    page.more = data.more === true
    page.before = typeof data.before === "string" ? data.before : ""
    if (data.stoppedBy === "days" || data.stoppedBy === "count") page.stoppedBy = data.stoppedBy
    if (Number(data.days) > 0) page.days = Number(data.days)
  }
  return page
}

function parse(raw) {
  return parsePage(raw).sessions
}

// Add a later page, skipping sessions already listed (one can move between pages while it runs).
function merge(sessions, incoming) {
  var seen = {}
  sessions.forEach(function(s) { seen[s.id] = true })
  return sessions.concat(incoming.filter(function(s) { return !seen[s.id] }))
}

// Caption for the "Load older sessions" row, which says what the list holds so far.
function loadCaption(count, stoppedBy, days, filtering) {
  if (filtering) return "The filter only searches loaded sessions"
  if (count === 0) return "Nothing in the last " + days + " days"
  if (stoppedBy === "days") return "Showing the last " + days + " days"
  return "Showing the " + count + " newest"
}

function label(s) {
  return s.title || s.prompt || "(no prompt)"
}

// Every whitespace-separated word must appear in the folder, title or first prompt.
function filter(sessions, query) {
  var words = String(query || "").toLowerCase().split(/\s+/).filter(function(w) { return w !== "" })
  if (words.length === 0) return sessions.slice()
  return sessions.filter(function(s) {
    var hay = [s.folder, s.title, s.prompt].join(" ").toLowerCase()
    return words.every(function(w) { return hay.indexOf(w) !== -1 })
  })
}

// How a closed terminal session stopped (list-sessions --closed). Phone sessions have no state.
var STATES = { limit: "stopped by a usage limit", working: "closed mid-task", idle: "closed" }

function stateLabel(s) {
  return (s && STATES[s.state]) || ""
}

// Worth a look: the phone is running it, or it stopped before it finished.
function needsAttention(s) {
  return !!(s && (s.live || s.state === "limit" || s.state === "working"))
}

function ago(mtimeSec, nowSec) {
  var d = Math.max(0, Math.floor(nowSec - mtimeSec))
  if (d < 60) return "just now"
  if (d < 3600) return Math.floor(d / 60) + "m ago"
  if (d < 86400) return Math.floor(d / 3600) + "h ago"
  return Math.floor(d / 86400) + "d ago"
}

if (typeof module !== "undefined") module.exports = { parsePage, parse, merge, loadCaption, label, filter, stateLabel, needsAttention, ago }
