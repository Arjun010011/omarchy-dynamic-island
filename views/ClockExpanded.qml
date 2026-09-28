import QtQuick
import qs.Commons
import "../IslandModel.js" as Model

// Opened timer / stopwatch: the time large, and its controls. A running
// timer shows its label and a bar of how much is gone.
Item {
  id: view

  property var island: null
  readonly property var clocks: island.clocks
  readonly property bool timer: clocks.timerActive
  readonly property bool paused: timer ? clocks.timerPaused : !clocks.stopwatchRunning
  readonly property color tone: paused ? island.fgDim : (timer ? island.orangeColor : island.accentColor)
  readonly property int pad: island.s(24)

  Column {
    x: view.pad
    anchors.verticalCenter: parent.verticalCenter
    spacing: island.s(2)

    Text {
      text: view.timer ? (view.clocks.timerLabel || "Timer") : "Stopwatch"
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island.fontFamily
      font.pixelSize: island.f(12)
      color: island.fgDim
    }

    Text {
      text: view.timer ? Model.formatClock(Math.ceil(view.clocks.timerLeft / 1000))
        : Model.formatClock(view.clocks.stopwatchElapsed / 1000, true)
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island.fontFamily
      font.pixelSize: island.f(34)
      font.bold: true
      font.features: { "tnum": 1 }
      color: view.tone
    }

    Rectangle {
      visible: view.timer
      width: island.s(170)
      height: island.s(4)
      radius: height / 2
      color: Util.alpha(island.fg, 0.14)

      Rectangle {
        height: parent.height
        radius: height / 2
        width: parent.width * view.clocks.timerProgress
        color: view.tone
      }
    }
  }

  Row {
    anchors.right: parent.right
    anchors.rightMargin: view.pad - island.s(6)
    anchors.verticalCenter: parent.verticalCenter
    spacing: island.s(8)

    // +1 min (timer) / reset (stopwatch)
    IconButton {
      glyph: view.timer ? "󰐕" : "󰑓"
      glyphSize: island.f(18)
      color: island.fg
      fontFamily: island.fontFamily
      onClicked: view.timer ? view.clocks.addToTimer(60) : view.clocks.resetStopwatch()
    }

    // Pause / resume, in the activity's color like iOS.
    Rectangle {
      width: island.s(46)
      height: width
      radius: width / 2
      color: Util.alpha(view.timer ? island.orangeColor : island.accentColor, pp.pressed ? 0.4 : 0.26)
      scale: pp.pressed ? 0.92 : 1

      Behavior on scale { NumberAnimation { duration: 120 } }

      Text {
        anchors.centerIn: parent
        text: view.paused ? "󰐊" : "󰏤"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island.fontFamily
        font.pixelSize: island.f(20)
        color: view.timer ? island.orangeColor : island.accentColor
      }

      MouseArea {
        id: pp
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: view.timer ? view.clocks.toggleTimer() : view.clocks.toggleStopwatch()
      }
    }

    // Cancel
    IconButton {
      glyph: "󰅖"
      glyphSize: island.f(18)
      color: island.fg
      fontFamily: island.fontFamily
      onClicked: {
        if (view.timer) view.clocks.cancelTimer()
        else view.clocks.resetStopwatch()
        island.collapse()
      }
    }
  }
}
