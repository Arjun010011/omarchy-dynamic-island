import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "IslandModel.js" as Model

// The island's notification daemon.
//
// Only one process can own org.freedesktop.Notifications, so this runs only
// while Omarchy's own `omarchy.notifications` service is disabled (Island.qml
// arranges that). It answers the same `notifications` IPC target, so
// Omarchy's keybinds and scripts (dismiss, invoke, history, silencing) keep
// working, and it shares Omarchy's do-not-disturb state file.
//
// Life of a notification, iOS style:
//   banner  - it drops out of the island for a few seconds;
//   inbox   - if it was not clicked or closed, it waits in the inbox (a bell
//             with a count in the island) until opened or cleared;
//   gone    - clicking it jumps to the app, × clears it.
Item {
  id: service

  property var island: null
  // Held off until Omarchy's server has let go of the bus name.
  property bool active: false

  readonly property string home: Quickshell.env("HOME")
  readonly property string stateDir: home + "/.local/state/omarchy/dynamic-island"
  readonly property string settingsPath: home + "/.local/state/omarchy/notifications.json"
  readonly property string inboxPath: stateDir + "/inbox.json"
  readonly property int inboxLimit: 50

  // Newest first. Each entry is a plain snapshot plus `ref`, the live
  // Notification while its sender still holds it (for actions and updates).
  property var banners: []
  property var inbox: []
  readonly property var current: banners.length > 0 ? banners[0] : null
  readonly property int pending: Math.max(0, banners.length - 1)
  property bool doNotDisturb: false
  property int serial: 0
  property bool tearingDown: false

  Component.onDestruction: tearingDown = true

  // ---------------------------------------------------------------- server
  LazyLoader {
    active: service.active

    NotificationServer {
      keepOnReload: false
      imageSupported: true
      actionsSupported: true
      bodyMarkupSupported: true
      bodyHyperlinksSupported: false
      persistenceSupported: true

      onNotification: function(notification) { service.receive(notification) }
    }
  }

  function receive(n) {
    n.tracked = true
    var entry = snapshot(n)
    // The sender withdrew it (read elsewhere, app closed it): drop it
    // everywhere without echoing a close back. Only a sender's own
    // CloseNotification counts; objects torn down with the shell (restart,
    // reload) also emit `closed`, and those must stay in the saved inbox.
    n.closed.connect(function(reason) {
      if (service.tearingDown || reason !== NotificationCloseReason.CloseRequested) return
      service.remove(entry.key, "")
    })

    // A replaces_id update arrives as the same object: replace, don't stack.
    banners = banners.filter(function(e) { return e.ref !== n })
    var before = inbox.length
    inbox = inbox.filter(function(e) { return e.ref !== n })
    if (inbox.length !== before) saveInbox()

    if (doNotDisturb && !bypassesDnd(entry)) {
      // Silenced: no banner, straight to the inbox so nothing is missed.
      if (Model.isEphemeralApp(entry.app)) n.tracked = false
      else addToInbox(entry)
      return
    }
    banners = [entry].concat(banners)
  }

  function snapshot(n) {
    serial += 1
    var actions = []
    try {
      for (var i = 0; i < n.actions.length; i++) {
        var a = n.actions[i]
        if (a && a.identifier !== "default" && a.text) actions.push({ id: a.identifier, text: a.text })
      }
    } catch (e) {}
    return {
      key: serial,
      ref: n,
      app: String(n.appName || ""),
      appIcon: String(n.appIcon || ""),
      desktopEntry: String(n.desktopEntry || ""),
      summary: Model.plainText(n.summary),
      body: Model.plainText(n.body),
      image: String(n.image || ""),
      // Omarchy's own toasts: a Nerd Font glyph for the icon slot and a
      // command to run on click (omarchy-notification-send --glyph/--exec).
      glyph: Model.stringHint(n.hints, "omarchy-glyph"),
      execArgv: Model.stringHint(n.hints, "omarchy-exec-argv"),
      critical: n.urgency === NotificationUrgency.Critical,
      low: n.urgency === NotificationUrgency.Low,
      timeout: Number(n.expireTimeout || 0),
      actions: actions.slice(0, 3),
      time: Date.now()
    }
  }

  // Demo / testing: a notification with no live sender.
  function inject(fields) {
    serial += 1
    banners = [{
      key: serial, ref: null, app: fields.app || "", appIcon: fields.appIcon || "", desktopEntry: "",
      summary: fields.summary || "", body: fields.body || "", image: fields.image || "",
      glyph: fields.glyph || "", execArgv: "", critical: fields.critical === true, low: false,
      timeout: 0, actions: fields.actions || [], time: Date.now()
    }].concat(banners)
  }

  // Omarchy's rule: its own action toasts, and bare `notify-send` criticals.
  function bypassesDnd(entry) {
    return entry.app === "omarchy-action" || (entry.app === "notify-send" && entry.critical)
  }

  // How long a banner holds, iOS short. Critical ones stay until handled; a
  // sender's own longer timeout is honoured.
  function durationFor(entry) {
    if (!entry || entry.critical) return 0
    var base = entry.low ? 4000 : 6000
    return Math.min(30000, Math.max(base, entry.timeout > 0 ? entry.timeout : 0))
  }

  function find(key) {
    for (var i = 0; i < banners.length; i++) if (banners[i].key === key) return banners[i]
    for (var j = 0; j < inbox.length; j++) if (inbox[j].key === key) return inbox[j]
    return null
  }

  // Take an entry out of the banners and the inbox. `close` is how the
  // sender is told: "dismiss" (user cleared it), "expire", or "" (silent).
  function remove(key, close) {
    var entry = find(key)
    if (!entry) return null
    banners = banners.filter(function(e) { return e.key !== key })
    var before = inbox.length
    inbox = inbox.filter(function(e) { return e.key !== key })
    if (inbox.length !== before) saveInbox()
    var ref = entry.ref
    entry.ref = null
    if (ref && close) {
      try {
        if (close === "dismiss") ref.dismiss()
        else ref.expire()
      } catch (e) {}
    }
    return entry
  }

  // A banner's time ran out without a click: into the inbox, unless it was
  // only feedback noise (Omarchy's "Theme changed" and friends).
  function retire(key) {
    var entry = find(key)
    if (!entry) return
    if (Model.isEphemeralApp(entry.app)) {
      remove(key, "expire")
      return
    }
    banners = banners.filter(function(e) { return e.key !== key })
    addToInbox(entry)
  }

  function addToInbox(entry) {
    // Newest arrival first, however long each banner happened to stay up.
    inbox = [entry].concat(inbox.filter(function(e) { return e.key !== entry.key }))
      .sort(function(a, b) { return b.time - a.time })
      .slice(0, inboxLimit)
    saveInbox()
  }

  // Click: the sender's own handling (its default action, or Omarchy's exec
  // command), then bring its window forward, so a click always lands in the
  // app the notification came from.
  function open(key) {
    var entry = find(key)
    if (!entry) return
    var argv = Model.parseExecArgv(entry.execArgv)
    if (argv) {
      Quickshell.execDetached(["bash", "-lc", 'exec "$@"', "bash"].concat(argv))
    } else {
      try {
        if (entry.ref && entry.ref.actions) {
          for (var i = 0; i < entry.ref.actions.length; i++) {
            var a = entry.ref.actions[i]
            if (a && a.identifier === "default") { a.invoke(); break }
          }
        }
      } catch (e) {}
      focusApp(entry)
    }
    remove(key, "dismiss")
  }

  // Omarchy's helper matches a window class; try the sender's desktop entry
  // (usually the class) and fall back to its app name.
  function focusApp(entry) {
    var app = Model.isEphemeralApp(entry.app) ? "" : String(entry.app || "")
    var desktop = String(entry.desktopEntry || "")
    if (!app && !desktop) return
    Quickshell.execDetached(["sh", "-c",
      'f="$OMARCHY_PATH/bin/omarchy-hyprland-focus-app"; { [ -n "$1" ] && "$f" "$1"; } || { [ -n "$2" ] && "$f" "$2"; }',
      "sh", desktop, app])
  }

  function invokeAction(key, id) {
    var entry = find(key)
    if (!entry) return
    try {
      if (entry.ref) {
        for (var i = 0; i < entry.ref.actions.length; i++) {
          var a = entry.ref.actions[i]
          if (a && a.identifier === id) { a.invoke(); break }
        }
      }
    } catch (e) {}
    remove(key, "dismiss")
  }

  function dismiss(key) { remove(key, "dismiss") }

  function clearAll() {
    var keys = banners.concat(inbox).map(function(e) { return e.key })
    for (var i = 0; i < keys.length; i++) remove(keys[i], "dismiss")
    saveInbox()
  }

  // The newest thing on screen, else the newest in the inbox (keybinds).
  function newestKey() {
    if (current) return current.key
    return inbox.length > 0 ? inbox[0].key : -1
  }

  // Banner timeout, paused while the pointer is on the island.
  Timer {
    id: expiry
    interval: Math.max(1000, service.durationFor(service.current))
    running: service.current !== null && service.durationFor(service.current) > 0
      && !(service.island && service.island.hovered)
    onTriggered: if (service.current) service.retire(service.current.key)
  }

  onCurrentChanged: if (expiry.running) expiry.restart()

  // ------------------------------------------------------------- inbox file
  // Snapshots only: after a restart the senders are gone, so restored rows
  // open by focusing their app.
  function saveInbox() {
    if (tearingDown) return
    var rows = inbox.map(function(e) {
      var image = e.image && e.image.indexOf("/tmp/") === -1 && e.image.indexOf("image://") !== 0 ? e.image : ""
      return {
        app: e.app, appIcon: e.appIcon, desktopEntry: e.desktopEntry, summary: e.summary,
        body: e.body, image: image, glyph: e.glyph, execArgv: e.execArgv, critical: e.critical, time: e.time
      }
    })
    inboxFile.setText(JSON.stringify(rows) + "\n")
  }

  function restoreInbox(raw) {
    var rows = []
    try { rows = JSON.parse(raw || "[]") } catch (e) { rows = [] }
    if (!Array.isArray(rows)) return
    var restored = []
    for (var i = 0; i < rows.length && i < inboxLimit; i++) {
      var r = rows[i] || {}
      serial += 1
      restored.push({
        key: serial, ref: null, app: r.app || "", appIcon: r.appIcon || "", desktopEntry: r.desktopEntry || "",
        summary: r.summary || "", body: r.body || "", image: r.image || "", glyph: r.glyph || "",
        execArgv: r.execArgv || "", critical: r.critical === true, low: false, timeout: 0,
        actions: [], time: r.time || Date.now()
      })
    }
    inbox = restored.concat(inbox)
  }

  property bool inboxRestored: false

  Process {
    running: true
    command: ["mkdir", "-p", service.stateDir]
    onExited: inboxFile.reload()
  }

  FileView {
    id: inboxFile
    path: service.inboxPath
    atomicWrites: true
    onLoaded: {
      if (service.inboxRestored) return
      service.inboxRestored = true
      service.restoreInbox(text())
    }
    // No inbox yet: nothing to restore, and the first save must not be
    // read back in as if it were old rows.
    onLoadFailed: service.inboxRestored = true
  }

  // ----------------------------------------------------------------- DND
  function setDoNotDisturb(value) {
    doNotDisturb = !!value
    settingsFile.setText(JSON.stringify({ version: 3, dnd: doNotDisturb }, null, 2) + "\n")
    if (island) island.showHud({
      key: "dnd",
      layout: "label",
      label: doNotDisturb ? "Silenced" : "Notifications On",
      icon: doNotDisturb ? "󰂛" : "󰂚",
      valueText: "",
      color: doNotDisturb ? island.orangeColor : island.fg,
      duration: 1800
    })
  }

  FileView {
    id: settingsFile
    path: service.settingsPath
    atomicWrites: true
    onLoaded: {
      try { service.doNotDisturb = JSON.parse(text() || "{}").dnd === true } catch (e) {}
    }
  }

  // ----------------------------------------------------------------- IPC
  // Same target and methods as Omarchy's service, so SUPER+, and friends,
  // omarchy-toggle-notification-silencing and omarchy-notification-* work.
  IpcHandler {
    target: "notifications"
    enabled: service.active

    function dndState(): string { return service.doNotDisturb ? "on" : "off" }
    function toggleDnd(): string { service.setDoNotDisturb(!service.doNotDisturb); return dndState() }
    function setDnd(value: string): string {
      var v = String(value || "").toLowerCase()
      service.setDoNotDisturb(v === "true" || v === "1" || v === "on" || v === "yes")
      return dndState()
    }
    function isDnd(): string { return dndState() }
    // Omarchy's "notification history" keybind opens the inbox list.
    function showHistory(): string {
      if (service.island) service.island.openInbox()
      return service.inbox.length > 0 ? "ok" : "none"
    }
    function clear(): string { service.clearAll(); return "ok" }
    function dismissAll(): string { service.clearAll(); return "ok" }
    function dismissOne(): string {
      var key = service.newestKey()
      if (key < 0) return "none"
      service.dismiss(key)
      return "ok"
    }
    function invokeLast(): string {
      var key = service.newestKey()
      if (key < 0) return "none"
      service.open(key)
      return "ok"
    }
    function dismiss(summary: string): string {
      var needle = String(summary || "")
      if (!needle) return "none"
      var keys = service.banners.concat(service.inbox)
        .filter(function(e) { return String(e.summary || "").indexOf(needle) !== -1 })
        .map(function(e) { return e.key })
      for (var i = 0; i < keys.length; i++) service.dismiss(keys[i])
      return keys.length > 0 ? "ok" : "none"
    }
    function ping(): string { return "ok" }
  }
}
