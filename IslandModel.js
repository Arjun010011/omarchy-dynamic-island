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
  "idle-expanded": { w: 368, h: 100, r: 38 }
}

// Compact activities in priority order. The first one present owns the pill;
// the second one, if any, gets the detached bubble on the right.
var activityOrder = ["recording", "media", "mic"]

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
  if (state.userExpanded) return state.hasMedia ? "media-expanded" : "idle-expanded"
  if (state.hud) return state.hud.layout === "progress" ? "hud-progress"
    : (state.hud.layout === "track" ? "hud-track"
      : (state.hud.layout === "toast" ? "hud-toast" : "hud-label"))
  if (state.primary) return state.primary
  if (state.idleHidden) return "hidden"
  return state.hovered ? "idle-hover" : "idle"
}

function sizeFor(view) {
  return sizes[view] || sizes["idle"]
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

// This plugin's own entry in shell.json's plugins[] array doubles as its
// settings block, e.g. { "id": "...", "style": "notch" }.
function entryFor(configText, pluginId) {
  try {
    var cfg = JSON.parse(String(configText || "{}"))
    var list = Array.isArray(cfg.plugins) ? cfg.plugins : []
    for (var i = 0; i < list.length; i++)
      if (list[i] && list[i].id === pluginId) return list[i]
  } catch (e) {}
  return {}
}
