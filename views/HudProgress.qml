import QtQuick
import qs.Commons

// Volume / brightness: glyph, a slim level bar, and the percentage.
Item {
  id: view

  property var island: null
  readonly property var hud: island.hud || ({})
  readonly property real value: Math.max(0, Math.min(1, Number(hud.value) || 0))

  Text {
    id: glyph
    anchors.left: parent.left
    anchors.leftMargin: island.s(14)
    anchors.verticalCenter: parent.verticalCenter
    width: island.s(20)
    horizontalAlignment: Text.AlignHCenter
    text: view.hud.icon || ""
    textFormat: Text.PlainText
    font.family: island.fontFamily
    font.pixelSize: island.f(16)
    color: island.fg
  }

  Text {
    id: readout
    anchors.right: parent.right
    anchors.rightMargin: island.s(15)
    anchors.verticalCenter: parent.verticalCenter
    width: island.s(42)
    horizontalAlignment: Text.AlignRight
    text: view.hud.valueText || ""
    textFormat: Text.PlainText
    font.family: island.fontFamily
    font.pixelSize: island.f(12)
    font.bold: true
    font.features: { "tnum": 1 }
    color: island.fg
  }

  Rectangle {
    anchors.left: glyph.right
    anchors.leftMargin: island.s(12)
    anchors.right: readout.left
    anchors.rightMargin: island.s(10)
    anchors.verticalCenter: parent.verticalCenter
    height: island.s(5)
    radius: height / 2
    color: Util.alpha(island.fg, 0.16)

    Rectangle {
      height: parent.height
      radius: height / 2
      width: Math.max(view.value > 0 ? height : 0, parent.width * view.value)
      color: view.hud.color || island.fg

      Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }
  }
}
