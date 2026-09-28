import QtQuick

// Next meeting, compact: calendar glyph, the title scrolling through the
// middle, and the countdown on the trailing edge.
Item {
  id: view

  property var island: null
  readonly property var cal: island.calendar
  readonly property bool started: cal.next && cal.next.start <= cal.now

  Text {
    id: glyph
    anchors.left: parent.left
    anchors.leftMargin: island.s(13)
    anchors.verticalCenter: parent.verticalCenter
    text: "󰃭"
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: island.fontFamily
    font.pixelSize: island.f(15)
    color: view.started ? island.urgentColor : island.accentColor
  }

  Text {
    id: countdown
    anchors.right: parent.right
    anchors.rightMargin: island.s(14)
    anchors.verticalCenter: parent.verticalCenter
    text: view.cal.countdown
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: island.textFamily
    font.pixelSize: island.f(12)
    font.weight: Font.DemiBold
    color: view.started ? island.urgentColor : island.accentColor
  }

  Marquee {
    anchors.left: glyph.right
    anchors.leftMargin: island.s(10)
    anchors.right: countdown.left
    anchors.rightMargin: island.s(10)
    anchors.verticalCenter: parent.verticalCenter
    text: view.cal.next ? view.cal.next.title : ""
    color: island.fg
    fontFamily: island.textFamily
    pixelSize: island.f(12)
    bold: true
    speed: island.s(26)
    gap: island.s(40)
    fadeColor: island.surface
    fadeTop: island.bodyAt(0.25)
    fadeBottom: island.bodyAt(0.75)
    fadeWidth: island.s(10)
  }
}
