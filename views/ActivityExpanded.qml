import QtQuick
import qs.Commons

// A script's live activity, opened: glyph, title, subtitle, progress, and
// an × to end it.
Item {
  id: view

  property var island: null
  readonly property var item: island.activity
  readonly property color tone: item ? island.toneFor(item.color) : island.accentColor
  readonly property int pad: island.s(20)

  Rectangle {
    id: badge
    x: view.pad
    anchors.verticalCenter: parent.verticalCenter
    width: island.s(48)
    height: width
    radius: width / 2
    color: Util.alpha(view.tone, 0.18)

    ProgressRing {
      anchors.fill: parent
      anchors.margins: island.s(3)
      visible: !!view.item && view.item.progress >= 0
      progress: view.item ? Math.max(0, view.item.progress) : 0
      color: view.tone
      lineWidth: island.s(3)
    }

    Text {
      anchors.centerIn: parent
      text: view.item ? view.item.icon : ""
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island.fontFamily
      font.pixelSize: island.f(18)
      color: view.tone
    }
  }

  IconButton {
    id: close
    anchors.right: parent.right
    anchors.rightMargin: view.pad - island.s(6)
    anchors.verticalCenter: parent.verticalCenter
    glyph: "󰅖"
    glyphSize: island.f(16)
    color: island.fg
    fontFamily: island.fontFamily
    onClicked: {
      if (view.item) island.endActivity(view.item.id)
      island.collapse()
    }
  }

  Column {
    anchors.left: badge.right
    anchors.leftMargin: island.s(14)
    anchors.right: close.left
    anchors.rightMargin: island.s(10)
    anchors.verticalCenter: parent.verticalCenter
    spacing: island.s(3)

    Item {
      width: parent.width
      height: title.implicitHeight

      Text {
        id: title
        anchors.left: parent.left
        anchors.right: value.left
        anchors.rightMargin: island.s(8)
        text: view.item ? view.item.title : ""
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        elide: Text.ElideRight
        font.family: island.textFamily
        font.pixelSize: island.f(14)
        font.weight: Font.DemiBold
        color: island.fg
      }

      Text {
        id: value
        anchors.right: parent.right
        text: !view.item ? "" : (view.item.value !== "" ? view.item.value
          : (view.item.progress >= 0 ? Math.round(view.item.progress * 100) + "%" : ""))
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island.fontFamily
        font.pixelSize: island.f(12)
        font.bold: true
        font.features: { "tnum": 1 }
        color: view.tone
      }
    }

    Text {
      width: parent.width
      visible: text !== ""
      text: view.item ? view.item.subtitle : ""
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      elide: Text.ElideRight
      font.family: island.textFamily
      font.pixelSize: island.f(12)
      color: island.fgDim
    }

    Rectangle {
      visible: !!view.item && view.item.progress >= 0
      width: parent.width
      height: island.s(4)
      radius: height / 2
      color: Util.alpha(island.fg, 0.14)

      Rectangle {
        height: parent.height
        radius: height / 2
        width: parent.width * (view.item ? Math.max(0, view.item.progress) : 0)
        color: view.tone

        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
      }
    }
  }
}
