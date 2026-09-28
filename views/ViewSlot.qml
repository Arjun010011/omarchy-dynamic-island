import QtQuick
import QtQuick.Effects

// Holds one island view at its own target size, centered in the island.
// Because the view never resizes with the spring, the morphing shape reveals
// it instead of squashing it; the view itself only fades, scales and
// un-blurs in, the way iOS content resolves as the island settles.
Item {
  id: slot

  property bool active: false

  anchors.centerIn: parent
  opacity: active ? 1 : 0
  scale: active ? 1 : 0.86
  visible: opacity > 0.01
  enabled: active

  Behavior on opacity {
    SequentialAnimation {
      PauseAnimation { duration: slot.active ? 90 : 0 }
      NumberAnimation { duration: slot.active ? 260 : 120; easing.type: Easing.OutCubic }
    }
  }

  Behavior on scale {
    SequentialAnimation {
      PauseAnimation { duration: slot.active ? 90 : 0 }
      NumberAnimation { duration: slot.active ? 420 : 140; easing.type: slot.active ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.1 }
    }
  }

  layer.enabled: opacity > 0.01 && opacity < 0.99
  layer.effect: MultiEffect {
    blurEnabled: true
    blurMax: 32
    blur: 1 - slot.opacity
  }
}
