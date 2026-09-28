import QtQuick

// Text that flips to its next value like a split-flap board: the old value
// slides up out of the island while the new one rises in from below, a beat
// later, so the two never smear over each other. Size it to the island (it
// clips to itself) so values travel the full height.
Item {
  id: flip

  property string text: ""
  property color color: "white"
  property string fontFamily: ""
  property int pixelSize: 12
  property bool bold: true

  readonly property real restY: Math.round((height - current.implicitHeight) / 2)

  clip: true
  implicitWidth: Math.max(current.implicitWidth, incoming.implicitWidth)
  implicitHeight: current.implicitHeight

  onTextChanged: {
    if (current.text === "") { current.text = text; return }
    incoming.text = text
    incoming.color = color
    turn.restart()
  }
  onColorChanged: if (!turn.running) current.color = color

  Text {
    id: current
    anchors.horizontalCenter: parent.horizontalCenter
    y: flip.restY
    color: flip.color
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: flip.fontFamily
    font.pixelSize: flip.pixelSize
    font.bold: flip.bold
    font.features: { "tnum": 1 }
  }

  Text {
    id: incoming
    anchors.horizontalCenter: parent.horizontalCenter
    y: flip.height
    opacity: 0
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font: current.font
  }

  SequentialAnimation {
    id: turn
    ParallelAnimation {
      NumberAnimation { target: current; property: "y"; to: -current.implicitHeight; duration: 240; easing.type: Easing.InCubic }
      NumberAnimation { target: current; property: "opacity"; to: 0; duration: 200 }
      SequentialAnimation {
        PauseAnimation { duration: 120 }
        ParallelAnimation {
          NumberAnimation { target: incoming; property: "y"; from: flip.height; to: flip.restY; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
          NumberAnimation { target: incoming; property: "opacity"; from: 0; to: 1; duration: 260 }
        }
      }
    }
    ScriptAction {
      script: {
        current.text = incoming.text
        current.color = incoming.color
        current.y = Qt.binding(function() { return flip.restY })
        current.opacity = 1
        incoming.opacity = 0
      }
    }
  }
}
