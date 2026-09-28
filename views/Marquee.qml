import QtQuick
import qs.Commons

// Text that loops right-to-left forever. Two copies of the text sit in a row
// one gap apart; the row slides left by exactly one copy plus the gap and
// then starts over, so the seam is invisible. The edges fade into the island
// color instead of cutting letters off hard.
Item {
  id: marquee

  property string text: ""
  property color color: "white"
  property string fontFamily: Style.font.family
  property int pixelSize: 12
  property bool bold: false
  property bool moving: true
  property real speed: 30
  property real gap: 36
  property color fadeColor: "black"
  // When the background is shaded top-to-bottom, give both ends: the fades
  // are built from thin vertical-gradient slices so they match it exactly.
  property color fadeTop: fadeColor
  property color fadeBottom: fadeColor
  property real fadeWidth: 12

  readonly property real cycle: first.implicitWidth + gap

  clip: true
  implicitHeight: first.implicitHeight

  Row {
    id: strip
    anchors.verticalCenter: parent.verticalCenter
    spacing: marquee.gap

    Text {
      id: first
      text: marquee.text
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: marquee.fontFamily
      font.pixelSize: marquee.pixelSize
      font.bold: marquee.bold
      color: marquee.color
    }

    Text {
      text: marquee.text
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font: first.font
      color: marquee.color
    }
  }

  NumberAnimation {
    id: scroll
    target: strip
    property: "x"
    from: 0
    to: -marquee.cycle
    duration: Math.max(1000, marquee.cycle / marquee.speed * 1000)
    loops: Animation.Infinite
    running: marquee.visible && marquee.text !== "" && marquee.width > 0
    // Pausing holds the text where it is rather than snapping it back.
    paused: running && !marquee.moving
  }

  // A new title starts from the beginning.
  onCycleChanged: {
    strip.x = 0
    if (scroll.running) scroll.restart()
  }

  Row {
    anchors.left: parent.left
    height: parent.height
    Repeater {
      model: 6
      Rectangle {
        required property int index
        width: marquee.fadeWidth / 6
        height: parent.height
        opacity: 1 - index / 6
        gradient: Gradient {
          GradientStop { position: 0; color: marquee.fadeTop }
          GradientStop { position: 1; color: marquee.fadeBottom }
        }
      }
    }
  }

  Row {
    anchors.right: parent.right
    height: parent.height
    layoutDirection: Qt.RightToLeft
    Repeater {
      model: 6
      Rectangle {
        required property int index
        width: marquee.fadeWidth / 6
        height: parent.height
        opacity: 1 - index / 6
        gradient: Gradient {
          GradientStop { position: 0; color: marquee.fadeTop }
          GradientStop { position: 1; color: marquee.fadeBottom }
        }
      }
    }
  }
}
