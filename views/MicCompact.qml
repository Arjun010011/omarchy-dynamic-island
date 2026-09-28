import QtQuick

// Something is listening to a microphone: glyph on the leading edge, the
// privacy dot on the trailing edge, both in the theme's warning color.
Item {
  id: view

  property var island: null

  Text {
    anchors.left: parent.left
    anchors.leftMargin: island.s(13)
    anchors.verticalCenter: parent.verticalCenter
    text: "󰍬"
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: island.fontFamily
    font.pixelSize: island.f(15)
    color: island.orangeColor
  }

  RecordDot {
    anchors.right: parent.right
    anchors.rightMargin: island.s(14)
    anchors.verticalCenter: parent.verticalCenter
    size: island.s(8)
    color: island.orangeColor
    pulsing: false
  }
}
