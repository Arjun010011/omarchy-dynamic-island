import QtQuick
import "../IslandModel.js" as Model

// Screen recording, compact: a pulsing record dot and the running time.
Item {
  id: view

  property var island: null

  Row {
    anchors.left: parent.left
    anchors.leftMargin: island.s(12)
    anchors.verticalCenter: parent.verticalCenter
    spacing: island.s(7)

    RecordDot {
      anchors.verticalCenter: parent.verticalCenter
      size: island.s(10)
      color: island.urgentColor
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: "REC"
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island.fontFamily
      font.pixelSize: island.f(11)
      font.bold: true
      font.letterSpacing: 0.6
      color: island.urgentColor
    }
  }

  Text {
    anchors.right: parent.right
    anchors.rightMargin: island.s(13)
    anchors.verticalCenter: parent.verticalCenter
    text: Model.formatTime(island.recordingElapsed)
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: island.fontFamily
    font.pixelSize: island.f(13)
    font.bold: true
    font.features: { "tnum": 1 }
    color: island.urgentColor
  }
}
