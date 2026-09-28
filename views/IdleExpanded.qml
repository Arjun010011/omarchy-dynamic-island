import QtQuick
import Quickshell
import "../IslandModel.js" as Model

// What the island opens into when nothing is live: the time, the date, and
// the battery.
Item {
  id: view

  property var island: null

  SystemClock {
    id: clock
    precision: SystemClock.Seconds
  }

  Column {
    anchors.left: parent.left
    anchors.leftMargin: island.s(28)
    anchors.verticalCenter: parent.verticalCenter
    spacing: island.s(1)

    Text {
      text: Qt.formatDateTime(clock.date, island.clockFormat)
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island.fontFamily
      font.pixelSize: island.f(30)
      font.bold: true
      font.features: { "tnum": 1 }
      color: island.fg
    }

    Text {
      text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island.fontFamily
      font.pixelSize: island.f(12)
      color: island.fgDim
    }
  }

  Column {
    anchors.right: parent.right
    anchors.rightMargin: island.s(28)
    anchors.verticalCenter: parent.verticalCenter
    spacing: island.s(2)
    visible: island.hasBattery

    Text {
      anchors.right: parent.right
      text: Model.batteryIcon(island.batteryLevel, island.charging)
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island.fontFamily
      font.pixelSize: island.f(26)
      color: island.charging ? island.greenColor
        : (island.batteryLevel <= 0.2 ? island.urgentColor : island.fg)
    }

    Text {
      anchors.right: parent.right
      text: Model.percentText(island.batteryLevel) + (island.charging ? " · charging" : "")
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island.fontFamily
      font.pixelSize: island.f(11)
      font.features: { "tnum": 1 }
      color: island.fgDim
    }
  }
}
