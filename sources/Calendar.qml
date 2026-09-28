import QtQuick
import Quickshell
import Quickshell.Io
import "../IslandModel.js" as Model

// Next meeting from iCalendar feeds. Any calendar that can publish an .ics
// link works (Google "secret address in iCal format", iCloud public
// calendar, Outlook "publish calendar", Nextcloud, Fastmail) as can local
// .ics files. Configured with "calendars": [...] in the island's settings.
Item {
  id: calendar

  property var island: null
  // Links written by hand into shell.json's "calendars" setting...
  readonly property var configured: {
    var v = island ? island.setting("calendars", []) : []
    return Array.isArray(v) ? v.map(function(x) { return String(x) }) : (v ? [String(v)] : [])
  }
  // ...plus links added from the calendar view, which live in the island's
  // own file. Writing shell.json makes the shell rebuild the whole island
  // (closing the view mid-add), so the view never writes there.
  property var added: []
  readonly property var sources: {
    var out = []
    var all = configured.concat(added)
    for (var i = 0; i < all.length; i++)
      if (all[i] && out.indexOf(all[i]) === -1) out.push(all[i])
    return out
  }

  readonly property string addedDir: Quickshell.env("HOME") + "/.config/omarchy/dynamic-island"
  readonly property string addedPath: addedDir + "/calendars.json"

  function add(link) {
    var l = String(link || "").trim()
    if (!l) return
    justAdded = l
    lastResult = null
    var next = added.filter(function(x) { return x !== l })
    next.push(l)
    added = next
    addedFile.setText(JSON.stringify(next, null, 2) + "\n")
  }

  function remove(link) {
    var l = String(link || "")
    if (added.indexOf(l) !== -1) {
      added = added.filter(function(x) { return x !== l })
      addedFile.setText(JSON.stringify(added, null, 2) + "\n")
    }
    // A hand-written one: take it out of shell.json too (this reloads the
    // island, which is fine for a removal).
    if (configured.indexOf(l) !== -1 && island) island.editCalendars("remove", l)
  }

  Process {
    running: true
    command: ["mkdir", "-p", calendar.addedDir]
    onExited: addedFile.reload()
  }

  FileView {
    id: addedFile
    path: calendar.addedPath
    printErrors: false
    atomicWrites: true
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      try {
        var list = JSON.parse(text() || "[]")
        if (Array.isArray(list)) calendar.added = list.map(function(x) { return String(x) })
      } catch (e) {}
    }
  }
  readonly property int leadMinutes: island ? Math.max(1, Number(island.setting("calendarLeadMinutes", 15)) || 15) : 15

  property var events: []
  property double now: Date.now()
  // The fetched feeds, kept so the month view can read any month on demand.
  property string raw: ""
  property int version: 0

  // Every event (all-day ones too) in one month, grouped by day, for the
  // calendar view. Recomputed when the feeds are re-read.
  function month(year, monthIndex) {
    version
    var from = new Date(year, monthIndex, 1).getTime() - 7 * 86400000
    var to = new Date(year, monthIndex + 1, 1).getTime() + 14 * 86400000
    return Model.eventsByDay(Model.parseIcs(raw, from, to, true))
  }

  // The next event that has not ended yet.
  readonly property var next: {
    for (var i = 0; i < events.length; i++)
      if (events[i].end > now) return events[i]
    return null
  }
  // Live activity from `leadMinutes` before until 5 minutes after it starts.
  readonly property bool soon: next !== null && next.start - now <= leadMinutes * 60000
    && now - next.start < 5 * 60000
  readonly property string countdown: next ? Model.untilText(next.start, now) : ""

  property string announced: ""

  Timer {
    interval: 20000
    repeat: true
    running: calendar.events.length > 0
    triggeredOnStart: true
    onTriggered: {
      calendar.now = Date.now()
      var ev = calendar.next
      // One heads-up as it starts.
      if (ev && ev.start <= calendar.now && calendar.now - ev.start < 60000) {
        var key = ev.title + "@" + ev.start
        if (calendar.announced !== key && calendar.island) {
          calendar.announced = key
          calendar.island.toast({ title: ev.title || "Event", body: "Starting now", icon: "󰃭", color: "accent", duration: 8000 })
        }
      }
    }
  }

  // Fetch every source (URLs with curl, files with cat; ~ expands) and
  // parse the next week.
  // Each source is announced with a status line before its contents
  // ("@@ISLAND-SOURCE <index> ok", or "HTTP 404", "unreachable", "file not
  // found", "not a calendar"), so a bad link can be reported instead of
  // silently showing nothing.
  readonly property string fetchScript:
    'i=0; for u in "$@"; do s="${u/#\\~/$HOME}"; t=$(mktemp); st=ok; ' +
    'case "$s" in webcal://*) s="https://${s#webcal://}" ;; esac; ' +
    'case "$s" in ' +
    'http://*|https://*) code=$(curl -sL --max-time 20 -o "$t" -w "%{http_code}" "$s" 2>/dev/null) || code=000; ' +
    '  if [ "$code" = 000 ]; then st=unreachable; elif [ "$code" != 200 ]; then st="HTTP $code"; fi ;; ' +
    '*) cat "$s" > "$t" 2>/dev/null || st="file not found" ;; ' +
    'esac; ' +
    '[ "$st" = ok ] && ! grep -q "BEGIN:VCALENDAR" "$t" && st="not a calendar"; ' +
    'echo "@@ISLAND-SOURCE $i $st"; [ "$st" = ok ] && cat "$t"; echo; rm -f "$t"; i=$((i+1)); done'

  // source link -> "ok" or what went wrong, from the last fetch.
  property var status: ({})
  // A link just added from the calendar view: report how it went.
  property string justAdded: ""

  // The outcome of the last add, shown inside the calendar view (the HUD
  // is hidden while the view is open): { ok: bool, text: string }.
  property var lastResult: null
  Timer { id: resultTimer; interval: 7000; onTriggered: calendar.lastResult = null }

  function statusOf(link) { return status[String(link)] || "" }

  Process {
    id: fetch
    stdout: StdioCollector {
      onStreamFinished: {
        var from = Date.now() - 3600000
        var map = {}
        var lines = String(text || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
          var m = /^@@ISLAND-SOURCE (\d+) (.*)$/.exec(lines[i].replace(/\r$/, ""))
          if (m && calendar.fetchedSources[+m[1]] !== undefined) map[calendar.fetchedSources[+m[1]]] = m[2]
        }
        calendar.status = map
        calendar.raw = text
        calendar.events = Model.parseIcs(text, from, from + 8 * 86400000)
        calendar.now = Date.now()
        calendar.version++
        calendar.reportAdded()
        if (calendar.refetch) {
          calendar.refetch = false
          Qt.callLater(calendar.refresh)
        }
      }
    }
  }

  function refresh() {
    if (sources.length === 0) { events = []; raw = ""; version++; return }
    // A fetch already in flight has the old list: fetch again when it ends.
    if (fetch.running) { refetch = true; return }
    // Set here rather than bound: a binding can lag the sources change that
    // triggered this refresh and fetch the old list.
    fetchedSources = sources.slice()
    fetch.command = ["bash", "-c", fetchScript, "bash"].concat(fetchedSources)
    fetch.running = true
  }

  property var fetchedSources: []
  property bool refetch: false

  function reportAdded() {
    var link = justAdded
    if (!link || !island) return
    var st = statusOf(link)
    if (!st) return
    justAdded = ""
    if (st === "ok") {
      var count = Model.parseIcs(raw, Date.now() - 30 * 86400000, Date.now() + 60 * 86400000, true).length
      lastResult = { ok: true, text: "󰄬  Calendar added · " + count + (count === 1 ? " event" : " events") + " around now" }
      resultTimer.restart()
      island.showHud({ key: "calendar", layout: "label", label: "Calendar added", icon: "󰃭",
                       valueText: count + (count === 1 ? " event" : " events"), color: island.greenColor, duration: 2600 })
    } else {
      // Google's "public address" 404s unless the calendar is public; the
      // secret address is what people almost always want.
      var google = link.indexOf("calendar.google.com") !== -1 && link.indexOf("/public/") !== -1 && st === "HTTP 404"
      lastResult = { ok: false, text: google
        ? "󰀦  Google refused the public address (404). Use \"Secret address in iCal format\"."
        : "󰀦  That link didn't work: " + st }
      resultTimer.restart()
      island.showHud({ key: "calendar", layout: "label",
                       label: google ? "Use Google's secret iCal address" : "Calendar link didn't work",
                       icon: "󰃮", valueText: google ? "404" : st, color: island.urgentColor, duration: 5000 })
    }
  }

  onSourcesChanged: refresh()

  Timer {
    interval: 15 * 60000
    repeat: true
    running: calendar.sources.length > 0
    onTriggered: calendar.refresh()
  }

  // Demo: a meeting in eight minutes.
  function demo() {
    var start = Date.now() + 8 * 60000
    events = [{ title: "Design review", start: start, end: start + 30 * 60000, allDay: false, url: "" }]
    // A little month to look at in the calendar view.
    function stamp(t) {
      var d = new Date(t)
      function p(n) { return n < 10 ? "0" + n : "" + n }
      return d.getFullYear() + p(d.getMonth() + 1) + p(d.getDate()) + "T" + p(d.getHours()) + p(d.getMinutes()) + "00"
    }
    var today = new Date()
    var d0 = new Date(today.getFullYear(), today.getMonth(), today.getDate())
    function at(days, h, m) { return d0.getTime() + days * 86400000 + (h * 60 + m) * 60000 }
    raw = [
      "BEGIN:VCALENDAR",
      "BEGIN:VEVENT", "SUMMARY:Design review", "DTSTART:" + stamp(start), "DTEND:" + stamp(start + 1800000),
      "LOCATION:https://meet.google.com/abc-defg-hij", "END:VEVENT",
      "BEGIN:VEVENT", "SUMMARY:Standup", "DTSTART:" + stamp(at(-20, 10, 0)), "DTEND:" + stamp(at(-20, 10, 15)),
      "RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR", "END:VEVENT",
      "BEGIN:VEVENT", "SUMMARY:Lunch with Priya", "DTSTART:" + stamp(at(1, 13, 0)), "DTEND:" + stamp(at(1, 14, 0)), "END:VEVENT",
      "BEGIN:VEVENT", "SUMMARY:Omarchy release", "DTSTART;VALUE=DATE:" + stamp(at(4, 0, 0)).substring(0, 8), "END:VEVENT",
      "END:VCALENDAR"
    ].join("\r\n")
    now = Date.now()
    version++
  }
}
