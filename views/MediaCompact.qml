import QtQuick

// Now playing, compact: cover art on the leading edge, the equalizer on the
// trailing edge, and the song scrolling past in between.
Item {
  id: view

  property var island: null

  AlbumArt {
    id: art
    anchors.left: parent.left
    anchors.leftMargin: island.s(6)
    anchors.verticalCenter: parent.verticalCenter
    width: island.s(22)
    height: width
    source: island.mediaArt
    tint: island.accentColor
    fontFamily: island.fontFamily
  }

  Visualizer {
    id: viz
    anchors.right: parent.right
    anchors.rightMargin: island.s(13)
    anchors.verticalCenter: parent.verticalCenter
    playing: island.mediaPlaying
    color: island.mediaTint
    barWidth: island.s(3)
    maxHeight: island.s(15)
  }

  Marquee {
    anchors.left: art.right
    anchors.leftMargin: island.s(8)
    anchors.right: viz.left
    anchors.rightMargin: island.s(10)
    anchors.verticalCenter: parent.verticalCenter
    text: island.mediaArtist !== "" ? island.mediaTitle + "  ·  " + island.mediaArtist : island.mediaTitle
    color: island.mediaPlaying ? island.fg : island.fgDim
    fontFamily: island.textFamily
    pixelSize: island.f(12)
    bold: true
    moving: island.mediaPlaying
    speed: island.s(30)
    gap: island.s(40)
    fadeColor: island.surface
    fadeTop: island.bodyAt(0.25)
    fadeBottom: island.bodyAt(0.75)
    fadeWidth: island.s(12)
  }
}
