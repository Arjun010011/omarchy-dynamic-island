import QtQuick
import QtQuick.Effects

// Holds one island view at its own target size, centered in the island.
// Because the view never resizes with the spring, the morphing shape reveals
// it instead of squashing it; the view itself only fades, scales and
// un-blurs in, the way iOS content resolves as the island settles.
Item {
  id: slot

  property bool active: false

  // Centered, but on whole device pixels (the parent says how big one is),
  // so text and edges inside don't land between pixels.
  readonly property real dpr: parent && parent.dpr > 0 ? parent.dpr : 1
  x: parent ? Math.round((parent.width - width) / 2 * dpr) / dpr : 0
  y: parent ? Math.round((parent.height - height) / 2 * dpr) / dpr : 0
  opacity: active ? 1 : 0
  scale: active ? 1 : 0.86
  visible: opacity > 0.01
  enabled: active

  Behavior on opacity {
    SequentialAnimation {
      PauseAnimation { duration: slot.active ? 40 : 0 }
      NumberAnimation { duration: slot.active ? 240 : 80; easing.type: Easing.OutCubic }
    }
  }

  Behavior on scale {
    SequentialAnimation {
      PauseAnimation { duration: slot.active ? 40 : 0 }
      NumberAnimation { duration: slot.active ? 380 : 90; easing.type: slot.active ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.1 }
    }
  }

  layer.enabled: opacity > 0.01 && opacity < 0.99
  layer.effect: MultiEffect {
    blurEnabled: true
    blurMax: 32
    blur: 1 - slot.opacity
  }
}
