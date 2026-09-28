import QtQuick

// The detached circle that carries a second live activity while the pill is
// busy with the first, like iOS's split island.
Item {
  id: view

  property var island: null
  property string kind: ""

  AlbumArt {
    anchors.centerIn: parent
    visible: view.kind === "media"
    width: parent.width - island.s(10)
    height: width
    radius: width / 2
    source: island.mediaArt
    tint: island.accentColor
    fontFamily: island.fontFamily
  }

  RecordDot {
    anchors.centerIn: parent
    visible: view.kind === "recording"
    size: island.s(11)
    color: island.urgentColor
  }

  Text {
    anchors.centerIn: parent
    visible: view.kind === "inbox"
    text: "󰂚"
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: island.fontFamily
    font.pixelSize: island.f(15)
    color: island.accentColor
  }

  Text {
    anchors.centerIn: parent
    visible: view.kind === "mic"
    text: "󰍬"
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: island.fontFamily
    font.pixelSize: island.f(15)
    color: island.orangeColor
  }
}
