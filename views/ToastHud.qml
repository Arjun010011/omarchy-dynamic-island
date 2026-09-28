import QtQuick
import qs.Commons

// A custom message pushed over IPC (build finished, agent done, ...).
Item {
  id: view

  property var island: null
  readonly property var hud: island.hud || ({})
  readonly property color tone: hud.color || island.accentColor

  Rectangle {
    id: badge
    anchors.left: parent.left
    anchors.leftMargin: island.s(11)
    anchors.verticalCenter: parent.verticalCenter
    width: island.s(44)
    height: width
    radius: width / 2
    color: Util.alpha(view.tone, 0.2)

    Text {
      anchors.centerIn: parent
      text: view.hud.icon || "󰂚"
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island.fontFamily
      font.pixelSize: island.f(20)
      color: view.tone
    }
  }

  Column {
    anchors.left: badge.right
    anchors.leftMargin: island.s(12)
    anchors.right: parent.right
    anchors.rightMargin: island.s(22)
    anchors.verticalCenter: parent.verticalCenter
    spacing: island.s(2)

    Text {
      width: parent.width
      text: view.hud.title || ""
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      elide: Text.ElideRight
      font.family: island.textFamily
      font.pixelSize: island.f(14)
      font.weight: Font.DemiBold
      color: island.fg
    }

    Text {
      width: parent.width
      visible: text !== ""
      text: view.hud.body || ""
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      elide: Text.ElideRight
      font.family: island.textFamily
      font.pixelSize: island.f(12)
      color: island.fgDim
    }
  }
}
