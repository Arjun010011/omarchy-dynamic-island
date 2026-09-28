import QtQuick

// Now playing, compact: cover art hugging the leading edge, equalizer on the
// trailing edge, and the middle left empty where the camera would be.
Item {
  id: view

  property var island: null

  AlbumArt {
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
    anchors.right: parent.right
    anchors.rightMargin: island.s(13)
    anchors.verticalCenter: parent.verticalCenter
    playing: island.mediaPlaying
    color: island.accentColor
    barWidth: island.s(3)
    maxHeight: island.s(15)
  }
}
