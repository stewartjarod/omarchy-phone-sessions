.pragma library

// Pure logic for the picker: parsing the lister's JSON, filtering, and labels. No QML or I/O.

function parse(raw) {
  try {
    var list = JSON.parse(raw)
    return Array.isArray(list) ? list.filter(function(s) { return s && s.id && s.cwd }) : []
  } catch (e) {
    return []
  }
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

function ago(mtimeSec, nowSec) {
  var d = Math.max(0, Math.floor(nowSec - mtimeSec))
  if (d < 60) return "just now"
  if (d < 3600) return Math.floor(d / 60) + "m ago"
  if (d < 86400) return Math.floor(d / 3600) + "h ago"
  return Math.floor(d / 86400) + "d ago"
}

if (typeof module !== "undefined") module.exports = { parse, label, filter, ago }
