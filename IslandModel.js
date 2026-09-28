.pragma library

// Pure helpers for the island. No QML types in here so the logic can be read
// (and reasoned about) without the scene around it.

// Base geometry for each view, in unscaled pixels. The island springs between
// these; `r` is the corner radius, which for the compact views is half the
// height so the shape stays a true capsule.
var sizes = {
  "idle":          { w: 126, h: 32, r: 16 },
  "idle-hover":    { w: 138, h: 34, r: 17 },
  "hidden":        { w: 0,   h: 32, r: 16 },
  "media":         { w: 300, h: 32, r: 16 },
  "recording":     { w: 232, h: 32, r: 16 },
  "mic":           { w: 214, h: 32, r: 16 },
  "hud-progress":  { w: 310, h: 36, r: 18 },
  "hud-label":     { w: 310, h: 36, r: 18 },
  "hud-track":     { w: 368, h: 66, r: 28 },
  "hud-toast":     { w: 368, h: 66, r: 28 },
  "media-expanded": { w: 404, h: 186, r: 42 },
  "recording-expanded": { w: 392, h: 76, r: 34 },
  "recording-media-expanded": { w: 404, h: 145, r: 40 },
  "idle-expanded": { w: 392, h: 150, r: 40 },
  "notification":  { w: 404, h: 78, r: 34 },
  "inbox":         { w: 200, h: 32, r: 16 },
  "timer":         { w: 236, h: 32, r: 16 },
  "stopwatch":     { w: 236, h: 32, r: 16 },
  "activity":      { w: 256, h: 32, r: 16 },
  "calendar":      { w: 300, h: 32, r: 16 },
  "clock-expanded": { w: 380, h: 132, r: 40 },
  "activity-expanded": { w: 392, h: 104, r: 38 },
  "notification-actions": { w: 404, h: 118, r: 38 }
}

// Compact activities in priority order. The first one present owns the pill;
// the second one, if any, gets the detached bubble on the right.
var activityOrder = ["recording", "timer", "activity", "media", "stopwatch", "calendar", "mic", "inbox"]

function activities(flags) {
  var out = []
  for (var i = 0; i < activityOrder.length; i++)
    if (flags[activityOrder[i]]) out.push(activityOrder[i])
  return out
}

// Which view the island shows. Transient HUDs win over everything except an
// island the user deliberately opened, since a volume tick while reading the
// expanded player should not throw the player away.
function viewFor(state) {
  if (state.userExpanded && state.inboxOpen) return "inbox-expanded"
  if (state.userExpanded && state.outputsOpen) return "outputs-expanded"
  if (state.userExpanded) {
    // Recording takes the top of an opened island so it can be stopped from
    // there; music, if any, rides along underneath.
    if (state.recording) return state.hasMedia ? "recording-media-expanded" : "recording-expanded"
    // Otherwise open whatever was clicked: the pill's activity, or the
    // bubble's when the bubble was the thing clicked.
    var focus = state.focus || state.primary
    if (focus === "timer" || focus === "stopwatch") return "clock-expanded"
    if (focus === "activity") return "activity-expanded"
    if (focus === "media" && state.hasMedia) return "media-expanded"
    return state.hasMedia && focus !== "calendar" ? "media-expanded" : "idle-expanded"
  }
  if (state.hud && state.hud.layout === "progress") return "hud-progress"
  if (state.notification) return state.notificationActions ? "notification-actions" : "notification"
  if (state.hud) return state.hud.layout === "progress" ? "hud-progress"
    : (state.hud.layout === "track" ? "hud-track"
      : (state.hud.layout === "toast" ? "hud-toast" : "hud-label"))
  if (state.primary) return state.primary
  if (state.idleHidden) return "hidden"
  return state.hovered ? "idle-hover" : "idle"
}

// The opened inbox grows with its contents, up to four rows (then scrolls).
var inboxRowHeight = 58
var inboxRowGap = 6

function inboxSize(count) {
  if (count <= 0) return { w: 420, h: 72, r: 32 }
  var rows = Math.min(4, count)
  return { w: 420, h: 14 + rows * inboxRowHeight + (rows - 1) * inboxRowGap + 10 + 30 + 14, r: 36 }
}

// Output picker: a header plus one row per audio output.
function outputsSize(count) {
  var rows = Math.max(1, Math.min(6, count))
  return { w: 392, h: 16 + 22 + 8 + rows * 40 + (rows - 1) * 4 + 16, r: 36 }
}

// Views that sit on the notch itself; with a measured notch they grow to
// clear the camera cutout with room for content on both sides.
var compactViews = ["idle", "idle-hover", "media", "recording", "mic", "inbox", "timer",
                    "stopwatch", "activity", "calendar"]

function sizeFor(view, counts, notch) {
  var base
  if (view === "inbox-expanded") base = inboxSize(counts && counts.inbox || 0)
  else if (view === "outputs-expanded") base = outputsSize(counts && counts.outputs || 0)
  else base = sizes[view] || sizes["idle"]
  if (!notch || !(notch.w > 0) || compactViews.indexOf(view) === -1) return base
  var h = Math.max(base.h, notch.h > 0 ? notch.h : base.h)
  if (view === "idle" || view === "idle-hover") {
    var r = notch.r > 0 ? notch.r : h / 2
    return { w: notch.w + (view === "idle-hover" ? 12 : 0), h: h, r: Math.min(r, h / 2) }
  }
  // 60px of content either side of the cutout.
  return { w: Math.max(base.w, notch.w + 120), h: h, r: h / 2 }
}

// "25", "25m", "90s", "1h30m", "1:30" (m:s) or "1:30:00" (h:m:s) -> seconds.
function parseDuration(text) {
  var t = String(text || "").trim().toLowerCase()
  if (!t) return 0
  if (/^\d+$/.test(t)) return parseInt(t, 10) * 60
  if (/^\d+(:\d{1,2}){1,2}$/.test(t)) {
    var parts = t.split(":").map(function(p) { return parseInt(p, 10) })
    return parts.length === 2 ? parts[0] * 60 + parts[1] : parts[0] * 3600 + parts[1] * 60 + parts[2]
  }
  var total = 0
  var matched = false
  var re = /(\d+(?:\.\d+)?)\s*(h|hr|hours?|m|min|mins|minutes?|s|sec|secs|seconds?)/g
  var m
  while ((m = re.exec(t)) !== null) {
    matched = true
    var n = parseFloat(m[1])
    var u = m[2].charAt(0)
    total += u === "h" ? n * 3600 : (u === "m" ? n * 60 : n)
  }
  return matched ? Math.round(total) : 0
}

// 272.4s -> "4:32"; with tenths -> "4:32.4". Hours when needed.
function formatClock(seconds, tenths) {
  var s = Math.max(0, Number(seconds) || 0)
  var whole = Math.floor(s)
  var text = formatTime(whole)
  if (tenths) text += "." + Math.floor((s - whole) * 10)
  return text
}

// Bluetooth device icon names (freedesktop) -> Nerd Font glyph.
function deviceGlyph(icon) {
  var i = String(icon || "").toLowerCase()
  if (i.indexOf("headset") !== -1 || i.indexOf("headphone") !== -1) return "󰋋"
  if (i.indexOf("speaker") !== -1 || i.indexOf("audio") !== -1) return "󰓃"
  if (i.indexOf("keyboard") !== -1) return "󰌌"
  if (i.indexOf("mouse") !== -1 || i.indexOf("tablet") !== -1) return "󰍽"
  if (i.indexOf("gaming") !== -1 || i.indexOf("joystick") !== -1) return "󰊴"
  if (i.indexOf("phone") !== -1) return "󰄜"
  if (i.indexOf("watch") !== -1) return "󰖉"
  if (i.indexOf("computer") !== -1) return "󰌢"
  return "󰂱"
}

// ---------------------------------------------------------------- calendar
// A small iCalendar reader: enough for "what is my next meeting". Handles
// folded lines, UTC / floating / TZID times (TZID times are read as local
// time), all-day events, and DAILY/WEEKLY recurrence with INTERVAL, BYDAY,
// COUNT, UNTIL and EXDATE. Other recurrences show their first occurrence.

function icsDate(value) {
  var v = String(value || "").trim()
  var m = /^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z)?)?$/.exec(v)
  if (!m) return null
  var y = +m[1], mo = +m[2] - 1, d = +m[3]
  if (m[4] === undefined) return { time: new Date(y, mo, d).getTime(), allDay: true }
  var h = +m[4], mi = +m[5], se = +m[6]
  var time = m[7] ? Date.UTC(y, mo, d, h, mi, se) : new Date(y, mo, d, h, mi, se).getTime()
  return { time: time, allDay: false }
}

function icsUnescape(v) {
  return String(v || "").replace(/\\n/gi, " ").replace(/\\([,;\\])/g, "$1").trim()
}

var weekdayCodes = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"]

function expandEvent(ev, from, to) {
  var out = []
  if (!ev.rrule) {
    if (ev.end > from && ev.start < to) out.push(ev)
    return out
  }
  var rule = {}
  ev.rrule.split(";").forEach(function(part) {
    var kv = part.split("=")
    if (kv.length === 2) rule[kv[0].toUpperCase()] = kv[1]
  })
  var freq = rule.FREQ
  if (freq !== "DAILY" && freq !== "WEEKLY") {
    if (ev.end > from && ev.start < to) out.push(ev)
    return out
  }
  var interval = Math.max(1, parseInt(rule.INTERVAL || "1", 10))
  var until = rule.UNTIL ? (icsDate(rule.UNTIL) || {}).time : Infinity
  var count = rule.COUNT ? parseInt(rule.COUNT, 10) : Infinity
  var duration = ev.end - ev.start
  var first = new Date(ev.start)
  var days = freq === "WEEKLY" && rule.BYDAY
    ? rule.BYDAY.split(",").map(function(d) { return weekdayCodes.indexOf(d.replace(/^[+-]?\d+/, "")) })
        .filter(function(d) { return d >= 0 })
    : [first.getDay()]
  var n = 0
  // Walk day by day (bounded): cheap for a week-ahead window.
  for (var i = 0; i < 3700 && n < count; i++) {
    var day = new Date(first.getFullYear(), first.getMonth(), first.getDate() + i,
                       first.getHours(), first.getMinutes(), first.getSeconds())
    var t = day.getTime()
    if (t > until || t > to) break
    var weeks = Math.floor(i / 7)
    var ok = freq === "DAILY" ? i % interval === 0
      : (weeks % interval === 0 && days.indexOf(day.getDay()) !== -1)
    if (!ok) continue
    n += 1
    if (ev.exdates.indexOf(t) !== -1) continue
    if (t + duration > from) out.push({ title: ev.title, start: t, end: t + duration, allDay: ev.allDay })
  }
  return out
}

// All timed (not all-day) events overlapping [from, to), soonest first.
function parseIcs(text, from, to) {
  var lines = String(text || "").replace(/\r\n[ \t]/g, "").replace(/\n[ \t]/g, "").split(/\r?\n/)
  var events = []
  var ev = null
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    if (line === "BEGIN:VEVENT") { ev = { title: "", start: 0, end: 0, allDay: false, rrule: "", exdates: [], cancelled: false }; continue }
    if (line === "END:VEVENT") {
      if (ev && ev.start && !ev.cancelled) {
        if (!ev.end) ev.end = ev.start + (ev.allDay ? 86400000 : 3600000)
        events = events.concat(expandEvent(ev, from, to))
      }
      ev = null
      continue
    }
    if (!ev) continue
    var colon = line.indexOf(":")
    if (colon < 0) continue
    var name = line.substring(0, colon).split(";")[0].toUpperCase()
    var value = line.substring(colon + 1)
    if (name === "SUMMARY") ev.title = icsUnescape(value)
    else if (name === "DTSTART") { var ds = icsDate(value); if (ds) { ev.start = ds.time; ev.allDay = ds.allDay } }
    else if (name === "DTEND") { var de = icsDate(value); if (de) ev.end = de.time }
    else if (name === "RRULE") ev.rrule = value
    else if (name === "EXDATE") value.split(",").forEach(function(v) { var x = icsDate(v); if (x) ev.exdates.push(x.time) })
    else if (name === "STATUS" && value.toUpperCase() === "CANCELLED") ev.cancelled = true
  }
  return events.filter(function(e) { return !e.allDay })
    .sort(function(a, b) { return a.start - b.start })
}

// "in 12m", "in 1h 5m", "now"
function untilText(start, now) {
  var s = Math.round((start - now) / 1000)
  if (s <= 30) return "now"
  var m = Math.ceil(s / 60)
  if (m < 60) return "in " + m + "m"
  return "in " + Math.floor(m / 60) + "h" + (m % 60 ? " " + (m % 60) + "m" : "")
}

// "now", "5m", "2h", "3d" — how long ago a notification arrived.
function ago(time, now) {
  var s = Math.max(0, Math.floor((Number(now) - Number(time)) / 1000))
  if (s < 60) return "now"
  if (s < 3600) return Math.floor(s / 60) + "m"
  if (s < 86400) return Math.floor(s / 3600) + "h"
  return Math.floor(s / 86400) + "d"
}

function pad2(n) {
  return n < 10 ? "0" + n : String(n)
}

function formatTime(seconds) {
  var s = Math.max(0, Math.floor(Number(seconds) || 0))
  var h = Math.floor(s / 3600)
  var m = Math.floor((s % 3600) / 60)
  var sec = s % 60
  return h > 0 ? h + ":" + pad2(m) + ":" + pad2(sec) : m + ":" + pad2(sec)
}

function clamp01(v) {
  var n = Number(v)
  if (!isFinite(n)) return 0
  return Math.max(0, Math.min(1, n))
}

function volumeIcon(volume, muted) {
  if (muted || volume <= 0.001) return "󰝟"
  if (volume < 0.34) return "󰕿"
  if (volume < 0.67) return "󰖀"
  return "󰕾"
}

function brightnessIcon(level) {
  if (level < 0.34) return "󰃞"
  if (level < 0.67) return "󰃟"
  return "󰃠"
}

var batteryDischarging = ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
var batteryCharging = ["󰢟", "󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"]

function batteryIcon(fraction, charging) {
  var i = Math.max(0, Math.min(10, Math.round(clamp01(fraction) * 10)))
  return charging ? batteryCharging[i] : batteryDischarging[i]
}

function percentText(fraction) {
  return Math.round(clamp01(fraction) * 100) + "%"
}

// MPRIS proxies (playerctld) mirror another player; showing them would put
// every track in the island twice.
function isProxyPlayer(player) {
  var dbusName = String(player && player.dbusName || "").toLowerCase()
  var entry = String(player && player.desktopEntry || "").toLowerCase()
  return dbusName.indexOf("playerctld") !== -1 || entry === "playerctld"
}

function playerKey(player) {
  return player ? String(player.dbusName || player.identity || "") : ""
}

function hasTrack(player) {
  return !!(player && (player.trackTitle || player.trackArtist))
}

// How complete a player's track info is. When two players both claim to be
// playing (a music app plus a browser tab mirroring it), the one with cover
// art and a separate artist is the one worth showing.
function richness(player) {
  return (hasRealArt(player) ? 2 : 0) + (player.trackArtist ? 1 : 0)
}

// Chromium-based browsers hand MPRIS a temp file for artwork, and when the
// page gives none it is just the browser's own logo. It never outranks a
// player with a real cover.
function hasRealArt(player) {
  var url = String(player && player.trackArtUrl || "")
  if (!url) return false
  return url.indexOf("/.org.chromium.") === -1 && url.indexOf("/.com.google.Chrome.") === -1
    && url.indexOf("/.com.brave.") === -1 && url.indexOf("/.com.microsoft.Edge.") === -1
}

function normalizedTitle(player) {
  return String(player && player.trackTitle || "").toLowerCase().replace(/\s+/g, " ").trim()
}

// Two players showing one song: typically the Spotify app plus Chromium's
// mirror of it ("Boyfriend" vs "Boyfriend • Karan Aujla, Ikky", same length).
function sameTrack(a, b) {
  var ta = normalizedTitle(a)
  var tb = normalizedTitle(b)
  if (!ta || !tb) return false
  if (!(ta === tb || ta.indexOf(tb) === 0 || tb.indexOf(ta) === 0)) return false
  if (a.lengthSupported && b.lengthSupported && a.length > 0 && b.length > 0)
    return Math.abs(a.length - b.length) < 2
  return true
}

// Players worth considering: no proxies, something loaded, and of any pair
// playing the same song only the one with the better metadata.
function candidates(players) {
  var list = []
  for (var i = 0; i < players.length; i++) {
    var p = players[i]
    if (!p || isProxyPlayer(p) || !hasTrack(p)) continue
    var duplicateOf = -1
    for (var j = 0; j < list.length; j++)
      if (sameTrack(p, list[j])) { duplicateOf = j; break }
    if (duplicateOf === -1) list.push(p)
    else if (richness(p) > richness(list[duplicateOf])) list[duplicateOf] = p
  }
  return list
}

// The island sticks with the player it is already showing (`currentKey`), so
// pausing keeps that player on screen even while a browser tab keeps claiming
// "Playing". It moves on only when another player starts playing (handled by
// the caller) or the current one goes away. Without a current player: the
// richest playing one, then the richest one at all.
function pickPlayer(players, currentKey) {
  var list = candidates(players)
  var current = null
  var playing = null
  var fallback = null
  for (var i = 0; i < list.length; i++) {
    var p = list[i]
    if (currentKey && playerKey(p) === currentKey) current = p
    if (p.isPlaying && (!playing || richness(p) > richness(playing))) playing = p
    if (!fallback || richness(p) > richness(fallback)) fallback = p
  }
  return current || playing || fallback
}

// Capture streams (something is recording from a microphone). Peak meters and
// monitor taps are capture streams too, but they are not a privacy signal.
function isMicStream(node) {
  if (!node || !node.isStream || node.isSink !== false) return false
  var name = String(node.name || "").toLowerCase()
  return name.indexOf("peak") === -1 && name.indexOf("monitor") === -1 && name.indexOf("cava") === -1
}

// Pull `colorN = "#rrggbb"` pairs out of a theme's colors.toml.
function parseColors(text) {
  var out = {}
  var re = /^\s*([A-Za-z0-9_]+)\s*=\s*"(#[0-9A-Fa-f]{6,8})"/gm
  var m
  while ((m = re.exec(String(text || ""))) !== null) out[m[1]] = m[2]
  return out
}

function parseConfig(configText) {
  try {
    var cfg = JSON.parse(String(configText || "{}"))
    return cfg && typeof cfg === "object" ? cfg : {}
  } catch (e) {
    return {}
  }
}

// This plugin's own entry in shell.json's plugins[] array doubles as its
// settings block, e.g. { "id": "...", "style": "notch" }.
function entryFor(cfg, pluginId) {
  var list = cfg && Array.isArray(cfg.plugins) ? cfg.plugins : []
  for (var i = 0; i < list.length; i++)
    if (list[i] && list[i].id === pluginId) return list[i]
  return {}
}

// Senders that are feedback noise rather than messages (Omarchy's rule).
function isEphemeralApp(appName) {
  var name = String(appName || "")
  return name === "notify-send" || name === "omarchy-action"
}

function stringHint(hints, name) {
  try {
    if (hints) {
      var value = hints[name]
      if (value !== undefined && value !== null) return String(value)
    }
  } catch (e) {}
  return ""
}

// omarchy-notification-send --exec passes the click command as a JSON argv.
function parseExecArgv(value) {
  var text = String(value || "")
  if (!text) return null
  var parsed
  try { parsed = JSON.parse(text) } catch (e) { return null }
  if (!Array.isArray(parsed) || parsed.length === 0) return null
  for (var i = 0; i < parsed.length; i++)
    if (typeof parsed[i] !== "string") return null
  return parsed
}

// Notification bodies may carry a little markup; the island shows text.
function plainText(value) {
  return String(value || "")
    .replace(/<br\s*\/?>/gi, " ")
    .replace(/<[^>]*>/g, "")
    .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"")
    .replace(/&#39;|&apos;/g, "'").replace(/&amp;/g, "&")
    .replace(/\s+/g, " ")
    .trim()
}
