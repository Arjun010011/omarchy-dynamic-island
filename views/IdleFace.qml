import QtQuick
import qs.Commons

// What the resting island shows (the "idleFace" setting):
//   ticker - a glance that flips through the time, date, battery, next
//            meeting, today's festival and silenced state (default);
//   clock  - just the time;
//   lens   - a camera lens, like the hardware island;
//   none   - the plain pill.
Item {
  id: face

  property var island: null
  readonly property string mode: island.idleFace
  readonly property var item: island.idleItem

  Flip {
    anchors.fill: parent
    visible: face.mode === "ticker" || face.mode === "clock"
    text: face.item ? face.item.text : ""
    color: face.item && face.item.color ? face.item.color : Util.alpha(island.fg, 0.9)
    fontFamily: island.fontFamily
    pixelSize: island.f(12)
  }

  // A lens: dark glass, a faint ring, and a little reflection.
  Item {
    visible: face.mode === "lens"
    anchors.right: parent.right
    anchors.rightMargin: island.s(11)
    anchors.verticalCenter: parent.verticalCenter
    width: island.s(12)
    height: width

    Rectangle {
      anchors.fill: parent
      radius: width / 2
      color: Qt.darker(island.surface, 1.6)
      border.width: Math.max(1, island.s(1))
      border.color: Util.alpha(island.accentColor, 0.28)
    }

    Rectangle {
      anchors.centerIn: parent
      width: parent.width * 0.42
      height: width
      radius: width / 2
      color: Util.alpha(island.accentColor, 0.35)
    }

    Rectangle {
      x: parent.width * 0.26
      y: parent.height * 0.22
      width: parent.width * 0.2
      height: width
      radius: width / 2
      color: Util.alpha("#ffffff", 0.55)
    }
  }
}
