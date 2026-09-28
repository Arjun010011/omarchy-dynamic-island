import QtQuick
import Quickshell
import qs.Commons
import "../IslandModel.js" as Model

// What the island opens into when nothing is live: the time, the date, the
// next meeting, the battery, and one-tap timers and a stopwatch.
Item {
  id: view

  property var island: null
  readonly property int pad: island.s(26)
  readonly property var nextEvent: island.calendar.next

  SystemClock {
    id: clock
    precision: SystemClock.Seconds
  }

  Column {
    x: view.pad
    y: island.s(18)
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

    // The date (or next meeting) opens the calendar.
    Text {
      id: dateLine
      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: island.openCalendar()
        onContainsMouseChanged: dateLine.font.underline = containsMouse
      }
      text: view.nextEvent
        ? "󰃭  " + view.nextEvent.title + "  ·  " + Qt.formatDateTime(new Date(view.nextEvent.start), island.clockFormat.indexOf("AP") !== -1 ? "h:mm AP" : "HH:mm")
        : Qt.formatDateTime(clock.date, "dddd, d MMMM")
      width: island.s(240)
      elide: Text.ElideRight
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island.fontFamily
      font.pixelSize: island.f(12)
      color: view.nextEvent ? island.accentColor : island.fgDim
    }
  }

  Column {
    anchors.right: parent.right
    anchors.rightMargin: view.pad
    y: island.s(20)
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

  // One-tap timers and the stopwatch.
  Row {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: island.s(16)
    spacing: island.s(8)

    Repeater {
      model: [
        { label: "5 min", glyph: "󰔛", seconds: 300 },
        { label: "15 min", glyph: "󰔛", seconds: 900 },
        { label: "25 min", glyph: "󰔛", seconds: 1500 },
        { label: "Stopwatch", glyph: "󱎫", seconds: 0 },
        { label: "", glyph: "󰃭", seconds: -1 }
      ]

      Rectangle {
        id: chip
        required property var modelData
        height: island.s(30)
        width: chipLabel.implicitWidth + island.s(22)
        radius: height / 2
        color: Util.alpha(chip.modelData.seconds > 0 ? island.orangeColor : island.accentColor,
                          chipMouse.pressed ? 0.3 : (chipMouse.containsMouse ? 0.22 : 0.14))
        scale: chipMouse.pressed ? 0.94 : 1

        Behavior on scale { NumberAnimation { duration: 120 } }
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
          id: chipLabel
          anchors.centerIn: parent
          text: chip.modelData.label ? chip.modelData.glyph + " " + chip.modelData.label : chip.modelData.glyph
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: island.fontFamily
          font.pixelSize: island.f(12)
          font.bold: true
          color: chip.modelData.seconds > 0 ? island.orangeColor : island.accentColor
        }

        MouseArea {
          id: chipMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (chip.modelData.seconds < 0) { island.openCalendar(); return }
            if (chip.modelData.seconds > 0) island.clocks.startTimer(chip.modelData.seconds, "")
            else island.clocks.toggleStopwatch()
            island.collapse()
          }
        }
      }
    }
  }
}
