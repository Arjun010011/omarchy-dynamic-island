import QtQuick
import qs.Commons

// "Play on": every audio output PipeWire knows about (speakers, headphones,
// Bluetooth, HDMI). Click one to move sound there.
Item {
  id: view

  property var island: null
  readonly property int pad: island.s(16)

  Item {
    id: header
    x: view.pad
    y: view.pad
    width: parent.width - view.pad * 2
    height: island.s(22)

    IconButton {
      id: back
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      glyph: "󰁍"
      glyphSize: island.f(13)
      color: island.fg
      fontFamily: island.fontFamily
      onClicked: island.closeOutputs()
    }

    Text {
      anchors.left: back.right
      anchors.leftMargin: island.s(6)
      anchors.verticalCenter: parent.verticalCenter
      text: "Play on"
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island.fontFamily
      font.pixelSize: island.f(13)
      font.bold: true
      color: island.fg
    }
  }

  Column {
    x: view.pad
    y: header.y + header.height + island.s(8)
    width: parent.width - view.pad * 2
    spacing: island.s(4)

    Repeater {
      model: island.audioOutputs

      Rectangle {
        id: row
        required property var modelData
        readonly property bool current: !!island.sink && island.sink.id === modelData.id
        width: parent.width
        height: island.s(40)
        radius: island.s(14)
        color: row.current ? Util.alpha(island.accentColor, 0.18)
          : Util.alpha(island.fg, rowMouse.containsMouse ? 0.1 : 0.04)

        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
          id: glyph
          anchors.left: parent.left
          anchors.leftMargin: island.s(12)
          anchors.verticalCenter: parent.verticalCenter
          text: island.outputGlyph(row.modelData)
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: island.fontFamily
          font.pixelSize: island.f(16)
          color: row.current ? island.accentColor : island.fg
        }

        Text {
          anchors.left: glyph.right
          anchors.leftMargin: island.s(12)
          anchors.right: check.left
          anchors.rightMargin: island.s(8)
          anchors.verticalCenter: parent.verticalCenter
          text: island.outputLabel(row.modelData)
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          elide: Text.ElideRight
          font.family: island.fontFamily
          font.pixelSize: island.f(12)
          font.bold: row.current
          color: island.fg
        }

        Text {
          id: check
          anchors.right: parent.right
          anchors.rightMargin: island.s(14)
          anchors.verticalCenter: parent.verticalCenter
          visible: row.current
          text: "󰄬"
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: island.fontFamily
          font.pixelSize: island.f(14)
          color: island.accentColor
        }

        MouseArea {
          id: rowMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: island.selectOutput(row.modelData)
        }
      }
    }
  }
}
