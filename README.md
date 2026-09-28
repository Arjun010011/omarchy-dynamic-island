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

## What it shows

| State | Looks like |
|---|---|
| Idle | A small capsule, like the camera cutout |
| Music playing | Cover art on the left, a live equalizer on the right |
| Screen recording | Pulsing record dot, `REC`, and the running time |
| Microphone in use | Mic glyph and privacy dot in the theme's warning color |
| Two at once | The second activity splits off into its own bubble |
| Volume / brightness | The island stretches into a slim level bar |
| Plugged in / low battery | `Charging 80%` or `Low Battery 10%` |
| Track change | A short now-playing card |
| Click | Expands into a full player (seekable progress, prev/play/next), or the time, date and battery when nothing is playing |

Mouse:

* **Left click**: expand or collapse. The island also closes when the pointer leaves it.
* **Middle click**: play/pause.
* **Scroll**: change the volume.

## Install

```bash
omarchy plugin add https://github.com/Arjun010011/omarchy-dynamic-island --enable
```

Or from a checkout:

```bash
./dev-install.sh
omarchy-shell shell rescanPlugins
omarchy plugin enable arjun010011.dynamic-island
```

## Settings

Add keys to the plugin's entry in `~/.config/omarchy/shell.json`. Changes apply
as soon as you save the file.

```json
"plugins": [
  { "id": "arjun010011.dynamic-island", "style": "notch", "scale": 1.1 }
]
```

| Key | Default | Meaning |
|---|---|---|
| `style` | `"island"` | `"island"` floats below the top edge; `"notch"` is attached to it like a MacBook notch |
| `background` | `"theme"` | `"theme"` uses the theme background; `"black"` is true black like the hardware island |
| `idle` | `"pill"` | `"hidden"` removes the pill when nothing is live |
| `scale` | `1` | Size multiplier (0.6–2) |
| `topMargin` | `6` | Gap above the island in `island` style |
| `reserveSpace` | `true` | Keep windows from tiling under the island |
| `monitor` | `"primary"` | `"primary"`, `"focused"`, or a monitor name like `"eDP-1"` |
| `layer` | `"top"` | `"overlay"` keeps it above fullscreen windows |
| `expandOnHover` | `false` | Open on hover instead of on click |
| `clockFormat` | `"h:mm AP"` | Qt date format for the expanded clock |
| `mediaLingerSeconds` | `30` | How long a paused track stays in the island |
| `volume`, `brightness`, `charging`, `trackChange`, `recording`, `mic` | `true` | Turn individual activities off |

Omarchy's own OSD also shows volume and brightness at the bottom of the
screen. If seeing both is too much, set `"volume": false, "brightness": false`
here to leave those to the OSD.

## Scripting

```bash
omarchy-shell dynamic-island toast "Build finished" "0 errors" "󰄬" green
omarchy-shell dynamic-island toggle        # bind it to a key in hyprland.conf
omarchy-shell dynamic-island state         # JSON snapshot
omarchy-shell dynamic-island demo media    # preview: media paused split recording mic
                                           # volume brightness charging lowbattery
                                           # track toast expanded idle-expanded off
```

A toast's color can be `accent`, `green`, `orange`, `red`, `foreground` or a hex
value.

For example, to have a long command tell you when it's done:

```bash
make && omarchy-shell dynamic-island toast "make" "done" "󰄬" green \
     || omarchy-shell dynamic-island toast "make" "failed" "󰅚" red
```

## Development

`dev-install.sh` copies the working tree into
`~/.config/omarchy/plugins/arjun010011.dynamic-island` and validates it. The
shell does not always pick up a changed entry file for a keep-loaded panel on
hot reload, so run `omarchy restart shell` after editing `Island.qml`.

Files:

* `Island.qml`: state machine, data sources, window and IPC
* `IslandModel.js`: pure logic (sizes, priorities, formatting, player choice)
* `views/`: one file per island state, plus shared pieces

## License

MIT
