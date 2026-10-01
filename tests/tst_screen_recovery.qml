import QtQuick
import QtTest
import ".."

TestCase {
  name: "ScreenRecovery"

  QtObject {
    id: screen
    property int x: 0
    property int y: 0
  }

  QtObject {
    id: otherScreen
    property int x: 0
    property int y: 0
  }

  QtObject {
    id: window
    signal closed()
  }

  ScreenRecovery {
    id: recovery
    window: window
    targetScreen: screen
  }

  function init() {
    recovery.targetScreen = screen
    tryCompare(recovery, "ready", true)
  }

  function test_disconnect_reconnect() {
    recovery.targetScreen = null
    compare(recovery.ready, false)
    wait(250)
    compare(recovery.ready, false)
    recovery.targetScreen = screen
    compare(recovery.ready, false)
    tryCompare(recovery, "ready", true)
  }

  function test_compositor_close_with_same_screen() {
    window.closed()
    tryCompare(recovery, "ready", false)
    tryCompare(recovery, "ready", true)
  }

  function test_repeated_close_waits_for_settle() {
    window.closed()
    tryCompare(recovery, "ready", false)
    wait(100)
    window.closed()
    wait(125)
    compare(recovery.ready, false)
    tryCompare(recovery, "ready", true)
  }

  function test_screen_switch() {
    recovery.targetScreen = otherScreen
    compare(recovery.ready, false)
    tryCompare(recovery, "ready", true)
  }

  function test_monitor_move() {
    screen.x += 100
    compare(recovery.ready, false)
    tryCompare(recovery, "ready", true)
    screen.y += 100
    compare(recovery.ready, false)
    tryCompare(recovery, "ready", true)
  }
}
