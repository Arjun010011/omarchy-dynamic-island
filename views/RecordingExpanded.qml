import QtQuick
import qs.Commons
import "../IslandModel.js" as Model

// Opened while recording: the recording, with a stop button, on top; and if
// music is also playing, a compact player underneath so neither is hidden.
Item {
  id: view

  property var island: null
  readonly property int pad: island.s(18)

  // --- recording row ------------------------------------------------------
  Item {
    id: recordingRow
    x: view.pad
    y: view.pad
    width: parent.width - view.pad * 2
    height: island.s(40)

    RecordDot {
      id: dot
      anchors.left: parent.left
      anchors.leftMargin: island.s(4)
      anchors.verticalCenter: parent.verticalCenter
      size: island.s(12)
      color: island.urgentColor
    }

    Column {
      anchors.left: dot.right
      anchors.leftMargin: island.s(12)
      anchors.verticalCenter: parent.verticalCenter
      spacing: island.s(1)

      Text {
        text: "Screen Recording"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island.textFamily
        font.pixelSize: island.f(14)
        font.weight: Font.DemiBold
        color: island.fg
      }

      Text {
        text: Model.formatTime(island.recordingElapsed)
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island.fontFamily
        font.pixelSize: island.f(12)
        font.features: { "tnum": 1 }
        color: island.urgentColor
      }
    }

    Rectangle {
      id: stop
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      height: island.s(32)
      width: stopLabel.implicitWidth + island.s(30)
      radius: height / 2
      color: stopMouse.pressed ? Util.alpha(island.urgentColor, 0.95)
        : (stopMouse.containsMouse ? Util.alpha(island.urgentColor, 0.85) : island.urgentColor)
      scale: stopMouse.pressed ? 0.94 : 1

      Behavior on scale { NumberAnimation { duration: 120 } }

      Text {
        id: stopLabel
        anchors.centerIn: parent
        text: "󰓛  Stop"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island.textFamily
        font.pixelSize: island.f(13)
        font.weight: Font.DemiBold
        color: island.surface
      }

      MouseArea {
        id: stopMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: island.stopRecording()
      }
    }
  }

  // --- media strip (only when something is also playing) ------------------
  Rectangle {
    id: divider
    visible: island.hasMedia
    x: view.pad
    y: recordingRow.y + recordingRow.height + island.s(12)
    width: parent.width - view.pad * 2
    height: 1
    color: Util.alpha(island.fg, 0.1)
  }

  Item {
    visible: island.hasMedia
    x: view.pad
    y: divider.y + divider.height + island.s(12)
    width: parent.width - view.pad * 2
    height: island.s(44)

    AlbumArt {
      id: art
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: island.s(44)
      height: width
      source: island.mediaArt
      tint: island.accentColor
      fontFamily: island.fontFamily
    }

    Row {
      id: controls
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: island.s(2)

      IconButton {
        glyph: "󰒮"
        glyphSize: island.f(17)
        color: island.fg
        fontFamily: island.fontFamily
        available: island.mediaCanPrevious
        onClicked: island.mediaPrevious()
      }

      IconButton {
        glyph: island.mediaPlaying ? "󰏤" : "󰐊"
        glyphSize: island.f(21)
        color: island.fg
        fontFamily: island.fontFamily
        onClicked: island.mediaToggle()
      }

      IconButton {
        glyph: "󰒭"
        glyphSize: island.f(17)
        color: island.fg
        fontFamily: island.fontFamily
        available: island.mediaCanNext
        onClicked: island.mediaNext()
      }
    }

    Column {
      anchors.left: art.right
      anchors.leftMargin: island.s(12)
      anchors.right: controls.left
      anchors.rightMargin: island.s(8)
      anchors.verticalCenter: parent.verticalCenter
      spacing: island.s(2)

      Text {
        width: parent.width
        text: island.mediaTitle
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        elide: Text.ElideRight
        font.family: island.textFamily
        font.pixelSize: island.f(13)
        font.weight: Font.DemiBold
        color: island.fg
      }

      Text {
        width: parent.width
        visible: text !== ""
        text: island.mediaArtist
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        elide: Text.ElideRight
        font.family: island.textFamily
        font.pixelSize: island.f(11)
        color: island.fgDim
      }
    }
  }
}
