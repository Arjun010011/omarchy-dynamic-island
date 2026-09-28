import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "../IslandModel.js" as Model

// Bluetooth devices connecting and disconnecting: headphones, speakers,
// keyboards, mice, controllers, phones — anything BlueZ knows about. The
// island shows the device, and its battery when the device reports one.
Item {
  id: devices

  property var island: null
  readonly property var list: Bluetooth.devices ? Bluetooth.devices.values : []

  // Devices already connected when the shell starts are not news.
  property bool ready: false
  Timer { interval: 4000; running: true; onTriggered: devices.ready = true }

  function batteryFraction(device) {
    var b = Number(device.battery)
    if (!isFinite(b)) return -1
    return b > 1 ? b / 100 : b
  }

  function announce(device) {
    if (!ready || !island || island.setting("bluetooth", true) === false) return
    var name = String(device.name || device.deviceName || "Bluetooth device")
    if (device.connected) {
      // Battery often arrives a moment after the connection; wait for it.
      pending = device
      batteryWait.restart()
    } else {
      island.showHud({
        key: "device",
        layout: "label",
        label: name,
        icon: "󰂲",
        valueText: "Disconnected",
        color: island.fgDim,
        duration: 2200
      })
    }
  }

  property var pending: null

  Timer {
    id: batteryWait
    interval: 1200
    onTriggered: {
      var device = devices.pending
      devices.pending = null
      if (!device || !device.connected) return
      var battery = device.batteryAvailable ? devices.batteryFraction(device) : -1
      island.showHud({
        key: "device",
        layout: "label",
        label: String(device.name || device.deviceName || "Bluetooth device"),
        icon: Model.deviceGlyph(device.icon),
        valueText: battery >= 0 ? Math.round(battery * 100) + "%" : "Connected",
        color: battery >= 0 && battery <= 0.2 ? island.urgentColor : island.greenColor,
        duration: 3000
      })
    }
  }

  Instantiator {
    model: devices.list
    delegate: Connections {
      required property var modelData
      target: modelData
      function onConnectedChanged() { devices.announce(modelData) }
    }
  }
}
