import QtQuick

// Status HUD in the iOS "Charging ····· 80% ▮" shape: a label on the leading
// edge, a value and glyph on the trailing edge, both in the event's color.
Item {
  id: view

  property var island: null
  readonly property var hud: island.hud || ({})
  readonly property color tone: hud.color || island.fg

  Text {
    anchors.left: parent.left
    anchors.leftMargin: island.s(16)
    anchors.right: trailing.left
    anchors.rightMargin: island.s(10)
    anchors.verticalCenter: parent.verticalCenter
    text: view.hud.label || ""
    textFormat: Text.PlainText
    elide: Text.ElideRight
    font.family: island.fontFamily
    font.pixelSize: island.f(13)
    font.bold: true
    color: island.fg
  }

  Row {
    id: trailing
    anchors.right: parent.right
    anchors.rightMargin: island.s(14)
    anchors.verticalCenter: parent.verticalCenter
    spacing: island.s(6)

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: view.hud.valueText || ""
      textFormat: Text.PlainText
      font.family: island.fontFamily
      font.pixelSize: island.f(13)
      font.bold: true
      font.features: { "tnum": 1 }
      color: view.tone
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: view.hud.icon || ""
      textFormat: Text.PlainText
      font.family: island.fontFamily
      font.pixelSize: island.f(18)
      color: view.tone
    }
  }
}
