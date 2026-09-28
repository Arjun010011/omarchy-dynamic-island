import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs.Commons
import "views"
import "sources"
import "IslandModel.js" as Model

// Dynamic Island for Omarchy.
//
// A keep-loaded panel plugin: the shell mounts it at startup and it draws its
// own layer-shell strip across the top of one monitor. Only the island (and
// the split bubble) take input; everything else in the strip is click-through.
//
// Data flows one way: live sources (MPRIS, PipeWire, UPower, backlight,
// gpu-screen-recorder) feed plain properties on this root, those resolve to a
// single `view` name, and the shape springs to that view's size while the
// matching content fades in.
Item {
  id: root

  property var shell: null
  property var manifest: null
  readonly property string pluginId: manifest && manifest.id ? manifest.id : "arjun010011.dynamic-island"

  // ------------------------------------------------------------------
  // Settings: this plugin's entry in ~/.config/omarchy/shell.json plugins[]
  // ------------------------------------------------------------------
  property var settings: ({})

  function setting(key, fallback) {
    var v = settings ? settings[key] : undefined
    return v === undefined || v === null ? fallback : v
  }

  readonly property bool notch: setting("style", "island") === "notch"
  readonly property bool blackBackground: setting("background", "theme") === "black"
  readonly property bool idleHidden: setting("idle", "pill") === "hidden"
  readonly property real scaleFactor: Math.max(0.6, Math.min(2, Number(setting("scale", 1)) || 1))
  readonly property int topMargin: notch ? 0 : s(Number(setting("topMargin", 6)))
  readonly property bool reserveSpace: setting("reserveSpace", true) !== false
  readonly property string monitorSetting: String(setting("monitor", "primary"))
  readonly property bool expandOnHover: setting("expandOnHover", false) === true
  readonly property string clockFormat: String(setting("clockFormat", "h:mm AP"))
  readonly property bool showVolume: setting("volume", true) !== false
  readonly property bool showBrightness: setting("brightness", true) !== false
  readonly property bool showCharging: setting("charging", true) !== false
  readonly property bool showTrackChange: setting("trackChange", true) !== false
  readonly property bool showRecording: setting("recording", true) !== false
  readonly property bool showMic: setting("mic", true) !== false
  // Match a real display cutout (MacBook notch): its size in pixels.
  readonly property var notchSize: ({
    w: Math.max(0, Number(setting("notchWidth", 0)) || 0),
    h: Math.max(0, Number(setting("notchHeight", 0)) || 0),
    r: Math.max(0, Number(setting("notchRadius", 0)) || 0)
  })
  readonly property bool artworkTint: setting("visualizerColor", "accent") === "artwork"
  readonly property bool glowEnabled: setting("glow", true) !== false
  readonly property int mediaLingerMs: Math.max(0, Number(setting("mediaLingerSeconds", 30))) * 1000

  property var disabledPlugins: []
  property bool configLoaded: false

  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      var cfg = Model.parseConfig(text())
      root.settings = Model.entryFor(cfg, root.pluginId)
      root.disabledPlugins = Array.isArray(cfg.disabledPlugins) ? cfg.disabledPlugins : []
      root.configLoaded = true
    }
    onLoadFailed: {
      root.settings = ({})
      root.configLoaded = true
    }
  }

  // ------------------------------------------------------------------
  // Theme: Omarchy's shell tokens, plus the theme's green/yellow for the
  // charging and privacy tones the shell palette does not name.
  // ------------------------------------------------------------------
  property var themeColors: ({})

  FileView {
    id: themeColorsFile
    path: Color.currentThemePath + "/colors.toml"
    onLoaded: root.themeColors = Model.parseColors(text())
  }

  Connections {
    target: Color
    function onBackgroundChanged() { themeColorsFile.reload() }
    function onAccentChanged() { themeColorsFile.reload() }
  }

  readonly property color surface: blackBackground ? "#000000" : Color.background
  readonly property color fg: blackBackground ? "#f5f5f7" : Color.foreground
  readonly property color fgDim: Util.alpha(fg, 0.6)
  readonly property color accentColor: Color.accent
  readonly property color urgentColor: Color.urgent
  readonly property color greenColor: themeColors.color2 || Color.accent
  readonly property color orangeColor: themeColors.color3 || Color.urgent
  readonly property color outline: blackBackground ? "transparent" : Util.alpha(Color.foreground, 0.1)
  readonly property string fontFamily: Style.font.family

  function s(px) { return Math.round(Style.space(px) * scaleFactor) }
  function f(px) { return Math.max(6, Math.round(px * Style.fontScale * scaleFactor)) }

  // Nothing announces itself for the first moments after (re)load, so the
  // initial volume/brightness/battery reads do not pop HUDs.
  property bool ready: false
  Timer { interval: 2500; running: true; onTriggered: root.ready = true }

  // ------------------------------------------------------------------
  // Media (MPRIS)
  // ------------------------------------------------------------------
  readonly property var players: Mpris.players ? Mpris.players.values : []
  property string currentPlayerKey: ""
  property int playerTick: 0
  readonly property var player: { playerTick; return Model.pickPlayer(players, currentPlayerKey) }

  // Remember what is on screen so the choice survives a pause. Deferred so
  // the write does not land inside the evaluation of `player` itself.
  onPlayerChanged: Qt.callLater(function() {
    if (root.player) root.currentPlayerKey = Model.playerKey(root.player)
  })

  Instantiator {
    model: root.players
    delegate: Connections {
      required property var modelData
      target: modelData
      function onIsPlayingChanged() {
        // A player that starts playing takes over the island, unless it is
        // only a poorer copy of a song another player already shows.
        if (modelData.isPlaying && Model.candidates(root.players).indexOf(modelData) !== -1)
          root.currentPlayerKey = Model.playerKey(modelData)
        root.playerTick++
      }
      function onTrackTitleChanged() { root.playerTick++ }
      function onTrackArtistChanged() { root.playerTick++ }
    }
  }

  // Demo data (IPC `demo`) stands in for live sources so every state can be
  // previewed without a player running.
  property var demo: null
  readonly property var demoMedia: demo && demo.media ? demo.media : null
  readonly property bool demoOwnsMedia: !!demo && demo.media !== undefined

  readonly property bool hasMedia: demoOwnsMedia ? demoMedia !== null : player !== null
  readonly property bool mediaPlaying: demoMedia ? demoMedia.playing === true : (player ? player.isPlaying : false)
  readonly property string mediaTitle: demoMedia ? demoMedia.title : (player ? (player.trackTitle || "") : "")
  readonly property string mediaArtist: demoMedia ? demoMedia.artist : (player ? (player.trackArtist || "") : "")
  readonly property string mediaArt: demoMedia ? (demoMedia.art || "") : (player ? (player.trackArtUrl || "") : "")
  readonly property real mediaLength: demoMedia ? demoMedia.length
    : (player && player.lengthSupported ? player.length : 0)
  readonly property bool mediaCanSeek: !demoMedia && !!player && player.canSeek && player.positionSupported
  readonly property bool mediaCanNext: demoMedia ? true : (!!player && player.canGoNext)
  readonly property bool mediaCanPrevious: demoMedia ? true : (!!player && player.canGoPrevious)
  property real mediaPosition: 0

  // Keep the activity up for a while after pausing, like iOS does, so a
  // quick pause does not make the island collapse and re-open.
  property bool mediaLinger: false
  onMediaPlayingChanged: {
    if (!mediaPlaying && hasMedia && mediaLingerMs > 0) {
      mediaLinger = true
      lingerTimer.restart()
    }
  }
  Timer { id: lingerTimer; interval: root.mediaLingerMs; onTriggered: root.mediaLinger = false }

  // MPRIS position is not pushed; poll it while something shows it.
  Timer {
    interval: 500
    repeat: true
    running: root.hasMedia && root.view === "media-expanded"
    triggeredOnStart: true
    onTriggered: {
      if (root.demoMedia) {
        if (root.demoMedia.playing) root.mediaPosition = (root.mediaPosition + 0.5) % Math.max(1, root.mediaLength)
      } else if (root.player && root.player.positionSupported) {
        root.player.positionChanged()
        root.mediaPosition = root.player.position
      }
    }
  }

  function updateDemo(mutator) {
    var next = JSON.parse(JSON.stringify(root.demo || {}))
    mutator(next)
    root.demo = next
  }

  function mediaToggle() {
    if (demoMedia) updateDemo(function(d) { d.media.playing = !d.media.playing })
    else if (player && player.canTogglePlaying) player.togglePlaying()
  }

  function mediaNext() {
    if (demoMedia) root.mediaPosition = 0
    else if (player && player.canGoNext) player.next()
  }

  function mediaPrevious() {
    if (demoMedia) root.mediaPosition = 0
    else if (player && player.canGoPrevious) player.previous()
  }

  function mediaSeek(fraction) {
    if (!mediaCanSeek || mediaLength <= 0) return
    var target = Math.max(0, Math.min(1, fraction)) * mediaLength
    player.position = target
    mediaPosition = target
  }

  // Track change → brief now-playing card. Debounced because players send
  // title and artist as separate updates.
  readonly property string trackSignature: mediaTitle + "\u0001" + mediaArtist
  property string shownTrack: ""
  onTrackSignatureChanged: trackDebounce.restart()

  Timer {
    id: trackDebounce
    interval: 450
    onTriggered: {
      var sig = root.trackSignature
      if (sig === root.shownTrack) return
      root.shownTrack = sig
      if (root.ready && root.showTrackChange && root.mediaPlaying && root.mediaTitle !== "" && !root.userExpanded)
        root.showHud({ layout: "track", duration: 3200 })
    }
  }

  // ------------------------------------------------------------------
  // Audio (PipeWire): output volume HUD and microphone privacy activity
  // ------------------------------------------------------------------
  readonly property var sink: Pipewire.defaultAudioSink
  PwObjectTracker { objects: root.sink ? [root.sink] : [] }

  readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
  readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
  onVolumeChanged: volumeHud()
  onMutedChanged: volumeHud()

  function volumeHud() {
    if (!ready || !showVolume || !sink) return
    showHud({
      key: "volume",
      layout: "progress",
      icon: Model.volumeIcon(volume, muted),
      value: muted ? 0 : volume,
      valueText: muted ? "Mute" : Math.round(volume * 100) + "%",
      color: muted ? fgDim : fg,
      duration: 1500
    })
  }

  function adjustVolume(delta) {
    if (!sink || !sink.audio || delta === 0) return
    sink.audio.muted = false
    sink.audio.volume = Math.max(0, Math.min(1, sink.audio.volume + (delta > 0 ? 0.05 : -0.05)))
  }

  readonly property var pwNodes: Pipewire.nodes ? Pipewire.nodes.values : []
  readonly property bool micActive: {
    for (var i = 0; i < pwNodes.length; i++)
      if (Model.isMicStream(pwNodes[i])) return true
    return false
  }

  // ------------------------------------------------------------------
  // Power (UPower): charging and low-battery HUDs
  // ------------------------------------------------------------------
  readonly property var battery: UPower.displayDevice
  readonly property bool hasBattery: !!(battery && battery.isPresent)
  readonly property real batteryLevel: hasBattery ? Model.clamp01(battery.percentage) : 0
  readonly property bool charging: hasBattery && battery.state !== UPowerDeviceState.Discharging
    && battery.state !== UPowerDeviceState.Empty && battery.state !== UPowerDeviceState.Unknown

  onChargingChanged: {
    if (!ready || !showCharging || !charging) return
    showHud({
      key: "power",
      layout: "label",
      label: "Charging",
      icon: Model.batteryIcon(batteryLevel, true),
      valueText: Model.percentText(batteryLevel),
      color: greenColor,
      duration: 2600
    })
  }

  property real lastBatteryLevel: -1
  onBatteryLevelChanged: {
    var previous = lastBatteryLevel
    lastBatteryLevel = batteryLevel
    if (!ready || !showCharging || charging || previous < 0) return
    var crossed = (previous > 0.2 && batteryLevel <= 0.2) || (previous > 0.1 && batteryLevel <= 0.1)
    if (!crossed) return
    showHud({
      key: "power",
      layout: "label",
      label: "Low Battery",
      icon: Model.batteryIcon(batteryLevel, false),
      valueText: Model.percentText(batteryLevel),
      color: urgentColor,
      duration: 3500
    })
  }

  // ------------------------------------------------------------------
  // Backlight: sysfs does not notify, so poll the one small file.
  // ------------------------------------------------------------------
  property string backlightDir: ""
  property int brightnessMax: 0
  property real brightness: -1

  Process {
    id: backlightProbe
    running: true
    command: ["sh", "-c", "for d in /sys/class/backlight/*; do [ -r \"$d/brightness\" ] && echo \"$d\" && cat \"$d/max_brightness\" && break; done"]
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = String(text || "").trim().split("\n")
        if (lines.length < 2) return
        root.brightnessMax = parseInt(lines[1], 10) || 0
        root.backlightDir = lines[0]
      }
    }
  }

  FileView {
    id: brightnessFile
    path: root.backlightDir ? root.backlightDir + "/brightness" : ""
    blockLoading: true
  }

  Timer {
    interval: 350
    repeat: true
    running: root.backlightDir !== "" && root.brightnessMax > 0 && root.showBrightness
    onTriggered: {
      brightnessFile.reload()
      var raw = parseInt(brightnessFile.text(), 10)
      if (isNaN(raw)) return
      var level = Model.clamp01(raw / root.brightnessMax)
      var previous = root.brightness
      root.brightness = level
      if (previous < 0 || Math.abs(level - previous) < 0.001 || !root.ready) return
      root.showHud({
        key: "brightness",
        layout: "progress",
        icon: Model.brightnessIcon(level),
        value: level,
        valueText: Math.round(level * 100) + "%",
        color: root.fg,
        duration: 1500
      })
    }
  }

  // ------------------------------------------------------------------
  // Screen recording (gpu-screen-recorder, which Omarchy's capture uses)
  // ------------------------------------------------------------------
  property bool recording: false
  property int recordingElapsed: 0

  Process {
    id: recordingProbe
    command: ["sh", "-c", "p=$(pgrep -of '^gpu-screen-recorder') && ps -o etimes= -p \"$p\""]
    stdout: StdioCollector {
      onStreamFinished: {
        if (root.demo && root.demo.recording !== undefined) return
        var elapsed = parseInt(String(text || "").trim(), 10)
        root.recording = !isNaN(elapsed)
        if (!isNaN(elapsed)) root.recordingElapsed = elapsed
      }
    }
  }

  Timer {
    interval: 2000
    repeat: true
    running: root.showRecording
    triggeredOnStart: true
    onTriggered: if (!recordingProbe.running) recordingProbe.running = true
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.recordingActivity
    onTriggered: root.recordingElapsed++
  }

  // Same command the bar's recording indicator runs.
  function stopRecording() {
    if (demo && demo.recording !== undefined) {
      updateDemo(function(d) { d.recording = false })
      collapse()
      return
    }
    Quickshell.execDetached(["omarchy-capture-screenrecording", "--stop-recording"])
    collapse()
    recordingRecheck.restart()
  }

  Timer {
    id: recordingRecheck
    interval: 900
    onTriggered: if (!recordingProbe.running) recordingProbe.running = true
  }

  // ------------------------------------------------------------------
  // Notifications: the island replaces Omarchy's notification service.
  //
  // Only one notification server can own the bus, so on first run the
  // island disables `omarchy.notifications` (leaving a marker so it knows it
  // did), and serves notifications itself once that service has let go.
  // Setting "notifications": false, or disabling/removing this plugin,
  // gives the job back to Omarchy.
  // ------------------------------------------------------------------
  readonly property bool wantsNotifications: setting("notifications", true) !== false
  readonly property bool omarchyNotificationsOff: disabledPlugins.indexOf("omarchy.notifications") !== -1
  readonly property string takeoverMarker: Quickshell.env("HOME") + "/.local/state/omarchy/dynamic-island/notifications-takeover"
  property bool notificationsReady: false
  property bool ownershipRequested: false

  onWantsNotificationsChanged: syncNotificationOwnership()
  onOmarchyNotificationsOffChanged: syncNotificationOwnership()
  onConfigLoadedChanged: syncNotificationOwnership()

  function syncNotificationOwnership() {
    if (!configLoaded) return
    if (wantsNotifications && omarchyNotificationsOff) {
      notificationsReadyTimer.restart()
      return
    }
    notificationsReady = false
    if (ownershipRequested) return
    if (wantsNotifications) {
      ownershipRequested = true
      Quickshell.execDetached(["sh", "-c",
        "mkdir -p \"$(dirname \"$1\")\" && touch \"$1\" && \"$OMARCHY_PATH/bin/omarchy-plugin-disable\" omarchy.notifications",
        "sh", takeoverMarker])
    } else if (omarchyNotificationsOff) {
      // Only hand back a service this plugin took.
      ownershipRequested = true
      Quickshell.execDetached(["sh", "-c",
        "[ -f \"$1\" ] && \"$OMARCHY_PATH/bin/omarchy-plugin-enable\" omarchy.notifications && rm -f \"$1\"",
        "sh", takeoverMarker])
    }
  }

  // Give Omarchy's server a moment to release the bus name after a reload.
  Timer {
    id: notificationsReadyTimer
    interval: 1500
    onTriggered: root.notificationsReady = root.wantsNotifications && root.omarchyNotificationsOff
  }

  // The shell destroys this object on reloads and restarts too, so only act
  // if, a few seconds later, the plugin is really gone from shell.json.
  Component.onDestruction: Quickshell.execDetached(["sh", "-c",
    "sleep 4; [ -f \"$1\" ] || exit 0; " +
    "jq -e --arg id \"$2\" '.plugins[]? | select(.id == $id)' \"$HOME/.config/omarchy/shell.json\" >/dev/null 2>&1 && exit 0; " +
    "\"$OMARCHY_PATH/bin/omarchy-plugin-enable\" omarchy.notifications && rm -f \"$1\"",
    "sh", takeoverMarker, pluginId])

  Notifications {
    id: notifications
    island: root
    active: root.notificationsReady
  }

  readonly property var notification: notifications.current
  readonly property int notificationsPending: notifications.pending
  readonly property var inbox: notifications.inbox
  readonly property bool showInbox: setting("inbox", true) !== false

  function notificationOpen(key) {
    notifications.open(key)
    if (inboxOpen && inbox.length === 0) collapse()
  }

  function notificationDismiss(key) {
    notifications.dismiss(key)
    if (inboxOpen && inbox.length === 0) collapse()
  }

  function notificationAction(key, id) { notifications.invokeAction(key, id) }

  function notificationClearAll() {
    notifications.clearAll()
    collapse()
  }

  // Opens the list of waiting notifications (bell click, or Omarchy's
  // notification-history keybind).
  function openInbox() {
    hud = null
    inboxOpen = true
    userExpanded = true
    if (!hovered) {
      collapseTimer.interval = 8000
      collapseTimer.restart()
    }
  }

  // An icon URL that will actually load, or "" for the glyph fallback.
  // Quickshell hands appIcon over as image://icon/<name> even when the theme
  // has no such icon (which renders as a magenta checkerboard), so theme
  // names are checked before use.
  function themedIcon(name) {
    var n = String(name || "")
    if (!n) return ""
    if (n.charAt(0) === "/") return "file://" + n
    return Quickshell.iconPath(n, true) || ""
  }

  function notificationIcon(entry) {
    if (!entry || entry.glyph) return ""
    var image = String(entry.image || "")
    if (image) {
      if (image.charAt(0) === "/") return "file://" + image
      if (image.indexOf("image://icon/") === 0) return themedIcon(image.substring(13))
      return image
    }
    var icon = String(entry.appIcon || "")
    if (icon.indexOf("image://icon/") === 0) icon = icon.substring(13)
    if (icon.indexOf("file://") === 0 || (icon.indexOf("://") !== -1 && icon.indexOf("image://icon/") !== 0)) return icon
    var themed = themedIcon(icon)
    if (themed) return themed
    var desktop = entry.desktopEntry ? DesktopEntries.byId(entry.desktopEntry) : null
    if (!desktop && entry.app) desktop = DesktopEntries.heuristicLookup(entry.app)
    return desktop && desktop.icon ? themedIcon(desktop.icon) : ""
  }

  // ------------------------------------------------------------------
  // Timer, stopwatch, Bluetooth devices, calendar, script activities
  // ------------------------------------------------------------------
  Clocks { id: clockSource; island: root }
  Devices { island: root }
  Calendar { id: calendarSource; island: root }
  Activities { id: activitySource; island: root }

  readonly property var clocks: clockSource
  readonly property var calendar: calendarSource
  readonly property var activity: activitySource.current

  function endActivity(id) { activitySource.end(id, "") }

  // ------------------------------------------------------------------
  // Camera in use: any process holding a /dev/video* device open.
  // ------------------------------------------------------------------
  property bool cameraActive: false

  Process {
    id: cameraProbe
    command: ["sh", "-c", "find /proc/[0-9]*/fd -maxdepth 1 -lname '/dev/video*' -print -quit 2>/dev/null"]
    stdout: StdioCollector {
      onStreamFinished: {
        if (root.demo && root.demo.camera !== undefined) return
        root.cameraActive = String(text || "").trim() !== ""
      }
    }
  }

  Timer {
    interval: 3000
    repeat: true
    running: root.setting("camera", true) !== false
    triggeredOnStart: true
    onTriggered: if (!cameraProbe.running) cameraProbe.running = true
  }

  // ------------------------------------------------------------------
  // Media tint: the theme accent, or (visualizerColor: "artwork") the most
  // vivid color of the cover, like iOS. It colors the equalizer and glow.
  // ------------------------------------------------------------------
  ColorQuantizer {
    id: quantizer
    source: root.artworkTint && root.mediaArt ? root.mediaArt : ""
    depth: 3
    rescaleSize: 64
  }

  readonly property color mediaTint: {
    if (!artworkTint) return accentColor
    var best = null
    var bestScore = 0
    var colors = quantizer.colors || []
    for (var i = 0; i < colors.length; i++) {
      var c = colors[i]
      if (c.hsvValue < 0.35) continue
      var score = c.hsvSaturation * c.hsvValue
      if (score > bestScore) { best = c; bestScore = score }
    }
    return best && bestScore > 0.12 ? Qt.hsva(best.hsvHue, Math.max(0.45, best.hsvSaturation), Math.max(0.75, best.hsvValue), 1) : accentColor
  }

  // ------------------------------------------------------------------
  // Audio outputs ("Play on")
  // ------------------------------------------------------------------
  readonly property var audioOutputs: pwNodes.filter(function(n) { return n && n.isSink && !n.isStream && n.audio })
  property bool outputsOpen: false

  function openOutputs() { outputsOpen = true; userExpanded = true }
  function closeOutputs() { outputsOpen = false }

  function outputGlyph(node) {
    if (!node) return "󰓃"
    var id = (String(node.name || "") + " " + String(node.description || "")).toLowerCase()
    if (id.indexOf("bluez") !== -1 || id.indexOf("headphone") !== -1 || id.indexOf("headset") !== -1) return "󰋋"
    if (id.indexOf("hdmi") !== -1 || id.indexOf("displayport") !== -1) return "󰡁"
    return "󰓃"
  }

  // Output names usually share a long card prefix ("Raptor Lake-P/U/H cAVS
  // Speaker", "... HDMI / DisplayPort 1 Output"); drop the shared words.
  function outputLabel(node) {
    var name = String(node && (node.description || node.nickname || node.name) || "")
    var first = name.split(" ")[0]
    // Compare only against outputs from the same card (same first word), so
    // a Bluetooth headset in the list doesn't stop the trimming.
    var group = audioOutputs.map(function(n) { return String(n.description || n.nickname || n.name || "") })
      .filter(function(a) { return a.split(" ")[0] === first })
    if (group.length < 2) return name
    var words = name.split(" ")
    var common = 0
    while (common < words.length - 1 && group.every(function(a) {
      var w = a.split(" ")
      return w.length > common + 1 && w[common] === words[common]
    })) common++
    return words.slice(common).join(" ") || name
  }

  function selectOutput(node) {
    if (!node) return
    Pipewire.preferredDefaultAudioSink = node
    closeOutputs()
    showHud({
      key: "output", layout: "label",
      label: outputLabel(node),
      icon: outputGlyph(node), valueText: "Playing on", color: accentColor, duration: 1800
    })
  }

  // ------------------------------------------------------------------
  // State
  // ------------------------------------------------------------------
  readonly property bool recordingActivity: showRecording
    && (demo && demo.recording !== undefined ? demo.recording === true : recording)
  readonly property bool mediaActivity: hasMedia && (mediaPlaying || mediaLinger || (demoMedia !== null))
  readonly property bool micActivity: showMic && (demo && demo.mic !== undefined ? demo.mic === true : micActive)
  readonly property bool inboxActivity: showInbox && inbox.length > 0
  readonly property bool timerActivity: clockSource.timerActive
  readonly property bool stopwatchActivity: clockSource.stopwatchActive
  readonly property bool scriptActivity: activitySource.current !== null
  readonly property bool calendarActivity: setting("calendar", true) !== false && calendarSource.soon

  readonly property var activityList: Model.activities({
    recording: recordingActivity,
    media: mediaActivity,
    mic: micActivity || (setting("camera", true) !== false && cameraActive),
    inbox: inboxActivity,
    timer: timerActivity,
    stopwatch: stopwatchActivity,
    activity: scriptActivity,
    calendar: calendarActivity
  })
  readonly property string primary: activityList.length > 0 ? activityList[0] : ""
  readonly property string secondary: activityList.length > 1 ? activityList[1] : ""

  property bool userExpanded: false
  property bool inboxOpen: false
  // Which activity an opened island is about (the bubble's, when the
  // bubble was clicked).
  property string openFocus: ""
  property var hud: null
  readonly property bool hovered: islandHover.hovered

  readonly property string view: Model.viewFor({
    userExpanded: userExpanded,
    inboxOpen: inboxOpen,
    outputsOpen: outputsOpen,
    focus: openFocus,
    hasMedia: hasMedia,
    recording: recordingActivity,
    hud: hud,
    notification: notification !== null,
    notificationActions: notification !== null && notification.actions.length > 0,
    primary: primary,
    idleHidden: idleHidden,
    hovered: hovered
  })
  readonly property var viewCounts: ({ inbox: inbox.length, outputs: audioOutputs.length })
  readonly property var viewSize: Model.sizeFor(view, viewCounts, notchSize)
  function slotSize(name) { return Model.sizeFor(name, viewCounts, notchSize) }
  readonly property bool showBubble: secondary !== "" && !userExpanded && hud === null

  function showHud(next) {
    hud = next
    hudTimer.interval = Math.max(600, Number(next.duration) || 1600)
    hudTimer.restart()
  }

  Timer { id: hudTimer; onTriggered: root.hud = null }

  function expand() {
    hud = null
    userExpanded = true
    // Opened without the pointer on it (IPC, keybind): close on its own.
    if (!hovered) {
      collapseTimer.interval = 6000
      collapseTimer.restart()
    }
  }

  function collapse() {
    userExpanded = false
    inboxOpen = false
    outputsOpen = false
    openFocus = ""
    collapseTimer.stop()
  }

  function toggleExpanded() {
    if (userExpanded) collapse()
    else expand()
  }

  // Leaving an opened island closes it, the way a notch shelf does.
  Timer {
    id: collapseTimer
    interval: 500
    onTriggered: if (!root.hovered) root.collapse()
  }

  Timer {
    id: hoverExpandTimer
    interval: 380
    onTriggered: if (root.hovered && !root.userExpanded) root.expand()
  }

  onHoveredChanged: {
    if (hovered) {
      collapseTimer.stop()
      if (expandOnHover) hoverExpandTimer.restart()
    } else {
      hoverExpandTimer.stop()
      if (userExpanded) {
        collapseTimer.interval = 500
        collapseTimer.restart()
      }
    }
  }

  function islandClicked(button) {
    if (button === Qt.MiddleButton) {
      if (hasMedia) mediaToggle()
      return
    }
    // The bell owns the pill when nothing else is live: open the inbox.
    if (!userExpanded && primary === "inbox") {
      openInbox()
      return
    }
    toggleExpanded()
  }

  // ------------------------------------------------------------------
  // Shell contract + IPC
  // ------------------------------------------------------------------
  readonly property bool opened: userExpanded

  function open(payloadJson) {
    var payload = {}
    try { payload = JSON.parse(payloadJson || "{}") } catch (e) {}
    if (payload && payload.title) toast(payload)
    else expand()
  }

  function close() { collapse() }
  function toggle() { toggleExpanded() }

  function toneFor(name) {
    var n = String(name || "")
    if (n === "" || n === "accent") return accentColor
    if (n === "green" || n === "success") return greenColor
    if (n === "orange" || n === "yellow" || n === "warning") return orangeColor
    if (n === "red" || n === "urgent" || n === "error") return urgentColor
    if (n === "foreground") return fg
    return n
  }

  function toast(payload) {
    showHud({
      key: "toast",
      layout: "toast",
      title: String(payload.title || ""),
      body: String(payload.body || ""),
      icon: String(payload.icon || ""),
      color: toneFor(payload.color),
      duration: Number(payload.duration) || 4000
    })
  }

  function runDemo(kind) {
    // Switching demo data swaps the "current track"; that is not a real track
    // change, so mark it as already shown before the debounce looks at it.
    Qt.callLater(function() { root.shownTrack = root.trackSignature })
    var art = Quickshell.env("HOME") + "/.local/state/omarchy/current/background"
    var media = { playing: true, title: "Midnight City", artist: "M83", art: "file://" + art, length: 243 }
    if (kind === "off") {
      demo = null; hud = null; collapse(); recordingProbe.running = true; cameraProbe.running = true
      clocks.cancelTimer(); clocks.resetStopwatch(); activitySource.end("demo", ""); calendarSource.refresh()
    } else if (kind === "media") {
      demo = { media: media }; mediaPosition = 71
    } else if (kind === "paused") {
      media.playing = false; demo = { media: media }; mediaPosition = 71
    } else if (kind === "recording") {
      demo = { recording: true }; recordingElapsed = 42
    } else if (kind === "mic") {
      demo = { mic: true }
    } else if (kind === "split") {
      demo = { media: media, recording: true }; recordingElapsed = 42; mediaPosition = 71
    } else if (kind === "expanded") {
      demo = { media: media }; mediaPosition = 71; expand()
    } else if (kind === "recording-expanded") {
      demo = { media: media, recording: true }; recordingElapsed = 42; mediaPosition = 71; expand()
    } else if (kind === "idle-expanded") {
      demo = { media: null, recording: false, mic: false }; expand()
    } else if (kind === "volume") {
      showHud({ layout: "progress", icon: Model.volumeIcon(0.62, false), value: 0.62, valueText: "62%", color: fg, duration: 2500 })
    } else if (kind === "brightness") {
      showHud({ layout: "progress", icon: Model.brightnessIcon(0.8), value: 0.8, valueText: "80%", color: fg, duration: 2500 })
    } else if (kind === "charging") {
      showHud({ layout: "label", label: "Charging", icon: Model.batteryIcon(0.8, true), valueText: "80%", color: greenColor, duration: 3000 })
    } else if (kind === "lowbattery") {
      showHud({ layout: "label", label: "Low Battery", icon: Model.batteryIcon(0.1, false), valueText: "10%", color: urgentColor, duration: 3000 })
    } else if (kind === "track") {
      demo = { media: media }; mediaPosition = 0; showHud({ layout: "track", duration: 3200 })
    } else if (kind === "notification" || kind === "notification-actions") {
      notifications.inject({
        app: "Discord", appIcon: "discord", summary: "Arjun",
        body: "are we shipping the dynamic island today? it looks sick",
        actions: kind === "notification-actions" ? [{ id: "reply", text: "Reply" }, { id: "read", text: "Mark as Read" }] : []
      })
    } else if (kind === "inbox") {
      var samples = [
        { app: "Discord", appIcon: "discord", summary: "Arjun", body: "are we shipping the dynamic island today?" },
        { app: "Chromium", appIcon: "chromium", summary: "GitHub", body: "Your pull request was merged" },
        { app: "omarchy-update", glyph: "󰚰", summary: "Update available", body: "Omarchy 4.0.5 is ready to install" }
      ]
      for (var i = 0; i < samples.length; i++) {
        notifications.inject(samples[i])
        notifications.retire(notifications.current.key)
      }
      openInbox()
    } else if (kind === "timer") {
      clocks.startTimer(272, "Tea")
    } else if (kind === "stopwatch") {
      clocks.resetStopwatch(); clocks.toggleStopwatch()
    } else if (kind === "activity") {
      activitySource.update("demo", { title: "Building omarchy-dynamic-island", subtitle: "Compiling views · 14 of 22", icon: "󰏗", progress: 0.64, color: "green", ttl: 60 })
    } else if (kind === "calendar") {
      calendarSource.demo()
    } else if (kind === "camera") {
      demo = { camera: true }; cameraActive = true
    } else if (kind === "device") {
      showHud({ key: "device", layout: "label", label: "WH-1000XM5", icon: Model.deviceGlyph("audio-headset"), valueText: "82%", color: greenColor, duration: 3000 })
    } else if (kind === "outputs") {
      demo = { media: media }; mediaPosition = 71; openOutputs()
    } else if (kind === "toast") {
      toast({ title: "Build finished", body: "omarchy-dynamic-island · 0 errors", icon: "󰄬", color: "green" })
    } else {
      return "unknown demo: " + kind
    }
    return "ok"
  }

  IpcHandler {
    target: "dynamic-island"

    function expand(): string { root.expand(); return "ok" }
    function collapse(): string { root.collapse(); return "ok" }
    function toggle(): string { root.toggleExpanded(); return "ok" }
    function toast(title: string, body: string, icon: string, color: string): string {
      root.toast({ title: title, body: body, icon: icon, color: color })
      return "ok"
    }
    function show(payloadJson: string): string { root.open(payloadJson); return "ok" }
    function demo(kind: string): string { return root.runDemo(kind) }

    // Timer: "25m", "90s", "1h30m", "10:00", or plain minutes.
    function timer(duration: string, label: string): string {
      var seconds = Model.parseDuration(duration)
      if (seconds <= 0) return "bad duration: " + duration
      root.clocks.startTimer(seconds, label)
      return "ok"
    }
    function timerToggle(): string { root.clocks.toggleTimer(); return "ok" }
    function timerCancel(): string { root.clocks.cancelTimer(); return "ok" }
    // Stopwatch: start | pause | toggle | reset
    function stopwatch(action: string): string {
      var a = String(action || "toggle")
      if (a === "reset") root.clocks.resetStopwatch()
      else if (a === "start" && !root.clocks.stopwatchRunning) root.clocks.toggleStopwatch()
      else if (a === "pause" && root.clocks.stopwatchRunning) root.clocks.toggleStopwatch()
      else if (a === "toggle") root.clocks.toggleStopwatch()
      return "ok"
    }
    // Live activity for scripts; payload is JSON (see Activities.qml).
    function activity(id: string, payloadJson: string): string {
      var payload = {}
      try { payload = JSON.parse(payloadJson || "{}") } catch (e) { return "bad json" }
      return activitySource.update(id, payload)
    }
    function endActivity(id: string, message: string): string { return activitySource.end(id, message) }
    function activities(): string { return JSON.stringify(activitySource.list()) }
    function refreshCalendar(): string { calendarSource.refresh(); return "ok" }
    function state(): string {
      return JSON.stringify({
        view: root.view,
        primary: root.primary,
        secondary: root.secondary,
        expanded: root.userExpanded,
        hud: root.hud ? root.hud.layout : null,
        media: { has: root.hasMedia, playing: root.mediaPlaying, title: root.mediaTitle },
        recording: root.recordingActivity,
        mic: root.micActivity,
        battery: root.hasBattery ? Math.round(root.batteryLevel * 100) : null,
        brightness: root.brightness,
        timer: root.clocks.timerActive ? Math.ceil(root.clocks.timerLeft / 1000) : null,
        stopwatch: root.clocks.stopwatchActive ? Math.round(root.clocks.stopwatchElapsed / 100) / 10 : null,
        activity: root.activity ? root.activity.id : null,
        nextEvent: root.calendar.next ? root.calendar.next.title : null,
        camera: root.cameraActive,
        outputs: root.audioOutputs.length,
        notifications: {
          serving: root.notificationsReady,
          omarchyDisabled: root.omarchyNotificationsOff,
          showing: root.notification ? root.notification.summary : null,
          pending: root.notificationsPending,
          inbox: root.inbox.length,
          dnd: notifications.doNotDisturb
        },
        screen: win.screen ? win.screen.name : null
      })
    }
    function ping(): string { return "ok" }
  }

  // ------------------------------------------------------------------
  // Window
  // ------------------------------------------------------------------
  readonly property var targetScreen: {
    var screens = Quickshell.screens
    if (!screens || screens.length === 0) return null
    var wanted = monitorSetting
    if (wanted === "focused" && Hyprland.focusedMonitor) wanted = Hyprland.focusedMonitor.name
    for (var i = 0; i < screens.length; i++)
      if (screens[i].name === wanted) return screens[i]
    return screens[0]
  }

  PanelWindow {
    id: win

    screen: root.targetScreen
    anchors { top: true; left: true; right: true }
    // Tall enough for the biggest view (a full inbox or output list); only
    // the island itself takes input, the rest of the strip is click-through.
    implicitHeight: root.s(360) + root.topMargin
    color: "transparent"

    WlrLayershell.namespace: "dynamic-island"
    WlrLayershell.layer: root.setting("layer", "top") === "overlay" ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: root.reserveSpace ? ExclusionMode.Normal : ExclusionMode.Ignore
    exclusiveZone: root.reserveSpace ? root.s(32) + root.topMargin : 0

    mask: Region {
      item: island
      Region { item: bubble; intersection: Intersection.Combine }
    }

    Item {
      id: stage
      anchors.fill: parent

      // The spring: each dimension chases the current view's target with a
      // little overshoot, which is most of what makes it feel like iOS.
      property real w: root.s(root.viewSize.w)
      property real h: root.s(root.viewSize.h)
      property real r: root.s(root.viewSize.r)

      Behavior on w { SpringAnimation { spring: 3.4; damping: 0.28; mass: 1.0; epsilon: 0.25 } }
      Behavior on h { SpringAnimation { spring: 3.4; damping: 0.32; mass: 1.0; epsilon: 0.25 } }
      Behavior on r { SpringAnimation { spring: 3.4; damping: 0.32; mass: 1.0; epsilon: 0.25 } }

      readonly property real earSize: root.s(9)

      // Notch style: concave fillets joining the island to the screen edge.
      Shape {
        visible: root.notch && island.width > stage.earSize * 2
        x: island.x - stage.earSize
        y: 0
        width: stage.earSize
        height: stage.earSize
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          fillColor: root.surface
          strokeColor: "transparent"
          startX: 0; startY: 0
          PathLine { x: stage.earSize; y: 0 }
          PathLine { x: stage.earSize; y: stage.earSize }
          PathArc { x: 0; y: 0; radiusX: stage.earSize; radiusY: stage.earSize; direction: PathArc.Counterclockwise }
        }
      }

      Shape {
        visible: root.notch && island.width > stage.earSize * 2
        x: island.x + island.width
        y: 0
        width: stage.earSize
        height: stage.earSize
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          fillColor: root.surface
          strokeColor: "transparent"
          startX: 0; startY: 0
          PathLine { x: stage.earSize; y: 0 }
          PathArc { x: 0; y: stage.earSize; radiusX: stage.earSize; radiusY: stage.earSize; direction: PathArc.Counterclockwise }
          PathLine { x: 0; y: 0 }
        }
      }

      // A soft light behind the island in the music's color while something
      // plays. Only this glow goes through a blur layer; the island itself
      // is never layered, so its content stays sharp.
      Rectangle {
        id: glow
        readonly property bool lit: root.glowEnabled && root.mediaPlaying
          && (root.view === "media" || root.view === "media-expanded" || root.view === "hud-track")
        x: island.x - root.s(4)
        y: island.y + root.s(2)
        width: island.width + root.s(8)
        height: island.height + root.s(2)
        radius: island.radius
        color: root.mediaTint
        opacity: lit ? breath : 0
        visible: opacity > 0.01
        property real breath: 0.5

        Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.InOutSine } }

        SequentialAnimation on breath {
          running: glow.lit
          loops: Animation.Infinite
          NumberAnimation { to: 0.28; duration: 1600; easing.type: Easing.InOutSine }
          NumberAnimation { to: 0.55; duration: 1600; easing.type: Easing.InOutSine }
        }

        layer.enabled: visible
        layer.effect: MultiEffect {
          blurEnabled: true
          blur: 1.0
          blurMax: 40
          autoPaddingEnabled: true
        }
      }

      // A plain Rectangle with scissor clipping on purpose: clipping through
      // an offscreen layer blurs everything inside at fractional scaling.
      Rectangle {
        id: island

        // In notch style the top corners are pushed off-screen so only the
        // bottom ones round.
        readonly property real lift: root.notch ? stage.r : 0

        x: Math.round((stage.width - width) / 2)
        y: root.topMargin - lift
        width: Math.max(0, stage.w)
        height: Math.max(0, stage.h) + lift
        radius: Math.max(0, Math.min(stage.r, height / 2, width / 2))
        color: root.surface
        border.width: root.notch ? 0 : 1
        border.color: root.outline
        clip: true
        opacity: width < 4 ? 0 : 1
        scale: islandPress.pressed ? 0.965 : 1
        transformOrigin: Item.Top

        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
        Behavior on opacity { NumberAnimation { duration: 160 } }

        HoverHandler { id: islandHover }

        Item {
          id: content
          y: island.lift
          width: island.width
          height: Math.max(0, stage.h)

          MouseArea {
            id: islandPress
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            onClicked: function(mouse) { root.islandClicked(mouse.button) }
            onWheel: function(wheel) { root.adjustVolume(wheel.angleDelta.y) }
          }

          ViewSlot {
            active: root.view === "media"
            width: root.s(root.slotSize("media").w); height: root.s(root.slotSize("media").h)
            MediaCompact { anchors.fill: parent; island: root }
          }

          ViewSlot {
            active: root.view === "recording"
            width: root.s(root.slotSize("recording").w); height: root.s(root.slotSize("recording").h)
            RecordingCompact { anchors.fill: parent; island: root }
          }

          ViewSlot {
            active: root.view === "mic"
            width: root.s(root.slotSize("mic").w); height: root.s(root.slotSize("mic").h)
            MicCompact { anchors.fill: parent; island: root }
          }

          ViewSlot {
            active: root.view === "hud-progress"
            width: root.s(root.slotSize("hud-progress").w); height: root.s(root.slotSize("hud-progress").h)
            HudProgress { anchors.fill: parent; island: root }
          }

          ViewSlot {
            active: root.view === "hud-label"
            width: root.s(root.slotSize("hud-label").w); height: root.s(root.slotSize("hud-label").h)
            HudLabel { anchors.fill: parent; island: root }
          }

          ViewSlot {
            active: root.view === "hud-track"
            width: root.s(root.slotSize("hud-track").w); height: root.s(root.slotSize("hud-track").h)
            TrackHud { anchors.fill: parent; island: root }
          }

          ViewSlot {
            active: root.view === "hud-toast"
            width: root.s(root.slotSize("hud-toast").w); height: root.s(root.slotSize("hud-toast").h)
            ToastHud { anchors.fill: parent; island: root }
          }

          ViewSlot {
            active: root.view === "media-expanded"
            width: root.s(root.slotSize("media-expanded").w); height: root.s(root.slotSize("media-expanded").h)
            MediaExpanded { anchors.fill: parent; island: root }
          }

          ViewSlot {
            active: root.view === "recording-expanded"
            width: root.s(root.slotSize("recording-expanded").w); height: root.s(root.slotSize("recording-expanded").h)
            RecordingExpanded { anchors.fill: parent; island: root }
          }

          ViewSlot {
            active: root.view === "recording-media-expanded"
            width: root.s(root.slotSize("recording-media-expanded").w); height: root.s(root.slotSize("recording-media-expanded").h)
            RecordingExpanded { anchors.fill: parent; island: root }
          }

          ViewSlot {
            active: root.view === "notification"
            width: root.s(root.slotSize("notification").w); height: root.s(root.slotSize("notification").h)
            NotificationView { anchors.fill: parent; island: root }
          }

          ViewSlot {
            active: root.view === "notification-actions"
            width: root.s(root.slotSize("notification-actions").w); height: root.s(root.slotSize("notification-actions").h)
            NotificationView { anchors.fill: parent; island: root }
          }

          ViewSlot {
            active: root.view === "inbox"
            width: root.s(root.slotSize("inbox").w); height: root.s(root.slotSize("inbox").h)
            InboxCompact { anchors.fill: parent; island: root }
          }

          ViewSlot {
            active: root.view === "inbox-expanded"
            width: root.s(root.slotSize("inbox-expanded").w); height: root.s(root.slotSize("inbox-expanded").h)
            InboxView { anchors.fill: parent; island: root }
          }

          ViewSlot {
            active: root.view === "timer"
            width: root.s(root.slotSize("timer").w); height: root.s(root.slotSize("timer").h)
            ClockCompact { anchors.fill: parent; island: root; mode: "timer" }
          }

          ViewSlot {
            active: root.view === "stopwatch"
            width: root.s(root.slotSize("stopwatch").w); height: root.s(root.slotSize("stopwatch").h)
            ClockCompact { anchors.fill: parent; island: root; mode: "stopwatch" }
          }

          ViewSlot {
            active: root.view === "activity"
            width: root.s(root.slotSize("activity").w); height: root.s(root.slotSize("activity").h)
            ActivityCompact { anchors.fill: parent; island: root }
          }

          ViewSlot {
            active: root.view === "calendar"
            width: root.s(root.slotSize("calendar").w); height: root.s(root.slotSize("calendar").h)
            CalendarCompact { anchors.fill: parent; island: root }
          }

          ViewSlot {
            active: root.view === "clock-expanded"
            width: root.s(root.slotSize("clock-expanded").w); height: root.s(root.slotSize("clock-expanded").h)
            ClockExpanded { anchors.fill: parent; island: root }
          }

          ViewSlot {
            active: root.view === "activity-expanded"
            width: root.s(root.slotSize("activity-expanded").w); height: root.s(root.slotSize("activity-expanded").h)
            ActivityExpanded { anchors.fill: parent; island: root }
          }

          ViewSlot {
            active: root.view === "outputs-expanded"
            width: root.s(root.slotSize("outputs-expanded").w); height: root.s(root.slotSize("outputs-expanded").h)
            OutputsView { anchors.fill: parent; island: root }
          }

          ViewSlot {
            active: root.view === "idle-expanded"
            width: root.s(root.slotSize("idle-expanded").w); height: root.s(root.slotSize("idle-expanded").h)
            IdleExpanded { anchors.fill: parent; island: root }
          }
        }
      }

      // Split island: the second live activity in its own circle.
      Rectangle {
        id: bubble

        readonly property real d: root.s(32)
        readonly property real restX: island.x + island.width + root.s(8)

        width: d
        height: d
        radius: d / 2
        y: root.notch ? root.s(4) : root.topMargin
        x: root.showBubble ? restX : island.x + island.width - d
        color: root.surface
        border.width: root.notch ? 0 : 1
        border.color: root.outline
        opacity: root.showBubble ? 1 : 0
        scale: root.showBubble ? 1 : 0.4
        visible: opacity > 0.01
        clip: true

        Behavior on x { SpringAnimation { spring: 3.4; damping: 0.3; epsilon: 0.25 } }
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack } }

        BubbleContent {
          anchors.fill: parent
          island: root
          kind: root.secondary
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (root.secondary === "inbox") { root.openInbox(); return }
            root.openFocus = root.secondary
            root.expand()
          }
        }
      }
    }
  }
}
