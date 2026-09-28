import QtQuick

// A script's live activity, compact: its glyph on the leading edge (in a
// progress ring when it reports progress) and its value or percentage on
// the trailing edge.
Item {
  id: view

  property var island: null
  readonly property var item: island.activity
  readonly property color tone: item ? island.toneFor(item.color) : island.accentColor

  Item {
    anchors.left: parent.left
    anchors.leftMargin: island.s(6)
    anchors.verticalCenter: parent.verticalCenter
    width: island.s(22)
    height: width

    ProgressRing {
      anchors.fill: parent
      visible: !!view.item && view.item.progress >= 0
      progress: view.item ? Math.max(0, view.item.progress) : 0
      color: view.tone
      lineWidth: island.s(2)
    }

    Text {
      anchors.centerIn: parent
      text: view.item ? view.item.icon : ""
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island.fontFamily
      font.pixelSize: view.item && view.item.progress >= 0 ? island.f(10) : island.f(15)
      color: view.tone
    }
  }

  Text {
    anchors.right: parent.right
    anchors.rightMargin: island.s(14)
    anchors.verticalCenter: parent.verticalCenter
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
