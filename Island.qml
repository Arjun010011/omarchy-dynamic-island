import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs.Commons
import "views"
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
  readonly property int mediaLingerMs: Math.max(0, Number(setting("mediaLingerSeconds", 30))) * 1000

  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.settings = Model.entryFor(text(), root.pluginId)
    onLoadFailed: root.settings = ({})
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
  property string lastPlayingKey: ""
  property int playerTick: 0
  readonly property var player: { playerTick; return Model.pickPlayer(players, lastPlayingKey) }

  Instantiator {
    model: root.players
    delegate: Connections {
      required property var modelData
      target: modelData
      function onIsPlayingChanged() {
        if (modelData.isPlaying) root.lastPlayingKey = Model.playerKey(modelData)
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

  // ------------------------------------------------------------------
  // State
  // ------------------------------------------------------------------
  readonly property bool recordingActivity: showRecording
    && (demo && demo.recording !== undefined ? demo.recording === true : recording)
  readonly property bool mediaActivity: hasMedia && (mediaPlaying || mediaLinger || (demoMedia !== null))
  readonly property bool micActivity: showMic && (demo && demo.mic !== undefined ? demo.mic === true : micActive)

  readonly property var activityList: Model.activities({
    recording: recordingActivity,
    media: mediaActivity,
    mic: micActivity
  })
  readonly property string primary: activityList.length > 0 ? activityList[0] : ""
  readonly property string secondary: activityList.length > 1 ? activityList[1] : ""

  property bool userExpanded: false
  property var hud: null
  readonly property bool hovered: islandHover.hovered

  readonly property string view: Model.viewFor({
    userExpanded: userExpanded,
    hasMedia: hasMedia,
    hud: hud,
    primary: primary,
    idleHidden: idleHidden,
    hovered: hovered
  })
  readonly property var viewSize: Model.sizeFor(view)
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
      demo = null; hud = null; collapse(); recordingProbe.running = true
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
    implicitHeight: root.s(230) + root.topMargin
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

      ClippingRectangle {
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
        opacity: width < 4 ? 0 : 1
        scale: islandPress.pressed ? 0.965 : (root.hovered && !root.userExpanded && root.hud === null && root.primary !== "" ? 1.03 : 1)
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
            width: root.s(Model.sizes["media"].w); height: root.s(Model.sizes["media"].h)
            MediaCompact { anchors.fill: parent; island: root }
          }

          ViewSlot {
            active: root.view === "recording"
            width: root.s(Model.sizes["recording"].w); height: root.s(Model.sizes["recording"].h)
            RecordingCompact { anchors.fill: parent; island: root }
          }

          ViewSlot {
            active: root.view === "mic"
            width: root.s(Model.sizes["mic"].w); height: root.s(Model.sizes["mic"].h)
            MicCompact { anchors.fill: parent; island: root }
          }

          ViewSlot {
            active: root.view === "hud-progress"
            width: root.s(Model.sizes["hud-progress"].w); height: root.s(Model.sizes["hud-progress"].h)
            HudProgress { anchors.fill: parent; island: root }
          }

          ViewSlot {
            active: root.view === "hud-label"
            width: root.s(Model.sizes["hud-label"].w); height: root.s(Model.sizes["hud-label"].h)
            HudLabel { anchors.fill: parent; island: root }
          }

          ViewSlot {
            active: root.view === "hud-track"
            width: root.s(Model.sizes["hud-track"].w); height: root.s(Model.sizes["hud-track"].h)
            TrackHud { anchors.fill: parent; island: root }
          }

          ViewSlot {
            active: root.view === "hud-toast"
            width: root.s(Model.sizes["hud-toast"].w); height: root.s(Model.sizes["hud-toast"].h)
            ToastHud { anchors.fill: parent; island: root }
          }

          ViewSlot {
            active: root.view === "media-expanded"
            width: root.s(Model.sizes["media-expanded"].w); height: root.s(Model.sizes["media-expanded"].h)
            MediaExpanded { anchors.fill: parent; island: root }
          }

          ViewSlot {
            active: root.view === "idle-expanded"
            width: root.s(Model.sizes["idle-expanded"].w); height: root.s(Model.sizes["idle-expanded"].h)
            IdleExpanded { anchors.fill: parent; island: root }
          }
        }
      }

      // Split island: the second live activity in its own circle.
      ClippingRectangle {
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
          onClicked: root.expand()
        }
      }
    }
  }
}
