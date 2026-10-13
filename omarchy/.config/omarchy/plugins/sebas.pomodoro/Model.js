.pragma library

function pad(n) { return n < 10 ? "0" + n : "" + n }

function clock(sec) {
  sec = Math.max(0, Math.floor(sec))
  return pad(Math.floor(sec / 60)) + ":" + pad(sec % 60)
}

function duration(sec) {
  var m = Math.round(sec / 60)
  if (m < 60) return m + "m"
  var h = Math.floor(m / 60)
  return h + "h" + (m % 60 ? " " + pad(m % 60) + "m" : "")
}

function esc(s) { return String(s === undefined || s === null ? "" : s).replace(/'/g, "''") }

function startOfToday() {
  var d = new Date()
  d.setHours(0, 0, 0, 0)
  return Math.floor(d.getTime() / 1000)
}

function parseRows(text) {
  var t = String(text || "").trim()
  if (!t) return []
  try { return JSON.parse(t) } catch (e) { return [] }
}
