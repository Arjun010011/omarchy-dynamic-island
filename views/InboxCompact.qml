import QtQuick
import qs.Commons

// Unread notifications, compact: a bell on the leading edge and how many are
// waiting on the trailing edge.
Item {
  id: view

  property var island: null

  Text {
    anchors.left: parent.left
    anchors.leftMargin: island.s(13)
    anchors.verticalCenter: parent.verticalCenter
    text: "󰂚"
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: island.fontFamily
    font.pixelSize: island.f(15)
    color: island.accentColor
  }

  Rectangle {
    anchors.right: parent.right
    anchors.rightMargin: island.s(9)
    anchors.verticalCenter: parent.verticalCenter
    height: island.s(18)
    width: Math.max(height, count.implicitWidth + island.s(12))
    radius: height / 2
    color: Util.alpha(island.accentColor, 0.22)

    Text {
      id: count
      anchors.centerIn: parent
      text: island.inbox.length
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island.fontFamily
      font.pixelSize: island.f(11)
      font.bold: true
      color: island.accentColor
    }
  }
}
