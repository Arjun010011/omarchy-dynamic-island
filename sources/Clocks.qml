import QtQuick
import Quickshell
import Quickshell.Io
import "../IslandModel.js" as Model

// Timer and stopwatch live activities. Both are stored as wall-clock
// timestamps in a small state file, so they keep running across shell
// restarts and a timer that ran out while the shell was down still rings.
Item {
  id: clocks

  property var island: null
  readonly property string statePath: Quickshell.env("HOME") + "/.local/state/omarchy/dynamic-island/clocks.json"

  property double now: Date.now()

  // ---- timer
  property double timerEnd: 0          // epoch ms while running
  property double timerLeftPaused: 0   // ms left while paused
  property double timerTotal: 0        // ms, for the progress ring
  property bool timerPaused: false
  property string timerLabel: ""

  readonly property bool timerActive: timerEnd > 0 || timerPaused
  readonly property double timerLeft: timerPaused ? timerLeftPaused : Math.max(0, timerEnd - now)
  readonly property real timerProgress: timerTotal > 0 ? Math.max(0, Math.min(1, 1 - timerLeft / timerTotal)) : 0

  // ---- stopwatch
  property double stopwatchStart: 0    // epoch ms of the current run
  property double stopwatchBanked: 0   // ms from earlier runs
  property bool stopwatchRunning: false

  readonly property bool stopwatchActive: stopwatchRunning || stopwatchBanked > 0
  readonly property double stopwatchElapsed: stopwatchBanked + (stopwatchRunning ? now - stopwatchStart : 0)

  Timer {
    interval: clocks.stopwatchRunning ? 100 : 250
    repeat: true
    running: (clocks.timerActive && !clocks.timerPaused) || clocks.stopwatchRunning
    onTriggered: {
      clocks.now = Date.now()
      if (clocks.timerActive && !clocks.timerPaused && clocks.timerEnd <= clocks.now) clocks.timerFinished()
    }
  }

  function startTimer(seconds, label) {
    var ms = Math.max(1, Number(seconds) || 0) * 1000
    now = Date.now()
    timerTotal = ms
    timerEnd = now + ms
    timerPaused = false
    timerLeftPaused = 0
    timerLabel = String(label || "")
    save()
  }

  function toggleTimer() {
    if (!timerActive) return
    now = Date.now()
    if (timerPaused) {
      timerEnd = now + timerLeftPaused
      timerPaused = false
    } else {
      timerLeftPaused = Math.max(0, timerEnd - now)
      timerEnd = 0
      timerPaused = true
    }
    save()
  }

  function addToTimer(seconds) {
    if (!timerActive) return
    var ms = seconds * 1000
    if (timerPaused) timerLeftPaused += ms
    else timerEnd += ms
    timerTotal += ms
    save()
  }

  function cancelTimer() {
    timerEnd = 0
    timerPaused = false
    timerLeftPaused = 0
    timerTotal = 0
    timerLabel = ""
    save()
  }

  function timerFinished() {
    var label = timerLabel
    cancelTimer()
    if (!island) return
    island.toast({
      title: label || "Timer",
      body: "Time's up",
      icon: "󰀠",
      color: "accent",
      duration: 12000
    })
    if (island.setting("timerSound", true) !== false)
      Quickshell.execDetached(["sh", "-c",
        "for i in 1 2 3; do pw-play /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga 2>/dev/null " +
        "|| paplay /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga 2>/dev/null; done"])
  }

  function toggleStopwatch() {
    now = Date.now()
    if (stopwatchRunning) {
      stopwatchBanked += now - stopwatchStart
      stopwatchRunning = false
    } else {
      stopwatchStart = now
      stopwatchRunning = true
    }
    save()
  }

  function resetStopwatch() {
    stopwatchRunning = false
    stopwatchBanked = 0
    stopwatchStart = 0
    save()
  }

  // ---- persistence
  property bool restored: false

  function save() {
    if (!restored) return
    stateFile.setText(JSON.stringify({
      timerEnd: timerEnd, timerLeftPaused: timerLeftPaused, timerTotal: timerTotal,
      timerPaused: timerPaused, timerLabel: timerLabel,
      stopwatchStart: stopwatchStart, stopwatchBanked: stopwatchBanked, stopwatchRunning: stopwatchRunning
    }) + "\n")
  }

  FileView {
    id: stateFile
    path: clocks.statePath
    printErrors: false
    atomicWrites: true
    onLoaded: {
      if (clocks.restored) return
      clocks.restored = true
      var s = {}
      try { s = JSON.parse(text() || "{}") } catch (e) { s = {} }
      clocks.now = Date.now()
      clocks.timerEnd = Number(s.timerEnd) || 0
      clocks.timerLeftPaused = Number(s.timerLeftPaused) || 0
      clocks.timerTotal = Number(s.timerTotal) || 0
      clocks.timerPaused = s.timerPaused === true
      clocks.timerLabel = String(s.timerLabel || "")
      clocks.stopwatchStart = Number(s.stopwatchStart) || 0
      clocks.stopwatchBanked = Number(s.stopwatchBanked) || 0
      clocks.stopwatchRunning = s.stopwatchRunning === true
      // Ran out while the shell was down: ring now.
      if (clocks.timerEnd > 0 && !clocks.timerPaused && clocks.timerEnd <= clocks.now) clocks.timerFinished()
    }
    onLoadFailed: clocks.restored = true
  }
}
