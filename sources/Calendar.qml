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
  readonly property var sources: {
    var v = island ? island.setting("calendars", []) : []
    return Array.isArray(v) ? v.map(function(x) { return String(x) }) : (v ? [String(v)] : [])
  }
  readonly property int leadMinutes: island ? Math.max(1, Number(island.setting("calendarLeadMinutes", 15)) || 15) : 15

  property var events: []
  property double now: Date.now()

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
  readonly property string fetchScript:
    'for u in "$@"; do u="${u/#\\~/$HOME}"; case "$u" in ' +
    'http://*|https://*) curl -fsSL --max-time 20 "$u" ;; webcal://*) curl -fsSL --max-time 20 "https://${u#webcal://}" ;; ' +
    '*) cat "$u" ;; esac; echo; done 2>/dev/null'

  Process {
    id: fetch
    stdout: StdioCollector {
      onStreamFinished: {
        var from = Date.now() - 3600000
        calendar.events = Model.parseIcs(text, from, from + 8 * 86400000)
        calendar.now = Date.now()
      }
    }
  }

  function refresh() {
    if (sources.length === 0) { events = []; return }
    if (fetch.running) return
    // Set here rather than bound: a binding can lag the sources change that
    // triggered this refresh and fetch the old list.
    fetch.command = ["bash", "-c", fetchScript, "bash"].concat(sources)
    fetch.running = true
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
    events = [{ title: "Design review", start: start, end: start + 30 * 60000, allDay: false }]
    now = Date.now()
  }
}
