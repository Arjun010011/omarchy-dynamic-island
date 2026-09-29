# Dynamic Island for Omarchy

An Apple-style Dynamic Island for [Omarchy](https://omarchy.org). A pill sits at
the top of the screen and springs open into live activities: now playing,
screen recording, microphone in use, volume, brightness, charging, and custom
messages. It is drawn in your current Omarchy theme's colors and font, and
re-colors itself when you switch themes.

It is a native Omarchy shell plugin (Quickshell QML running inside
`omarchy-shell`), so it adds no extra process, and every data source is live:
MPRIS, PipeWire and UPower through Quickshell's services, sysfs for the
backlight, and `gpu-screen-recorder` for recording.

![The island's states: player, notifications, inbox, calendar, recording, timer, script activity, output picker, and the resting pills](assets/overview.webp)

## What it shows

| State | Looks like |
|---|---|
| Idle | A glance ticker: every few seconds the next of the time, date, battery, next meeting, today's festival or "Silenced" flips in like a split-flap board, and the pill resizes to fit |
| Music playing | Cover art on the left, the song and artist scrolling through the middle, a live equalizer on the right. When paused it stays on the same player, with the text stopped and dimmed |
| Screen recording | Pulsing record dot, `REC`, and the running time |
| Microphone / camera in use | Mic glyph and an orange dot; for the camera, a camera glyph and a green dot |
| Timer | A ring that fills as time runs out, and the time left. At zero a message and an alarm sound |
| Stopwatch | The running time. It keeps going across restarts |
| Next meeting | 15 minutes before an event: the title scrolling past and a countdown, then a "Starting now" message |
| Script activities | Any script can put a live activity in the island: glyph, progress ring, value, title |
| Bluetooth devices | Headphones, speakers, keyboards, mice, controllers: the device's name and battery when it connects, and a message when it disconnects |
| Two at once | The second activity splits off into its own bubble. Click the bubble to open that one |
| Play on | The speaker button in the player lists every audio output (speakers, headphones, Bluetooth, HDMI) to switch to |
| Volume / brightness | The island stretches into a slim level bar |
| Plugged in / low battery | `Charging 80%` or `Low Battery 10%` |
| Track change | A short now-playing card |
| Click (idle) | The time, date, next meeting and battery, plus one-tap 5, 15 and 25 minute timers and a stopwatch |
| Click | Expands into a full player (seekable progress, prev/play/next). While recording it shows the recording with a Stop button, with the player underneath if music is on. With nothing live it shows the time, date and battery |

Mouse:

* **Left click**: expand or collapse. The island also closes when the pointer leaves it.
* **Middle click**: play/pause.
* **Scroll**: change the volume.

| | | |
|---|---|---|
| ![The full player, washed in the album cover](assets/player.webp) | ![Clicking the resting island: time, battery and one-tap timers](assets/quick-actions.webp) | ![A script reporting build progress in the island](assets/live-activity.webp) |
| The full player | Quick timers and a stopwatch | Live progress from your own scripts |

## Look

The island is drawn as a piece of dark glass in your theme's colors: a body
shaded slightly from top to bottom with a hairline rim, words set in iA
Writer Quattro (Omarchy ships it) with numbers and icons in your theme's
monospace. A thin light along its lower edge shows what it's doing: a faint
accent line when idle, pulsing in the music's color while something plays,
draining orange as a timer runs down, red while recording, filling as a
script reports progress, and a bead of light running across when a
notification arrives or the charger goes in. The expanded player shows a
soft wash of the album cover behind it.

## Notifications

The island is also your notification daemon. On first run it disables
Omarchy's own `omarchy.notifications` service (only one program can receive
notifications), and it answers the same `omarchy-shell notifications ...`
commands, so Omarchy's keybinds and scripts keep working:

| | |
|---|---|
| ![A notification banner with Reply and Mark as Read buttons](assets/notification.webp) | ![The inbox with three missed notifications and Clear all](assets/inbox.webp) |
| A notification with its actions | Everything you missed, in the inbox |

* **New notification**: it drops out of the island as a banner with the app
  icon, title and body, plus the sender's buttons if it has any. Hovering
  keeps it up.
* **Click a notification**: runs the sender's action and focuses the app's
  window. Right-click or the × clears it without opening it.
* **Not clicked**: when the banner's time runs out the notification is not
  lost. It waits in the inbox, shown as a bell with a count, in the pill or as
  a bubble next to what's playing. The inbox survives shell restarts.
* **Inbox**: click the bell (or press `SUPER+SHIFT+ALT+,`) to see everything
  waiting. Click a row to open that app, × on a row to clear it, or
  **× Clear all** at the bottom.
* **Do not disturb** (`SUPER+CTRL+,`): nothing pops up, and everything still
  goes to the inbox.
* `SUPER+,` clears the newest, `SUPER+SHIFT+,` clears everything,
  `SUPER+ALT+,` opens the newest.

Omarchy's own quick feedback toasts ("Theme changed" and similar) show as
banners but don't pile up in the inbox.

To go back to Omarchy's notifications, set `"notifications": false` in the
island's settings. Disabling or removing the plugin also hands
notifications back automatically.

## Install

```bash
omarchy plugin add https://github.com/Arjun010011/omarchy-dynamic-island --enable
```

Or from a checkout:

```bash
./dev-install.sh
omarchy-shell shell rescanPlugins
omarchy plugin enable omarchy-dynamic-island
```

## Settings

Settings live in the plugin's entry in `~/.config/omarchy/shell.json`. On
first start the island fills that entry with every setting below at its
default, so you only change values; any you set yourself are kept. Changes
apply as soon as you save the file.

```json
"plugins": [
  { "id": "omarchy-dynamic-island", "style": "notch", "scale": 1.1 }
]
```

| Key | Default | Meaning |
|---|---|---|
| `style` | `"island"` | `"island"` floats below the top edge; `"notch"` is attached to it like a MacBook notch |
| `background` | `"theme"` | `"theme"` uses the theme background; `"black"` is true black like the hardware island |
| `idle` | `"pill"` | `"hidden"` removes the pill when nothing is live |
| `idleFace` | `"ticker"` | What the resting pill shows: `"ticker"`, `"clock"`, `"lens"` (a camera lens, like the hardware island) or `"none"` |
| `scale` | `1` | Size multiplier (0.6–2) |
| `topMargin` | `6` | Gap above the island in `island` style |
| `reserveSpace` | `true` | Keep a strip free across the top for the island. `false` lets windows fill the top of the screen and the island/notch sits over them, so no empty band is left beside it |
| `keybind` | `"SUPER + ALT + I"` | Key that toggles `reserveSpace`. The island adds it to `~/.config/hypr/bindings.lua` (skipped if the key is already taken) and removes it on uninstall; `false` for none |
| `monitor` | `"primary"` | `"primary"`, `"focused"`, or a monitor name like `"eDP-1"` |
| `layer` | `"top"` | `"overlay"` keeps it above fullscreen windows |
| `expandOnHover` | `false` | Open on hover instead of on click |
| `clockFormat` | `"h:mm AP"` | Qt date format for the expanded clock |
| `mediaLingerSeconds` | `30` | How long a paused track stays in the island |
| `notchWidth`, `notchHeight`, `notchRadius` | `0` | Fit a real display cutout: see below |
| `visualizerColor` | `"accent"` | `"artwork"` colors the equalizer and glow from the album cover |
| `textFont` | `"iA Writer Quattro V"` | Font for words; `"theme"` uses your theme font everywhere |
| `glow` | `false` | Soft light behind the island in the music's color |
| `calendars` | `[]` | iCalendar links or files for the next-meeting activity, e.g. `["https://…/basic.ics", "~/cal.ics"]` |
| `calendarLeadMinutes` | `15` | How early a meeting appears |
| `holidays` | `"auto"` | Public holidays: `"auto"` (from the timezone), `"off"`, or a country code |
| `timerSound` | `true` | Play the alarm sound when a timer ends |
| `bluetooth`, `camera`, `calendar` | `true` | Turn those activities off |
| `notifications` | `true` | Show notifications in the island (replaces Omarchy's notification popups) |
| `inbox` | `true` | Show the bell for notifications waiting in the inbox |
| `osd` | `true` | Show Omarchy's on-screen popups (volume, brightness, mic, …) in the island instead of at the bottom |
| `volume`, `brightness`, `charging`, `trackChange`, `recording`, `mic` | `true` | Turn individual activities off |

The island also replaces Omarchy's on-screen display: the popups at the
bottom of the screen for volume, brightness, microphone mute, keyboard
backlight, audio output, touchpad, power actions and downloads. It turns off
Omarchy's `omarchy.osd` plugin and answers the same `omarchy osd` calls, so
every key and script that popped the OSD now shows in the island. Set
`"osd": false` to go back to Omarchy's popups.

## Uninstalling

Disabling or removing the plugin gives back everything it took over: Omarchy's
notifications and on-screen display are switched back on, and its keybinding
is removed from `bindings.lua`. The plugin checks a
few seconds after it unloads, so a shell restart doesn't trigger this.

## Calendar

Open it by clicking the island when nothing is playing and then the date
(or the 󰃭 button), by clicking a meeting in the island, or with
`omarchy-shell dynamic-island calendar` (bind it to a key if you like).

![The calendar: a month view with event dots and the selected day's meetings](assets/calendar.webp)

It shows the month with today highlighted and a dot on every day that has
something on it; click a day to see its events, and click an event to open
its meeting link (Meet, Zoom, Teams). Press **+** to paste a calendar link (they are kept in
`~/.config/omarchy/dynamic-island/calendars.json`);
each added calendar has an × to remove it. Scripts can do the same with
`omarchy-shell dynamic-island addCalendar <link>` / `removeCalendar <link>`.

**Holidays** are on out of the box: the island picks your country from the
system timezone and shows its public holidays and festivals (from Google's
holiday calendars) as all-day entries, with today's festival next to the
date. In the calendar's **+** panel, tap **Holidays** to choose another
country (24 are available) or turn them off. The `"holidays"` setting does the
same: `"auto"`, `"off"`, or a country code like `"IN"`.

Any calendar that can give you an `.ics` link works:

* **Google Calendar**: Settings → your calendar → Integrate calendar → **"Secret
  address in iCal format"**. The "Public address" only works if the calendar
  is public (otherwise Google answers 404). Each calendar, and each Google
  account (personal, work), has its own secret address. Google refreshes these
  feeds on its own schedule, so a brand-new event can take a few hours to appear
* **iCloud**: share the calendar as a public calendar (a `webcal://` link works)
* **Outlook**: Settings → Shared calendars → Publish a calendar → ICS link
* **Nextcloud and Fastmail**: the calendar's export or subscription link

Local `.ics` files also work. Feeds are re-read every 15 minutes. Daily,
weekly, monthly and yearly repeats (birthdays) are understood; times with a
time zone are read as local time. The island takes keyboard input only while
the link field is open.

## MacBook notch

On a MacBook with a notch, use `"style": "notch"` and set the island to the
size of the notch so it looks like the notch itself coming alive:

```json
{ "id": "omarchy-dynamic-island", "style": "notch",
  "background": "black", "notchWidth": 200, "notchHeight": 32, "notchRadius": 10 }
```

`notchWidth` and `notchHeight` are in the same pixels as the rest of the
island. Adjust them until the idle island exactly covers the cutout; the
settings apply as soon as you save. Live activities then grow out to both
sides of the camera, like on an iPhone. This hasn't been tried on Apple
Silicon hardware yet. If your notch area is hidden by the kernel (the
default on Asahi Linux), the island simply sits in the black band there.

## Scripting

```bash
omarchy-shell dynamic-island toast "Build finished" "0 errors" "󰄬" green
omarchy-shell dynamic-island toggle        # bind it to a key in hyprland.conf
omarchy-shell dynamic-island reserveSpace toggle   # on | off | toggle: windows below the island or under it
omarchy-shell dynamic-island state         # JSON snapshot
omarchy-shell dynamic-island demo media    # preview: media paused split recording mic recording-expanded
                                           # volume brightness charging lowbattery notification
                                           # notification-actions inbox
                                           # track toast expanded idle-expanded timer stopwatch
                                           # activity calendar camera device outputs off
```

Timers, the stopwatch, and live activities for your own scripts:

```bash
omarchy-shell dynamic-island timer 25m "Focus"     # also 90s, 1h30m, 10:00, or plain minutes
omarchy-shell dynamic-island timerToggle           # pause / resume
omarchy-shell dynamic-island timerCancel
omarchy-shell dynamic-island stopwatch toggle      # start | pause | toggle | reset

# Start or update a live activity (all fields optional):
omarchy-shell dynamic-island activity backup \
  '{"title":"Backing up","subtitle":"~/Projects","icon":"󰁯","progress":0.4,"value":"4/10","color":"green","ttl":600}'
# End it, optionally with a closing message:
omarchy-shell dynamic-island endActivity backup "Backup complete"
```

`ttl` (seconds) ends an activity by itself if the script dies without ending
it.

A toast's color can be `accent`, `green`, `orange`, `red`, `foreground` or a hex
value.

For example, to have a long command tell you when it's done:

```bash
make && omarchy-shell dynamic-island toast "make" "done" "󰄬" green \
     || omarchy-shell dynamic-island toast "make" "failed" "󰅚" red
```

## Development

`dev-install.sh` copies the working tree into
`~/.config/omarchy/plugins/omarchy-dynamic-island` and validates it. The
shell does not always pick up a changed entry file for a keep-loaded panel on
hot reload, so run `omarchy restart shell` after editing `Island.qml`.

Files:

* `Island.qml`: state machine, data sources, window and IPC
* `IslandModel.js`: pure logic (sizes, priorities, formatting, player choice)
* `views/`: one file per island state, plus shared pieces

## License

MIT
