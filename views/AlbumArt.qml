import QtQuick
import QtQuick.Shapes
import qs.Commons

// Rounded cover art with a tinted glyph standing in until (or unless) the
// player provides an image.
//
// The image is painted straight into a rounded Shape (ShapePath.fillItem)
// rather than clipped through an offscreen layer: at fractional scaling a
// layer lands between device pixels and smears, which made covers soft.
Item {
  id: art

  property string source: ""
  property color tint: Color.accent
  property string fontFamily: Style.font.family
  property real radius: Math.round(width * 0.24)
  property string placeholder: "󰝚"

  // App icons from the icon theme have their own shape (and transparency),
  // so they are drawn as-is instead of cropped into a rounded tile.
  readonly property bool themeIcon: source.indexOf("image://icon/") === 0

  // Decode at twice the on-screen size so 1.25x/1.5x/2x screens all get
  // real pixels; the scene graph filters it down smoothly.
  readonly property int decodeSize: Math.max(64, Math.ceil(Math.max(width, height) * 2))

  Image {
    id: image
    width: art.width
    height: art.height
    visible: art.themeIcon
    source: art.source
    // With both sourceSize dimensions set, PreserveAspectCrop decodes the
    // image already cropped to a square, so the texture is exactly the tile.
    fillMode: art.themeIcon ? Image.PreserveAspectFit : Image.PreserveAspectCrop
    sourceSize.width: art.decodeSize
    sourceSize.height: art.decodeSize
    asynchronous: true
    cache: true
    smooth: true
    mipmap: true
  }

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    visible: !(art.themeIcon && image.status === Image.Ready)

    ShapePath {
      strokeWidth: 0
      strokeColor: "transparent"
      fillColor: Util.alpha(art.tint, 0.22)
      PathRectangle { x: 0; y: 0; width: art.width; height: art.height; radius: art.radius }
    }
  }

  // Built only once the image has loaded (and rebuilt for each new one): a
  // fill created while a network cover was still downloading keeps the
  // empty texture and paints white.
  Loader {
    anchors.fill: parent
    active: !art.themeIcon && image.status === Image.Ready

    sourceComponent: Shape {
      preferredRendererType: Shape.CurveRenderer

      ShapePath {
        strokeWidth: 0
        strokeColor: "transparent"
        fillItem: image
        // The fill texture is laid out at the image item's size; scale it
        // to the tile in case the two ever differ.
        fillTransform: PlanarTransform.fromScale(art.width / Math.max(1, image.width), art.height / Math.max(1, image.height))
        PathRectangle { x: 0; y: 0; width: art.width; height: art.height; radius: art.radius }
      }
    }
  }

  Text {
    anchors.centerIn: parent
    visible: image.status !== Image.Ready
    text: art.placeholder
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: art.fontFamily
    font.pixelSize: Math.round(art.height * 0.5)
    color: art.tint
  }
}
