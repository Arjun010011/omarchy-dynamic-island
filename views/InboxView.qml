import QtQuick
import qs.Commons
import "../IslandModel.js" as Model

// The opened inbox: every notification that was not clicked yet, newest
// first. Click a row to jump to its app, × on a row to clear that one, and
// the × Clear all pill at the bottom to clear them all.
Item {
  id: view

  property var island: null
  readonly property var items: island.inbox
  readonly property int pad: island.s(14)
  readonly property int rowHeight: island.s(Model.inboxRowHeight)
  readonly property int rowGap: island.s(Model.inboxRowGap)
  property double now: Date.now()

  Timer {
    interval: 30000
    repeat: true
    running: view.visible
    triggeredOnStart: true
    onTriggered: view.now = Date.now()
  }

  Text {
    visible: view.items.length === 0
    anchors.centerIn: parent
    text: "No notifications"
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: island.fontFamily
    font.pixelSize: island.f(13)
    color: island.fgDim
  }

  ListView {
    id: list
    visible: view.items.length > 0
    x: view.pad
    y: view.pad
    width: parent.width - view.pad * 2
    height: clearAll.y - island.s(10) - y
    clip: true
    spacing: view.rowGap
    boundsBehavior: Flickable.StopAtBounds
    model: view.items

    delegate: Rectangle {
      id: row
      required property var modelData
      width: ListView.view.width
      height: view.rowHeight
      radius: island.s(18)
      color: Util.alpha(island.fg, rowMouse.containsMouse ? 0.1 : 0.05)

      Behavior on color { ColorAnimation { duration: 120 } }

      MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: island.notificationOpen(row.modelData.key)
      }

      AlbumArt {
        id: icon
        anchors.left: parent.left
        anchors.leftMargin: island.s(10)
        anchors.verticalCenter: parent.verticalCenter
        width: island.s(36)
        height: width
        radius: Math.round(width * 0.28)
        source: island.notificationIcon(row.modelData)
        placeholder: row.modelData.glyph ? row.modelData.glyph : "󰂚"
        tint: row.modelData.critical ? island.urgentColor : island.accentColor
        fontFamily: island.fontFamily
      }

      // × for this one notification.
      Rectangle {
        id: close
        anchors.right: parent.right
        anchors.rightMargin: island.s(10)
        anchors.verticalCenter: parent.verticalCenter
        width: island.s(24)
        height: width
        radius: width / 2
        color: Util.alpha(island.fg, closeMouse.pressed ? 0.24 : (closeMouse.containsMouse ? 0.16 : 0.08))

        Text {
          anchors.centerIn: parent
          text: "󰅖"
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: island.fontFamily
          font.pixelSize: island.f(12)
          color: island.fg
        }

        MouseArea {
          id: closeMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: island.notificationDismiss(row.modelData.key)
        }
      }

      Column {
        anchors.left: icon.right
        anchors.leftMargin: island.s(10)
        anchors.right: close.left
        anchors.rightMargin: island.s(8)
        anchors.verticalCenter: parent.verticalCenter
        spacing: island.s(1)

        Text {
          width: parent.width
          text: (row.modelData.app || "Notification") + "  ·  " + Model.ago(row.modelData.time, view.now)
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          elide: Text.ElideRight
          font.family: island.fontFamily
          font.pixelSize: island.f(10)
          color: row.modelData.critical ? island.urgentColor : island.fgDim
        }

        Text {
          width: parent.width
          text: row.modelData.summary
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          elide: Text.ElideRight
          font.family: island.fontFamily
          font.pixelSize: island.f(12)
          font.bold: true
          color: island.fg
        }

        Text {
          width: parent.width
          visible: text !== ""
          text: row.modelData.body
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          elide: Text.ElideRight
          font.family: island.fontFamily
          font.pixelSize: island.f(11)
          color: island.fgDim
        }
      }
    }
  }

  // One × to clear everything.
  Rectangle {
    id: clearAll
    visible: view.items.length > 0
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: view.pad
    height: island.s(30)
    width: clearLabel.implicitWidth + island.s(32)
    radius: height / 2
    color: Util.alpha(island.fg, clearMouse.pressed ? 0.22 : (clearMouse.containsMouse ? 0.15 : 0.08))
    scale: clearMouse.pressed ? 0.95 : 1

    Behavior on scale { NumberAnimation { duration: 120 } }

    Text {
      id: clearLabel
      anchors.centerIn: parent
      text: "󰅖  Clear all"
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island.fontFamily
      font.pixelSize: island.f(12)
      font.bold: true
      color: island.fg
    }

    MouseArea {
      id: clearMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: island.notificationClearAll()
    }
  }
}
