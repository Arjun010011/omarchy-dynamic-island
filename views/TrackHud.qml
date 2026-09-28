import QtQuick

// Brief "now playing" card shown when the track changes.
Item {
  id: view

  property var island: null

  AlbumArt {
    id: art
    anchors.left: parent.left
    anchors.leftMargin: island.s(11)
    anchors.verticalCenter: parent.verticalCenter
    width: island.s(44)
    height: width
    source: island.mediaArt
    tint: island.accentColor
    fontFamily: island.fontFamily
  }

  Visualizer {
    id: viz
    anchors.right: parent.right
    anchors.rightMargin: island.s(20)
    anchors.verticalCenter: parent.verticalCenter
    playing: island.mediaPlaying
    color: island.accentColor
    barWidth: island.s(3)
    maxHeight: island.s(18)
  }

  Column {
    anchors.left: art.right
    anchors.leftMargin: island.s(12)
    anchors.right: viz.left
    anchors.rightMargin: island.s(14)
    anchors.verticalCenter: parent.verticalCenter
    spacing: island.s(2)

    Text {
      width: parent.width
      text: island.mediaTitle
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      elide: Text.ElideRight
      font.family: island.fontFamily
      font.pixelSize: island.f(14)
      font.bold: true
      color: island.fg
    }

    Text {
      width: parent.width
      visible: text !== ""
      text: island.mediaArtist
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      elide: Text.ElideRight
      font.family: island.fontFamily
      font.pixelSize: island.f(12)
      color: island.fgDim
    }
  }
}
