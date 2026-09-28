import QtQuick
import "../IslandModel.js" as Model

// Timer or stopwatch, compact. The timer's glyph sits in a ring that fills
// as time runs out; the time itself hugs the trailing edge.
Item {
  id: view

  property var island: null
  property string mode: "timer"
  readonly property var clocks: island.clocks
  readonly property bool timer: mode === "timer"
  readonly property bool paused: timer ? clocks.timerPaused : !clocks.stopwatchRunning
  readonly property color tone: paused ? island.fgDim : (timer ? island.orangeColor : island.accentColor)

  Item {
    anchors.left: parent.left
    anchors.leftMargin: island.s(6)
    anchors.verticalCenter: parent.verticalCenter
    width: island.s(22)
    height: width

    ProgressRing {
      anchors.fill: parent
      visible: view.timer
      progress: view.clocks.timerProgress
      color: view.tone
      lineWidth: island.s(2)
    }

    Text {
      anchors.centerIn: parent
      text: view.timer ? (view.paused ? "󰏤" : "󰔛") : "󱎫"
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island.fontFamily
      font.pixelSize: view.timer ? island.f(11) : island.f(15)
      color: view.tone
    }
  }

  Text {
    anchors.right: parent.right
    anchors.rightMargin: island.s(14)
    anchors.verticalCenter: parent.verticalCenter
    text: view.timer ? Model.formatClock(Math.ceil(view.clocks.timerLeft / 1000))
      : Model.formatClock(view.clocks.stopwatchElapsed / 1000, false)
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: island.fontFamily
    font.pixelSize: island.f(13)
    font.bold: true
    font.features: { "tnum": 1 }
    color: view.tone
  }
}
