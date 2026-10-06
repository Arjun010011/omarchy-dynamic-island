import QtQuick

// A compositor can close a layer surface when its output disappears without
// destroying the QML panel. Keep its state, but unmap until the output settles
// and then show it again. Merely rebinding window.screen does not reopen it.
Item {
  id: root

  required property var window
  required property var targetScreen
  property bool remapping: false
  readonly property bool ready: targetScreen !== null && !remapping

  visible: false

  function recover() {
    remapping = true
    settleTimer.restart()
  }

  onTargetScreenChanged: recover()

  Timer {
    id: settleTimer
    interval: 200
    onTriggered: root.remapping = false
  }

  Connections {
    target: root.window
    // Reopening synchronously would race Quickshell's close/teardown path.
    function onClosed() { Qt.callLater(root.recover) }
  }

  Connections {
    target: root.targetScreen
    // A retained monitor can move when another display is unplugged. Remap
    // then too, so Hyprland places the layer surface at the new origin.
    function onXChanged() { root.recover() }
    function onYChanged() { root.recover() }
  }
}
