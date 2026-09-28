import QtQuick
import qs.Commons

// Round glyph button used by the expanded player.
Item {
  id: button

  property string glyph: ""
  property int glyphSize: 18
  property color color: "white"
  property string fontFamily: Style.font.family
  property bool available: true

  signal clicked()

  implicitWidth: Math.round(glyphSize * 2)
  implicitHeight: implicitWidth
  scale: mouse.pressed && available ? 0.86 : 1

  Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

  Rectangle {
    anchors.fill: parent
    radius: width / 2
    color: Util.alpha(button.color, !button.available ? 0 : (mouse.pressed ? 0.2 : (mouse.containsMouse ? 0.1 : 0)))

    Behavior on color { ColorAnimation { duration: 140 } }
  }

  Text {
    anchors.centerIn: parent
    text: button.glyph
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: button.fontFamily
    font.pixelSize: button.glyphSize
    color: button.color
    opacity: button.available ? 1 : 0.35
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: button.available ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: if (button.available) button.clicked()
  }
}
