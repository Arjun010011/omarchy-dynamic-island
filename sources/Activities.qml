import QtQuick
import Quickshell

// Live activities pushed by scripts: a build, a download, a backup, an AI
// agent working. Anything can start, update and end one over IPC:
//
//   omarchy-shell dynamic-island activity build '{"title":"Building","progress":0.4}'
//   omarchy-shell dynamic-island endActivity build
//
// The most recently updated one is shown.
Item {
  id: activities

  property var island: null
  property var items: ({})
  property int tick: 0

  readonly property var current: {
    tick
    var best = null
    for (var id in items)
      if (!best || items[id].updated > best.updated) best = items[id]
    return best
  }
  readonly property int count: { tick; return Object.keys(items).length }

  // Fields: title, subtitle, icon (Nerd Font glyph), progress (0..1, or
  // omit for none), value (short text like "3/10"), color (accent, green,
  // orange, red, or #hex), ttl (seconds until it ends on its own).
  function update(id, payload) {
    var key = String(id || "").trim()
    if (!key) return "missing id"
    var p = payload || {}
    var prev = items[key] || {}
    var next = {}
    for (var k in items) next[k] = items[k]
    var progress = p.progress === undefined ? prev.progress : Number(p.progress)
    next[key] = {
      id: key,
      title: p.title !== undefined ? String(p.title) : (prev.title || key),
      subtitle: p.subtitle !== undefined ? String(p.subtitle) : (prev.subtitle || ""),
      icon: p.icon !== undefined ? String(p.icon) : (prev.icon || "󰄬"),
      progress: progress === undefined || progress === null || !isFinite(progress) ? -1 : Math.max(0, Math.min(1, progress)),
      value: p.value !== undefined ? String(p.value) : (prev.value || ""),
      color: p.color !== undefined ? String(p.color) : (prev.color || ""),
      expires: p.ttl !== undefined && Number(p.ttl) > 0 ? Date.now() + Number(p.ttl) * 1000 : (prev.expires || 0),
      updated: Date.now()
    }
    items = next
    tick++
    return "ok"
  }

  function end(id, message) {
    var key = String(id || "")
    if (!items[key]) return "none"
    var ended = items[key]
    var next = {}
    for (var k in items) if (k !== key) next[k] = items[k]
    items = next
    tick++
    if (message && island)
      island.toast({ title: ended.title, body: String(message), icon: ended.icon, color: ended.color || "green", duration: 4000 })
    return "ok"
  }

  function list() {
    var out = []
    for (var id in items) out.push(items[id])
    return out
  }

  // Drop activities whose ttl ran out, so a crashed script can't leave one
  // stuck in the island forever.
  Timer {
    interval: 5000
    repeat: true
    running: activities.count > 0
    onTriggered: {
      var now = Date.now()
      for (var id in activities.items) {
        var e = activities.items[id].expires
        if (e > 0 && e <= now) activities.end(id, "")
      }
    }
  }
}
