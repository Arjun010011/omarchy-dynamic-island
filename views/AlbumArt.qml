import QtQuick
import Quickshell.Widgets
import qs.Commons

// Rounded cover art with a tinted glyph standing in until (or unless) the
// player provides an image.
ClippingRectangle {
  id: art

  property string source: ""
  property color tint: Color.accent
  property string fontFamily: Style.font.family

  radius: Math.round(width * 0.24)
  color: Util.alpha(tint, 0.22)

  Image {
    id: image
    anchors.fill: parent
    source: art.source
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    cache: true
    smooth: true
    mipmap: true
    sourceSize.width: Math.max(64, art.width * 2)
    sourceSize.height: Math.max(64, art.height * 2)
    opacity: status === Image.Ready ? 1 : 0

    Behavior on opacity { NumberAnimation { duration: 200 } }
  }

  Text {
    anchors.centerIn: parent
    visible: image.status !== Image.Ready
    text: "󰝚"
    textFormat: Text.PlainText
    font.family: art.fontFamily
    font.pixelSize: Math.round(art.height * 0.5)
    color: art.tint
  }
}
